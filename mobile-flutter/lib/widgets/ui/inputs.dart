import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';

/// Text field with a visible label above it (never placeholder-only), inline error,
/// password visibility toggle and autofill hints.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.helper,
    this.error,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.prefixIcon,
    this.maxLines = 1,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.inputFormatters,
    this.enabled = true,
    this.autofocus = false,
    this.textCapitalization = TextCapitalization.none,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final String? helper;
  final String? error;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final IconData? prefixIcon;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;
  final List<TextInputFormatter>? inputFormatters;
  final bool enabled;
  final bool autofocus;
  final TextCapitalization textCapitalization;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _hidden = widget.obscure;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            widget.label,
            style: context.text.labelMedium!.copyWith(
              fontSize: 13.5,
              color: context.scheme.onSurface,
            ),
          ),
        ),
        TextFormField(
          controller: widget.controller,
          obscureText: _hidden,
          enabled: widget.enabled,
          autofocus: widget.autofocus,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          autofillHints: widget.autofillHints,
          maxLines: widget.obscure ? 1 : widget.maxLines,
          // 🔥 Fix: this used to hardcode `minLines: 3` whenever maxLines > 1,
          // which crashed with "minLines can't be greater than maxLines"
          // for ANY field using maxLines: 2 (e.g. the "Activities" field on
          // the Day-by-day trip review screen) — 3 > 2. Now minLines is
          // clamped so it's never more than maxLines.
          minLines: widget.maxLines <= 1
              ? 1
              : (widget.maxLines < 3 ? widget.maxLines : 3),
          onChanged: widget.onChanged,
          onFieldSubmitted: widget.onSubmitted,
          validator: widget.validator,
          inputFormatters: widget.inputFormatters,
          textCapitalization: widget.textCapitalization,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: InputDecoration(
            hintText: widget.hint,
            helperText: widget.helper,
            helperMaxLines: 3,
            errorText: widget.error,
            errorMaxLines: 3,
            prefixIcon: widget.prefixIcon != null
                ? Icon(widget.prefixIcon, size: 20)
                : null,
            suffixIcon: widget.obscure
                ? IconButton(
                    tooltip: _hidden ? 'Show password' : 'Hide password',
                    icon: Icon(
                      _hidden
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _hidden = !_hidden),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}

/// Search box with built-in debounce and a clear button.
class SearchField extends StatefulWidget {
  const SearchField({
    super.key,
    required this.controller,
    required this.onSearch,
    this.hint = 'Search…',
    this.debounce = const Duration(milliseconds: 400),
  });

  final TextEditingController controller;
  final VoidCallback onSearch;
  final String hint;
  final Duration debounce;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  Timer? _t;

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  void _changed(String _) {
    setState(() {});
    _t?.cancel();
    _t = Timer(widget.debounce, widget.onSearch);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      textField: true,
      label: widget.hint,
      child: TextField(
        controller: widget.controller,
        onChanged: _changed,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) {
          _t?.cancel();
          widget.onSearch();
        },
        decoration: InputDecoration(
          hintText: widget.hint,
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: widget.controller.text.isNotEmpty
              ? IconButton(
                  tooltip: 'Clear search',
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () {
                    widget.controller.clear();
                    setState(() {});
                    widget.onSearch();
                  },
                )
              : null,
        ),
      ),
    );
  }
}

/// Horizontally scrolling single-select chip row. `null` value = "All".
class ChoiceChipRow<T> extends StatelessWidget {
  const ChoiceChipRow({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.allLabel = 'All',
    this.labelOf,
  });

  final List<T> options;
  final T? value;
  final ValueChanged<T?> onChanged;
  final String? allLabel;
  final String Function(T)? labelOf;

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, bool selected, VoidCallback onTap) => Padding(
      padding: const EdgeInsets.only(right: Space.sm),
      child: Semantics(
        selected: selected,
        button: true,
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) {
            HapticFeedback.selectionClick();
            onTap();
          },
          labelStyle: context.text.labelMedium!.copyWith(
            color: selected
                ? context.scheme.primary
                : context.palette.textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
          side: BorderSide(
            color: selected ? context.scheme.primary : context.palette.border,
          ),
          materialTapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),
    );

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Space.lg),
        children: [
          if (allLabel != null)
            chip(allLabel!, value == null, () => onChanged(null)),
          for (final o in options)
            chip(
              labelOf?.call(o) ?? '$o',
              value == o,
              () => onChanged(value == o ? null : o),
            ),
        ],
      ),
    );
  }
}

/// −/+ stepper (group size, quantities). 48dp targets, announces the value.
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 99,
    this.label = 'Quantity',
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget btn(IconData icon, String tip, bool enabled, VoidCallback onTap) =>
        IconButton.filledTonal(
          tooltip: tip,
          onPressed: enabled
              ? () {
                  HapticFeedback.selectionClick();
                  onTap();
                }
              : null,
          icon: Icon(icon),
          style: IconButton.styleFrom(
            backgroundColor: p.surface2,
            foregroundColor: context.scheme.onSurface,
          ),
        );
    return Semantics(
      label: '$label: $value',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          btn(
            Icons.remove_rounded,
            'Decrease',
            value > min,
            () => onChanged(value - 1),
          ),
          SizedBox(
            width: 44,
            child: AnimatedSwitcher(
              duration: Motion.fast,
              transitionBuilder: (c, a) => ScaleTransition(
                scale: a,
                child: FadeTransition(opacity: a, child: c),
              ),
              child: Text(
                '$value',
                key: ValueKey(value),
                textAlign: TextAlign.center,
                style: context.text.titleLarge,
              ),
            ),
          ),
          btn(
            Icons.add_rounded,
            'Increase',
            value < max,
            () => onChanged(value + 1),
          ),
        ],
      ),
    );
  }
}

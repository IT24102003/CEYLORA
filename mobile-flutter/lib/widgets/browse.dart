import 'package:flutter/material.dart';

import 'ui/ui.dart';

/// Sri Lanka regions used by every browse filter (single source instead of per-screen copies).
const kRegions = [
  'Colombo',
  'Kandy',
  'Galle',
  'Nuwara Eliya',
  'Ella',
  'Sigiriya',
  'Jaffna',
  'Trincomalee',
  'Anuradhapura',
  'Mirissa',
];

/// Search box + optional "Filters" button (with active-count badge) that sits above every browse list.
class FilterBar extends StatelessWidget {
  const FilterBar({
    super.key,
    required this.controller,
    required this.onSearch,
    required this.hint,
    this.activeFilters = 0,
    this.onFilters,
  });

  final TextEditingController controller;
  final VoidCallback onSearch;
  final String hint;
  final int activeFilters;
  final VoidCallback? onFilters;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.lg,
        Space.sm,
        Space.lg,
        Space.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: SearchField(
              controller: controller,
              onSearch: onSearch,
              hint: hint,
            ),
          ),
          if (onFilters != null) ...[
            const SizedBox(width: Space.sm),
            Semantics(
              button: true,
              label: activeFilters > 0
                  ? 'Filters, $activeFilters active'
                  : 'Filters',
              child: PressScale(
                onTap: onFilters,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: activeFilters > 0
                        ? context.palette.primarySoft
                        : context.scheme.surface,
                    borderRadius: BorderRadius.circular(Radii.md),
                    border: Border.all(
                      color: activeFilters > 0
                          ? context.scheme.primary
                          : context.palette.border,
                    ),
                  ),
                  child: Badge(
                    isLabelVisible: activeFilters > 0,
                    label: Text('$activeFilters'),
                    backgroundColor: context.scheme.primary,
                    child: Icon(
                      Icons.tune_rounded,
                      color: activeFilters > 0
                          ? context.scheme.primary
                          : context.palette.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A titled group of single-select chips inside a filter sheet.
class FilterChips<T> extends StatelessWidget {
  const FilterChips({
    super.key,
    required this.title,
    required this.options,
    required this.value,
    required this.onChanged,
    this.labelOf,
  });

  final String title;
  final List<T> options;
  final T? value;
  final ValueChanged<T?> onChanged;
  final String Function(T)? labelOf;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: Space.sm, bottom: Space.sm),
          child: Text(title, style: context.text.titleSmall),
        ),
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          children: [
            for (final o in options)
              ChoiceChip(
                label: Text(labelOf?.call(o) ?? '$o'),
                selected: value == o,
                onSelected: (_) => onChanged(value == o ? null : o),
                labelStyle: context.text.labelMedium!.copyWith(
                  color: value == o
                      ? context.scheme.primary
                      : context.palette.textSecondary,
                ),
                side: BorderSide(
                  color: value == o
                      ? context.scheme.primary
                      : context.palette.border,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Opens the shared filter bottom sheet. [sections] rebuilds through the given setter as the user edits.
Future<void> showFilterSheet(
  BuildContext context, {
  required List<Widget> Function(StateSetter set) sections,
  required VoidCallback onApply,
  required VoidCallback onReset,
}) {
  return showAppSheet<void>(
    context,
    title: 'Filters',
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...sections(set),
          const SizedBox(height: Space.xl),
          AppButton(
            label: 'Show results',
            onPressed: () {
              Navigator.pop(ctx);
              onApply();
            },
          ),
          const SizedBox(height: Space.sm),
          AppButton(
            label: 'Reset all',
            variant: AppButtonVariant.ghost,
            onPressed: () {
              Navigator.pop(ctx);
              onReset();
            },
          ),
        ],
      ),
    ),
  );
}

/// Standard list row for browse screens: optional thumbnail, title, subtitle lines, trailing actions.
class ListingCard extends StatelessWidget {
  const ListingCard({
    super.key,
    required this.title,
    this.subtitle,
    this.meta,
    this.imageUrl,
    this.fallbackIcon = Icons.landscape_rounded,
    this.trailing,
    this.badges = const [],
    this.onTap,
    this.index = 0,
  });

  final String title;
  final String? subtitle;
  final Widget? meta;
  final String? imageUrl;
  final IconData fallbackIcon;
  final Widget? trailing;
  final List<Widget> badges;
  final VoidCallback? onTap;
  final int index;

  @override
  Widget build(BuildContext context) {
    return FadeInUp(
      index: index,
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(Space.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            NetImage(
              imageUrl,
              width: 76,
              height: 76,
              fallbackIcon: fallbackIcon,
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: context.text.titleSmall!.copyWith(fontSize: 16),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: context.text.bodyMedium!.copyWith(
                        color: context.palette.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (meta != null) ...[const SizedBox(height: 6), meta!],
                  if (badges.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(spacing: 6, runSpacing: 6, children: badges),
                  ],
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';

/// Shrinks its child slightly while pressed — the shared "tactile" feedback for
/// every tappable surface (buttons, cards, tiles).
class PressScale extends StatefulWidget {
  const PressScale({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.97,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final bool enabled;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  void _set(bool v) {
    if (widget.enabled && widget.onTap != null && _down != v) {
      setState(() => _down = v);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.of(context).disableAnimations;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.enabled ? widget.onTap : null,
      onLongPress: widget.enabled ? widget.onLongPress : null,
      child: AnimatedScale(
        scale: _down && !reduce ? widget.scale : 1,
        duration: Motion.fast,
        curve: Motion.out,
        child: widget.child,
      ),
    );
  }
}

enum AppButtonVariant { primary, secondary, ghost, danger, success }

/// The one button. Handles loading (spinner, disabled, same width), icons and
/// full-width layout so screens never hand-roll a `CircularProgressIndicator` inside a button.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.variant = AppButtonVariant.primary,
    this.loading = false,
    this.expand = true,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppButtonVariant variant;
  final bool loading;
  final bool expand;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final scheme = context.scheme;
    final enabled = onPressed != null && !loading;

    late final Color bg, fg;
    BorderSide? side;
    switch (variant) {
      case AppButtonVariant.primary:
        bg = scheme.primary;
        fg = scheme.onPrimary;
      case AppButtonVariant.secondary:
        bg = scheme.surface;
        fg = scheme.onSurface;
        side = BorderSide(
          color: Theme.of(context).brightness == Brightness.dark
              ? p.border
              : const Color(0xFFCBD5E1),
        );
      case AppButtonVariant.ghost:
        bg = Colors.transparent;
        fg = scheme.primary;
      case AppButtonVariant.danger:
        bg = p.dangerSoft;
        fg = p.danger;
      case AppButtonVariant.success:
        bg = p.success;
        fg = Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF05230F)
            : Colors.white;
    }

    final content = AnimatedSwitcher(
      duration: Motion.fast,
      child: loading
          ? SizedBox(
              key: const ValueKey('spin'),
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: fg),
            )
          : Row(
              key: const ValueKey('label'),
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20),
                  const SizedBox(width: Space.sm),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
    );

    final button = PressScale(
      enabled: enabled,
      onTap: enabled
          ? () {
              HapticFeedback.selectionClick();
              onPressed!();
            }
          : null,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: label,
        excludeSemantics: true,
        child: AnimatedContainer(
          duration: Motion.base,
          curve: Motion.out,
          constraints: BoxConstraints(
            minHeight: compact ? 44 : 52,
            minWidth: 64,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? Space.lg : Space.xl,
            vertical: Space.md,
          ),
          decoration: BoxDecoration(
            color: enabled || loading ? bg : bg.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(Radii.full),
            border: side != null ? Border.fromBorderSide(side) : null,
          ),
          alignment: expand ? Alignment.center : null,
          child: DefaultTextStyle.merge(
            style: context.text.labelLarge!.copyWith(
              color: enabled || loading ? fg : fg.withValues(alpha: 0.6),
            ),
            child: IconTheme.merge(
              data: IconThemeData(color: fg),
              child: content,
            ),
          ),
        ),
      ),
    );

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// 48dp icon button with a tooltip (= screen-reader label) and optional badge count.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.badge = 0,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final int badge;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Badge(
        isLabelVisible: badge > 0,
        label: Text(badge > 9 ? '9+' : '$badge'),
        backgroundColor: context.palette.danger,
        child: Icon(icon, color: color),
      ),
    );
  }
}

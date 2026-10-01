import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import 'buttons.dart';

/// Frosted-glass surface: blurred backdrop, soft white gradient and a thin light border.
class GlassCard extends StatelessWidget {
  const GlassCard({super.key, required this.child, this.padding = const EdgeInsets.all(Space.xl), this.radius = Radii.xl, this.tint, this.onTap, this.blur = 22});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? tint; // overrides the white/navy glass tint
  final VoidCallback? onTap;
  final double blur;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final tint = this.tint ?? (dark ? const Color(0xFF2A5380) : Colors.white);
    final glass = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [tint.withValues(alpha: dark ? 0.55 : 0.72), tint.withValues(alpha: dark ? 0.32 : 0.38)],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: dark ? 0.16 : 0.7), width: 1.2),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 30, offset: const Offset(0, 14))],
          ),
          child: child,
        ),
      ),
    );
    return onTap == null ? glass : PressScale(onTap: onTap, scale: 0.985, child: glass);
  }
}

/// Frosted circular icon button for gradient / photo headers. [color] tints the glyph; [badge] shows a count pill.
class GlassCircleButton extends StatelessWidget {
  const GlassCircleButton({super.key, required this.icon, required this.tooltip, required this.onPressed, this.badge = 0, this.color});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final int badge;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      button: true,
      label: tooltip,
      excludeSemantics: true,
      child: PressScale(
        onTap: onPressed,
        child: SizedBox(
          width: 52,
          height: 52,
          child: Stack(clipBehavior: Clip.none, children: [
            Positioned.fill(
              child: ClipOval(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Colors.white.withValues(alpha: dark ? 0.22 : 0.85), Colors.white.withValues(alpha: dark ? 0.08 : 0.45)],
                      ),
                      border: Border.all(color: Colors.white.withValues(alpha: dark ? 0.25 : 0.9), width: 1.2),
                    ),
                    child: Icon(icon, color: color ?? context.scheme.onSurface, size: 24),
                  ),
                ),
              ),
            ),
            if (badge > 0)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: AppColors.sun, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white, width: 1.5)),
                  child: Text(badge > 9 ? '9+' : '$badge', style: const TextStyle(color: AppColors.ink, fontSize: 11, fontWeight: FontWeight.w800)),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

class NavItemData {
  const NavItemData(this.icon, this.selectedIcon, this.label, {this.badge = 0});
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final int badge;
}

/// Glass navigation bar: a smoked, blurred bar with white icons; the selected tab becomes a glowing ocean pill with its label.
class FloatingNavBar extends StatelessWidget {
  const FloatingNavBar({super.key, required this.items, required this.index, required this.onChanged});

  final List<NavItemData> items;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, Space.sm),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [const Color(0xFF14325A).withValues(alpha: 0.42), const Color(0xFF14325A).withValues(alpha: 0.22)]),
                border: Border.all(color: Colors.white.withValues(alpha: 0.28), width: 1.2),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 24, offset: const Offset(0, 8))],
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                for (var i = 0; i < items.length; i++)
                  Semantics(
                    button: true,
                    selected: i == index,
                    label: items[i].badge > 0 ? '${items[i].label}, ${items[i].badge} new' : items[i].label,
                    excludeSemantics: true,
                    child: PressScale(
                      onTap: () {
                        if (i != index) HapticFeedback.selectionClick();
                        onChanged(i);
                      },
                      child: AnimatedContainer(
                        duration: Motion.base,
                        curve: Motion.out,
                        height: 50,
                        constraints: const BoxConstraints(minWidth: 50),
                        padding: EdgeInsets.symmetric(horizontal: i == index ? Space.lg : Space.md),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          gradient: i == index ? const LinearGradient(colors: [Color(0xFF4DB3EA), Color(0xFF2B7BC0)]) : null,
                          
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
                          Badge(
                            isLabelVisible: items[i].badge > 0,
                            label: Text(items[i].badge > 9 ? '9+' : '${items[i].badge}'),
                            backgroundColor: AppColors.sun,
                            textColor: AppColors.ink,
                            child: Icon(i == index ? items[i].selectedIcon : items[i].icon, size: 24, color: Colors.white.withValues(alpha: i == index ? 1 : 0.85)),
                          ),
                          AnimatedSize(
                            duration: Motion.base,
                            curve: Motion.out,
                            child: i == index
                                ? Padding(
                                    padding: const EdgeInsets.only(left: Space.sm),
                                    child: Text(items[i].label, style: context.text.labelMedium!.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ]),
                      ),
                    ),
                  ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Slide to confirm" pill: drag the knob across, with animated chevrons as the affordance.
/// Tapping (or screen-reader activation) also confirms, so it never relies on a drag alone.
class SlideToConfirm extends StatefulWidget {
  const SlideToConfirm({super.key, required this.label, required this.onConfirmed, this.loading = false, this.icon = Icons.arrow_forward_rounded});

  final String label;
  final VoidCallback onConfirmed;
  final bool loading;
  final IconData icon;

  @override
  State<SlideToConfirm> createState() => _SlideToConfirmState();
}

class _SlideToConfirmState extends State<SlideToConfirm> with TickerProviderStateMixin {
  static const double _h = 60;
  static const double _knob = 48;
  late final AnimationController _hint = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
  late final AnimationController _back = AnimationController(vsync: this, duration: Motion.base);
  double _dx = 0;
  double _from = 0;

  @override
  void initState() {
    super.initState();
    _back.addListener(() => setState(() => _dx = _from * (1 - Curves.easeOutBack.transform(_back.value))));
  }

  @override
  void dispose() {
    _hint.dispose();
    _back.dispose();
    super.dispose();
  }

  void _release(double max) {
    if (_dx > max * 0.82 && !widget.loading) {
      HapticFeedback.mediumImpact();
      widget.onConfirmed();
    }
    _from = _dx;
    _back.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final max = c.maxWidth - _knob - 12;
      return Semantics(
        button: true,
        label: widget.label,
        hint: 'Double tap to confirm',
        onTap: widget.loading ? null : widget.onConfirmed,
        excludeSemantics: true,
        child: GestureDetector(
          onTap: widget.loading ? null : () {
            HapticFeedback.selectionClick();
            widget.onConfirmed();
          },
          onHorizontalDragUpdate: widget.loading ? null : (d) => setState(() => _dx = (_dx + d.delta.dx).clamp(0, max)),
          onHorizontalDragEnd: widget.loading ? null : (_) => _release(max),
          child: Container(
            height: _h,
            decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(Radii.full)),
            child: Stack(alignment: Alignment.centerLeft, children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(left: _knob),
                  child: Opacity(
                    opacity: (1 - (_dx / max) * 1.4).clamp(0.0, 1.0),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Flexible(child: Text(widget.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.labelLarge!.copyWith(color: Colors.white))),
                      const SizedBox(width: Space.md),
                      AnimatedBuilder(
                        animation: _hint,
                        builder: (_, _) => Row(children: [
                          for (var i = 0; i < 3; i++)
                            Icon(Icons.chevron_right_rounded, size: 20, color: Colors.white.withValues(alpha: ((_hint.value * 3 - i).clamp(0.0, 1.0) * (1 - (_hint.value * 3 - i - 1).clamp(0.0, 1.0))) * 0.8 + 0.15)),
                        ]),
                      ),
                    ]),
                  ),
                ),
              ),
              Positioned(
                left: 6 + _dx,
                child: Container(
                  width: _knob,
                  height: _knob,
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: widget.loading
                      ? const Padding(padding: EdgeInsets.all(13), child: CircularProgressIndicator(strokeWidth: 2.6, color: AppColors.ink))
                      : Icon(widget.icon, color: AppColors.ink),
                ),
              ),
            ]),
          ),
        ),
      );
    });
  }
}

/// The Ceylora logo on a white rounded card, so it stays legible on any scenery.
class LogoBadge extends StatelessWidget {
  const LogoBadge({super.key, this.height = 120});
  final double height;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        label: 'Ceylora — Explore, Experience, Sri Lanka',
        image: true,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: Space.xl, vertical: Space.md),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(Radii.xl),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 24, offset: const Offset(0, 10))],
          ),
          child: Image.asset('assets/logo.png', height: height, fit: BoxFit.contain, excludeFromSemantics: true),
        ),
      ),
    );
  }
}

/// List-row flavour of [GlassCard] (same API as AppCard) for screens that sit on the scenery.
class GlassTile extends StatelessWidget {
  const GlassTile({super.key, required this.child, this.onTap, this.padding = const EdgeInsets.all(Space.lg), this.color, this.margin});

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? color; // tints the glass (e.g. unread highlight)
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final tile = GlassCard(radius: Radii.lg, blur: 14, padding: padding, tint: color, onTap: onTap, child: child);
    return margin == null ? tile : Padding(padding: margin!, child: tile);
  }
}

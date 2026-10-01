import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/scheduler.dart' show TickerProvider;
import '../../theme/app_theme.dart';
import 'scene_painter.dart';

export 'scene_painter.dart' show Destination;

/// App-wide scenery clock. One ticker drives every backdrop so all screens (and tabs) show the same
/// destination at the same moment and cross-fade together every [_hold] seconds.
class Scenic {
  Scenic._();
  static final Scenic instance = Scenic._();

  static const int _hold = 10;
  final ValueNotifier<double> t = ValueNotifier(0.25);
  final ValueNotifier<int> index = ValueNotifier(0);
  Timer? _timer;

  /// Rotates the destination every few seconds. (Per-frame drift was dropped: repainting a full-screen
  /// scene under several blur layers every frame is too costly, and photos don't need it.)
  void start(TickerProvider vsync) {
    _timer ??= Timer.periodic(const Duration(seconds: _hold), (_) {
      index.value = (index.value + 1) % Destination.values.length;
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Destination get current => Destination.values[index.value];
}

/// Full-bleed destination backdrop. [reach] is how far down the screen the scenery shows before it
/// melts into the page colour; [scrim] darkens it for white-on-photo text (intro / sign-in).
class ScenicBackground extends StatelessWidget {
  const ScenicBackground({super.key, this.reach = 0.5, this.scrim = false, this.opacity = 1});

  final double reach;
  final bool scrim;
  final double opacity; // < 1 lets the page colour show through the scenery

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final reduce = MediaQuery.of(context).disableAnimations;
    final bg = context.palette.background;
    final deep = const Color(0xFF14325A); // dark-blue wash over the scenery
    final end = reach.clamp(0.2, 1.0);
    final start = (end - 0.32).clamp(0.05, 0.8);

    return Positioned.fill(
      child: ExcludeSemantics(
        child: Stack(fit: StackFit.expand, children: [
          ColoredBox(color: bg),
          ValueListenableBuilder<int>(
            valueListenable: Scenic.instance.index,
            builder: (context, i, _) => AnimatedSwitcher(
              duration: const Duration(milliseconds: 1400),
              child: Opacity(key: ValueKey(i), opacity: opacity, child: _SceneLayer( scene: Destination.values[i], dark: dark, still: reduce, clip: scrim ? 1.0 : (end + 0.08).clamp(0.0, 1.0))),
            ),
          ),
          if (scrim)
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [const Color(0xFF14325A).withValues(alpha: 0.26), const Color(0xFF14325A).withValues(alpha: 0.03), const Color(0xFF14325A).withValues(alpha: 0.38)],
                  stops: const [0, 0.45, 1],
                ),
              ),
            )
          else
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [deep.withValues(alpha: 0.30), deep.withValues(alpha: 0.12), bg.withValues(alpha: 0.9), bg],
                  stops: [0, start, end * 0.9, end],
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

class _SceneLayer extends StatelessWidget {
  const _SceneLayer({required this.scene, required this.dark, required this.still, required this.clip});
  final Destination scene;
  final bool dark;
  final bool still;
  final double clip; // fraction of the height the scenery may occupy

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ClipRect(
        clipper: _TopClipper(clip),
        child: Stack(fit: StackFit.expand, children: [
        ValueListenableBuilder<double>(
          valueListenable: Scenic.instance.t,
          builder: (context, t, _) => CustomPaint(painter: ScenePainter(scene, still ? 0.25 : t, dark)),
        ),
        // Optional real photo: drop assets/backgrounds/<slug>.jpg and it replaces the illustration.
        Image.asset(
          'assets/backgrounds/${scene.slug}.jpg',
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          color: dark ? const Color(0x24000000) : null, // dim photos in dark mode
          colorBlendMode: dark ? BlendMode.darken : null,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
      ]),
      ),
    );
  }
}

/// Wraps a route so it always sits on the shared scenery (used by the page-transition builder).
class ScenicPage extends StatelessWidget {
  const ScenicPage({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(fit: StackFit.expand, children: [const ScenicBackground(reach: 0.8, opacity: 0.9), child]);
}

/// Page transition that keeps the shared scenery under every pushed route, so screens can be
/// transparent without the previous page showing through while the new one fades in.
class ScenicTransitions extends PageTransitionsBuilder {
  const ScenicTransitions(this.inner);
  final PageTransitionsBuilder inner;

  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    return inner.buildTransitions<T>(route, context, animation, secondaryAnimation, ScenicPage(child: child));
  }
}

class _TopClipper extends CustomClipper<Rect> {
  const _TopClipper(this.f);
  final double f;

  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, size.width, size.height * f);

  @override
  bool shouldReclip(_TopClipper old) => old.f != f;
}

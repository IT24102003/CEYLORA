import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Sri Lanka's postcard destinations, painted as layered illustrations in the Ceylora logo palette.
/// Which built-in illustration to paint when a destination has no photo yet.
enum Art { sigiriya, ella, galle, mirissa }

enum Destination {
  sigiriya('Sigiriya', 'sigiriya', Art.sigiriya),
  galle('Galle Fort', 'galle', Art.galle),
  colombo('Colombo', 'colombo', Art.mirissa),
  ella('Ella · Nine Arches', 'ella', Art.ella),
  anuradhapura('Anuradhapura', 'anuradhapura', Art.sigiriya),
  stclair("St Clair's Falls", 'stclair', Art.ella),
  yala('Yala', 'yala', Art.sigiriya),
  coast('Sri Lankan Coast', 'coast', Art.mirissa),
  sunset('Sunset by the Sea', 'sunset', Art.mirissa),
  falls('Hill Country Falls', 'falls', Art.ella);

  const Destination(this.label, this.slug, this.art);
  final String label;
  final String slug; // photo file: assets/backgrounds/<slug>.jpg
  final Art art;
}

class ScenePainter extends CustomPainter {
  ScenePainter(this.scene, this.t, this.dark);

  final Destination scene;
  final double t; // 0..1 looping drift
  final bool dark;

  // Palette derived from the logo: ocean blues, palm greens, sun orange.
  Color get skyTop => dark ? const Color(0xFF2A5D96) : const Color(0xFF9FD3F2);
  Color get skyBottom => dark ? const Color(0xFF5B8FC4) : const Color(0xFFFBE9CF);
  Color get sun => dark ? const Color(0xFFDDE8F5) : const Color(0xFFF8A31C);
  Color get far => dark ? const Color(0xFF2A6A8E) : const Color(0xFF6FA9C4);
  Color get mid => dark ? const Color(0xFF123C45) : const Color(0xFF2F8F78);
  Color get near => dark ? const Color(0xFF0A2A2F) : const Color(0xFF1F6B52);
  Color get rock => dark ? const Color(0xFF0E3238) : const Color(0xFF1E5A4C);
  Color get sea1 => dark ? const Color(0xFF0E3A66) : const Color(0xFF1B8FD1);
  Color get sea2 => dark ? const Color(0xFF0A2B4F) : const Color(0xFF0F6FB3);
  Color get sand => dark ? const Color(0xFF8C7A5A) : const Color(0xFFF1DEB8);
  Color get trunk => dark ? const Color(0xFF1A2A25) : const Color(0xFF3B3A2A);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final hz = h * 0.46;
    final drift = math.sin(t * 2 * math.pi);

    // Sky
    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [skyTop, skyBottom], stops: const [0.0, 0.62]).createShader(Offset.zero & size),
    );

    final sunPos = switch (scene.art) {
      Art.sigiriya => Offset(w * 0.74, hz * 0.52),
      Art.ella => Offset(w * 0.22, hz * 0.5),
      Art.galle => Offset(w * 0.30, hz * 0.62),
      Art.mirissa => Offset(w * 0.5, hz * 0.8),
    };
    _sun(canvas, sunPos, w * 0.085, drift);
    _clouds(canvas, w, hz, drift);

    switch (scene.art) {
      case Art.sigiriya:
        _sigiriya(canvas, w, h, hz, drift);
      case Art.ella:
        _ella(canvas, w, h, hz, drift);
      case Art.galle:
        _galle(canvas, w, h, hz, drift);
      case Art.mirissa:
        _mirissa(canvas, w, h, hz, drift);
    }
    _birds(canvas, w, hz, drift);
  }

  // ── Building blocks ───────────────────────────────────────────

  void _sun(Canvas c, Offset p, double r, double d) {
    c.drawCircle(p, r * 3.2, Paint()..shader = RadialGradient(colors: [sun.withValues(alpha: dark ? 0.18 : 0.45), sun.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: p, radius: r * 3.2)));
    c.drawCircle(p, r * (1 + d * 0.015), Paint()..color = sun);
  }

  void _clouds(Canvas c, double w, double hz, double d) {
    final p = Paint()..color = Colors.white.withValues(alpha: dark ? 0.07 : 0.55);
    void cloud(double x, double y, double s) {
      final o = Offset(x + d * w * 0.02, y);
      c.drawOval(Rect.fromCenter(center: o, width: s, height: s * 0.28), p);
      c.drawOval(Rect.fromCenter(center: o.translate(s * 0.22, -s * 0.07), width: s * 0.55, height: s * 0.26), p);
    }
    cloud(w * 0.2, hz * 0.28, w * 0.34);
    cloud(w * 0.78, hz * 0.18, w * 0.28);
  }

  void _birds(Canvas c, double w, double hz, double d) {
    final p = Paint()
      ..color = (dark ? Colors.white70 : const Color(0xFF0B2A52))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    void bird(double x, double y, double s) {
      final flap = math.sin(t * 2 * math.pi * 14 + x) * s * 0.25;
      final o = Offset(x + d * w * 0.03, y + d * 4);
      final path = Path()
        ..moveTo(o.dx - s, o.dy + flap)
        ..quadraticBezierTo(o.dx - s * 0.4, o.dy - s * 0.5, o.dx, o.dy)
        ..quadraticBezierTo(o.dx + s * 0.4, o.dy - s * 0.5, o.dx + s, o.dy + flap);
      c.drawPath(path, p);
    }
    bird(w * 0.42, hz * 0.34, 9);
    bird(w * 0.5, hz * 0.28, 7);
    bird(w * 0.36, hz * 0.24, 6);
  }

  Path _ridge(double w, double base, double amp, double phase, double shift) {
    final p = Path()..moveTo(-20, base + 400);
    for (double x = -20; x <= w + 20; x += 12) {
      final y = base - amp * (0.5 + 0.5 * math.sin((x + shift) / w * 5.2 + phase)) - amp * 0.35 * math.sin((x + shift) / w * 11 + phase * 2);
      p.lineTo(x, y);
    }
    p.lineTo(w + 20, base + 400);
    return p..close();
  }

  void _sea(Canvas c, double w, double h, double hz, double d, {double top = 0}) {
    final rect = Rect.fromLTRB(0, hz + top, w, h);
    c.drawRect(rect, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [sea1, sea2]).createShader(rect));
    final line = Paint()
      ..color = Colors.white.withValues(alpha: dark ? 0.12 : 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 6; i++) {
      final y = hz + top + 16 + i * 26.0;
      final path = Path()..moveTo(0, y);
      for (double x = 0; x <= w; x += 10) {
        path.lineTo(x, y + math.sin(x / 38 + t * 2 * math.pi * 2 + i) * (2 + i * 0.6));
      }
      c.drawPath(path, line..color = line.color.withValues(alpha: (dark ? 0.12 : 0.35) * (1 - i * 0.12)));
    }
  }

  void _palm(Canvas c, Offset base, double height, double lean, double d) {
    final top = Offset(base.dx + lean + d * 3, base.dy - height);
    final ctrl = Offset(base.dx + lean * 0.1, base.dy - height * 0.55);
    final trunkPath = Path()
      ..moveTo(base.dx, base.dy)
      ..quadraticBezierTo(ctrl.dx, ctrl.dy, top.dx, top.dy);
    c.drawPath(trunkPath, Paint()..color = trunk..style = PaintingStyle.stroke..strokeWidth = height * 0.045..strokeCap = StrokeCap.round);
    final leaf = Paint()..color = near;
    final len = height * 0.5;
    for (var i = 0; i < 7; i++) {
      final a = -math.pi * 0.95 + i * (math.pi * 0.95 / 3) + d * 0.04;
      c.save();
      c.translate(top.dx, top.dy);
      c.rotate(a);
      final f = Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(len * 0.5, -len * 0.30, len, len * 0.20)
        ..quadraticBezierTo(len * 0.5, -len * 0.08, 0, 0);
      c.drawPath(f, leaf);
      c.restore();
    }
  }

  // ── Scenes ────────────────────────────────────────────────────

  void _sigiriya(Canvas c, double w, double h, double hz, double d) {
    c.drawPath(_ridge(w, hz * 0.98, 38, 0.6, d * 14), Paint()..color = far.withValues(alpha: 0.65));
    c.drawPath(_ridge(w, hz * 1.02, 30, 2.4, d * 22), Paint()..color = mid.withValues(alpha: 0.85));
    // The rock
    final r = Path()
      ..moveTo(w * 0.06, hz * 1.04)
      ..cubicTo(w * 0.16, hz * 0.88, w * 0.24, hz * 0.74, w * 0.28, hz * 0.62)
      ..lineTo(w * 0.29, hz * 0.55)
      ..quadraticBezierTo(w * 0.34, hz * 0.49, w * 0.40, hz * 0.52)
      ..quadraticBezierTo(w * 0.45, hz * 0.47, w * 0.50, hz * 0.53)
      ..lineTo(w * 0.52, hz * 0.60)
      ..cubicTo(w * 0.54, hz * 0.72, w * 0.62, hz * 0.88, w * 0.78, hz * 1.04)
      ..close();
    c.save();
    c.translate(d * 5, 0);
    c.drawPath(r, Paint()..color = rock);
    // sun-lit face
    c.drawPath(
      Path()
        ..moveTo(w * 0.40, hz * 0.52)
        ..quadraticBezierTo(w * 0.45, hz * 0.47, w * 0.50, hz * 0.53)
        ..lineTo(w * 0.52, hz * 0.60)
        ..cubicTo(w * 0.54, hz * 0.72, w * 0.62, hz * 0.88, w * 0.70, hz * 1.04)
        ..lineTo(w * 0.52, hz * 1.04)
        ..cubicTo(w * 0.50, hz * 0.8, w * 0.46, hz * 0.66, w * 0.40, hz * 0.52)
        ..close(),
      Paint()..color = Colors.white.withValues(alpha: dark ? 0.05 : 0.14),
    );
    c.restore();
    // Jungle
    c.drawPath(_ridge(w, hz * 1.1, 34, 4.1, d * 34), Paint()..color = near);
    c.drawRect(Rect.fromLTRB(0, hz * 1.1, w, h), Paint()..color = near);
    _palm(c, Offset(w * 0.9, hz * 1.12), h * 0.2, -w * 0.06, d);
    _palm(c, Offset(w * 0.1, hz * 1.14), h * 0.15, w * 0.04, d);
  }

  void _ella(Canvas c, double w, double h, double hz, double d) {
    c.drawPath(_ridge(w, hz * 0.8, 46, 1.2, d * 10), Paint()..color = far.withValues(alpha: 0.6));
    c.drawPath(_ridge(w, hz * 0.92, 44, 3.3, d * 20), Paint()..color = mid.withValues(alpha: 0.75));
    c.drawPath(_ridge(w, hz * 1.02, 36, 0.2, d * 30), Paint()..color = mid);
    // Nine Arches viaduct
    final deckY = hz * 0.95;
    final x0 = w * 0.08, x1 = w * 0.92;
    final stone = dark ? const Color(0xFF6C6A60) : const Color(0xFFD8C7A8);
    final body = Rect.fromLTRB(x0, deckY, x1, deckY + h * 0.10);
    c.drawRect(body, Paint()..color = stone);
    c.drawRect(Rect.fromLTRB(x0, deckY - 5, x1, deckY), Paint()..color = stone.withValues(alpha: 0.85));
    const n = 9;
    final aw = (x1 - x0) / n;
    final hole = Paint()..color = mid;
    for (var i = 0; i < n; i++) {
      final cx = x0 + aw * (i + 0.5);
      final r = aw * 0.34;
      final arch = Path()
        ..moveTo(cx - r, body.bottom)
        ..lineTo(cx - r, body.top + h * 0.045)
        ..arcToPoint(Offset(cx + r, body.top + h * 0.045), radius: Radius.circular(r))
        ..lineTo(cx + r, body.bottom)
        ..close();
      c.drawPath(arch, hole);
    }
    c.drawPath(_ridge(w, hz * 1.14, 30, 5.1, d * 36), Paint()..color = near);
    c.drawRect(Rect.fromLTRB(0, hz * 1.14, w, h), Paint()..color = near);
    _palm(c, Offset(w * 0.88, hz * 1.18), h * 0.17, -w * 0.05, d);
  }

  void _galle(Canvas c, double w, double h, double hz, double d) {
    _sea(c, w, h, hz, d);
    // Fort rampart
    final wall = dark ? const Color(0xFF7A6C54) : const Color(0xFFE9D3A8);
    final base = Rect.fromLTRB(-10, hz * 0.96, w * 0.78, hz * 1.12);
    c.drawRect(base, Paint()..color = wall);
    const merlons = 14;
    final mw = base.width / merlons;
    for (var i = 0; i < merlons; i += 2) {
      c.drawRect(Rect.fromLTWH(base.left + i * mw, base.top - 10, mw, 10), Paint()..color = wall);
    }
    c.drawRect(Rect.fromLTRB(-10, hz * 1.12, w, h), Paint()..color = sand);
    // Lighthouse
    final lx = w * 0.62, tw = w * 0.07, th = h * 0.20;
    final tower = Path()
      ..moveTo(lx - tw * 0.6, hz * 0.96)
      ..lineTo(lx - tw * 0.38, hz * 0.96 - th)
      ..lineTo(lx + tw * 0.38, hz * 0.96 - th)
      ..lineTo(lx + tw * 0.6, hz * 0.96)
      ..close();
    c.drawPath(tower, Paint()..color = Colors.white.withValues(alpha: dark ? 0.8 : 1));
    c.drawRect(Rect.fromLTRB(lx - tw * 0.5, hz * 0.96 - th * 0.55, lx + tw * 0.5, hz * 0.96 - th * 0.42), Paint()..color = const Color(0xFF0B2A52));
    c.drawRect(Rect.fromLTRB(lx - tw * 0.45, hz * 0.96 - th - 12, lx + tw * 0.45, hz * 0.96 - th), Paint()..color = const Color(0xFF0B2A52));
    c.drawPath(
      Path()
        ..moveTo(lx - tw * 0.5, hz * 0.96 - th - 12)
        ..lineTo(lx, hz * 0.96 - th - 30)
        ..lineTo(lx + tw * 0.5, hz * 0.96 - th - 12)
        ..close(),
      Paint()..color = const Color(0xFFD64B2A),
    );
    _palm(c, Offset(w * 0.9, hz * 1.2), h * 0.2, -w * 0.07, d);
  }

  void _mirissa(Canvas c, double w, double h, double hz, double d) {
    _sea(c, w, h, hz, d);
    // Sun reflection
    final refl = Paint()..color = sun.withValues(alpha: dark ? 0.2 : 0.5)..strokeWidth = 5..strokeCap = StrokeCap.round;
    for (var i = 0; i < 6; i++) {
      final y = hz + 14 + i * 24.0;
      final half = w * (0.12 - i * 0.012);
      c.drawLine(Offset(w * 0.5 - half + d * 4, y), Offset(w * 0.5 + half + d * 4, y), refl);
    }
    // Stilt boat
    final bx = w * 0.72 + d * 6, by = hz + 6;
    final boat = Path()
      ..moveTo(bx - 34, by)
      ..quadraticBezierTo(bx, by + 14, bx + 34, by)
      ..lineTo(bx + 26, by - 8)
      ..lineTo(bx - 26, by - 8)
      ..close();
    c.drawPath(boat, Paint()..color = const Color(0xFF0B2A52));
    c.drawLine(Offset(bx, by - 8), Offset(bx, by - 46), Paint()..color = const Color(0xFF0B2A52)..strokeWidth = 2.5);
    c.drawPath(Path()..moveTo(bx, by - 46)..lineTo(bx + 26, by - 12)..lineTo(bx, by - 12)..close(), Paint()..color = Colors.white.withValues(alpha: 0.95));
    // Beach + palms
    final beach = Path()
      ..moveTo(-10, hz * 1.35)
      ..quadraticBezierTo(w * 0.35, hz * 1.12, w * 0.7, hz * 1.5)
      ..lineTo(w * 0.7, h)
      ..lineTo(-10, h)
      ..close();
    c.drawPath(beach, Paint()..color = sand);
    _palm(c, Offset(w * 0.08, hz * 1.4), h * 0.26, w * 0.12, d);
    _palm(c, Offset(w * 0.2, hz * 1.46), h * 0.17, w * 0.07, d);
  }

  @override
  bool shouldRepaint(ScenePainter old) => old.t != t || old.scene != scene || old.dark != dark;
}

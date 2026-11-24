import 'package:flutter/material.dart';

/// Hanna Software Series — Bakery ka logo (app icon jaisa): espresso chokor, cream "H", beech mein gold nishaan.
/// Asal design: app_icon/hanna_bakery_icon.svg (512 x 512) — yahan usi naap se CustomPaint.
class HannaBakeryLogo extends StatelessWidget {
  const HannaBakeryLogo({super.key, this.size = 64, this.glow = false});

  final double size;

  /// Gold chamak (hero / license / about par).
  final bool glow;

  /// 'cake' (A: 2 manzila cake + mom batti) ya 'wheat' (B: gandum ki baali).
  static const variant = 'cake';

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.22),
        boxShadow: [
          if (glow) BoxShadow(color: const Color(0xFFD4A24C).withValues(alpha: 0.35), blurRadius: size * 0.4),
          BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: size * 0.12, offset: Offset(0, size * 0.04)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.22),
        child: CustomPaint(size: Size.square(size), painter: const _LogoPainter(variant)),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  const _LogoPainter(this.variant);
  final String variant;

  static const _bg = Color(0xFF2A1A12);
  static const _cream = Color(0xFFF7F0E3);
  static const _gold = Color(0xFFD4A24C);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 512, size.height / 512);
    final fill = Paint()..isAntiAlias = true;

    canvas.drawRect(const Rect.fromLTWH(0, 0, 512, 512), fill..color = _bg);
    // "H" ke do sutoon
    fill.color = _cream;
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(128, 112, 64, 288), const Radius.circular(32)), fill);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(320, 112, 64, 288), const Radius.circular(32)), fill);

    if (variant == 'wheat') {
      _wheat(canvas);
    } else {
      _cake(canvas);
    }
    canvas.restore();
  }

  void _cake(Canvas canvas) {
    final p = Paint()..isAntiAlias = true;
    // mom batti
    p.color = _cream;
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(250, 176, 12, 36), const Radius.circular(6)), p);
    // lau
    p.color = _gold;
    final flame = Path()
      ..moveTo(256, 140)
      ..cubicTo(268, 154, 270, 164, 264, 172)
      ..cubicTo(260, 177, 252, 177, 248, 172)
      ..cubicTo(242, 164, 244, 154, 256, 140)
      ..close();
    canvas.drawPath(flame, p);
    // upar aur neeche wali manzil
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(220, 214, 72, 46), const Radius.circular(12)), p);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(200, 266, 112, 60), const Radius.circular(14)), p);
    // cream ki lehar
    final drip = Path()
      ..moveTo(200, 286)
      ..quadraticBezierTo(214, 298, 228, 286)
      ..quadraticBezierTo(242, 298, 256, 286)
      ..quadraticBezierTo(270, 298, 284, 286)
      ..quadraticBezierTo(298, 298, 312, 286);
    canvas.drawPath(
        drip,
        Paint()
          ..isAntiAlias = true
          ..color = _bg
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round);
  }

  void _wheat(Canvas canvas) {
    final p = Paint()
      ..isAntiAlias = true
      ..color = _gold;
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(251, 160, 10, 196), const Radius.circular(5)), p);
    canvas.drawOval(Rect.fromCenter(center: const Offset(256, 166), width: 26, height: 48), p);
    for (final y in const [210.0, 252.0, 294.0]) {
      for (final side in const [-1.0, 1.0]) {
        canvas.save();
        canvas.translate(256 + 22 * side, y);
        canvas.rotate(side * 38 * 3.1415926535 / 180);
        canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 24, height: 48), p);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LogoPainter old) => old.variant != variant;
}

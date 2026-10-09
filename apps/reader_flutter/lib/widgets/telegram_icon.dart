import 'package:flutter/material.dart';

/// Official-style Telegram paper-plane mark (not a Material glyph).
class TelegramIcon extends StatelessWidget {
  const TelegramIcon({
    super.key,
    this.size = 20,
    this.color = const Color(0xFF229ED9),
    this.filled = true,
  });

  final double size;
  final Color color;

  /// When true, draws the blue circle badge with a white plane.
  /// When false, draws only the plane in [color] (for colored buttons).
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _TelegramPainter(color: color, filled: filled),
      ),
    );
  }
}

class _TelegramPainter extends CustomPainter {
  const _TelegramPainter({required this.color, required this.filled});

  final Color color;
  final bool filled;

  Path _planePath() {
    return Path()
      ..moveTo(5.2, 11.7)
      ..lineTo(18.8, 6.2)
      ..cubicTo(19.5, 5.9, 20.1, 6.4, 19.9, 7.2)
      ..lineTo(17.4, 17.4)
      ..cubicTo(17.2, 18.2, 16.5, 18.4, 15.9, 18.0)
      ..lineTo(12.5, 15.5)
      ..lineTo(10.7, 17.2)
      ..cubicTo(10.5, 17.4, 10.3, 17.4, 10.2, 17.2)
      ..lineTo(10.0, 13.6)
      ..lineTo(16.0, 8.4)
      ..lineTo(8.5, 12.6)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    canvas.scale(scale);

    if (filled) {
      canvas.drawCircle(
        const Offset(12, 12),
        12,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill,
      );
      canvas.drawPath(
        _planePath(),
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill,
      );
    } else {
      canvas.drawPath(
        _planePath(),
        Paint()
          ..color = color
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TelegramPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.filled != filled;
}

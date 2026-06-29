import 'package:flutter/material.dart';

import '../design/app_tokens.dart';
import '../models/book_models.dart';

const _cyanGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF14708F), Color(0xFF29B6E0), Color(0xFF5CCDEC)],
  stops: [0.0, 0.55, 1.0],
);

const _deepBlueGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF0A3A4A), Color(0xFF1E9BC2), Color(0xFF14708F)],
  stops: [0.0, 0.55, 1.0],
);

LinearGradient catalogBookGradient(int index) {
  return index.isEven ? _cyanGradient : _deepBlueGradient;
}

Color catalogBookAccentColor(int index) {
  return index.isEven ? AppColors.referencePrimary : AppColors.referenceSecondary;
}

IconData catalogBookIcon(BookSummary book, int index) {
  final t = book.title.toLowerCase();
  if (t.contains('mezmur') || t.contains('psalm') || t.contains('dawit')) {
    return Icons.music_note_rounded;
  }
  if (t.contains('wudase') || t.contains('weddase') || t.contains('mary')) {
    return Icons.favorite_rounded;
  }
  if (t.contains('kidase') ||
      t.contains('qeddase') ||
      t.contains('liturgy') ||
      t.contains('anaphora')) {
    return Icons.local_fire_department_rounded;
  }
  if (t.contains('senkes') || t.contains('synax') || t.contains('calendar')) {
    return Icons.calendar_month_rounded;
  }
  if (t.contains('gedle') || t.contains('saint') || t.contains('hagi')) {
    return Icons.self_improvement_rounded;
  }
  const defaults = [
    Icons.menu_book_rounded,
    Icons.auto_stories_rounded,
    Icons.history_edu_rounded,
    Icons.church_rounded,
  ];
  return defaults[index % defaults.length];
}

class CatalogCrossWatermark extends StatelessWidget {
  const CatalogCrossWatermark({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: -8,
      right: -8,
      child: IgnorePointer(
        child: Opacity(
          opacity: 0.16,
          child: CustomPaint(
            size: const Size(72, 72),
            painter: _CrossWatermarkPainter(),
          ),
        ),
      ),
    );
  }
}

class _CrossWatermarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final cx = size.width * 0.55;
    final cy = size.height * 0.45;
    final r = size.width * 0.28;

    canvas.drawCircle(Offset(cx, cy), r, paint);
    canvas.drawLine(Offset(cx, cy - r), Offset(cx, cy + r), paint);
    canvas.drawLine(Offset(cx - r, cy), Offset(cx + r, cy), paint);
    canvas.drawLine(
      Offset(cx - r * 0.65, cy - r * 0.65),
      Offset(cx + r * 0.65, cy + r * 0.65),
      paint,
    );
    canvas.drawLine(
      Offset(cx + r * 0.65, cy - r * 0.65),
      Offset(cx - r * 0.65, cy + r * 0.65),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logbook_app_081/features/vision/dto/detection_result.dart';

class DamagePainter extends CustomPainter {
  final List<DetectionResult> results;

  const DamagePainter(this.results);

  @override
  void paint(Canvas canvas, Size size) {
    for (final result in results) {
      final bool isCrack = result.label.contains('CRACK');
      final Color boxColor =
          isCrack ? const Color(0xFFFFB74D) : Colors.redAccent;
      final rect = result.toRect(size);
      final outlinePaint = Paint()
        ..color = boxColor
        ..strokeWidth = 3.0
        ..style = PaintingStyle.stroke;

      final fillPaint = Paint()
        ..color = boxColor.withOpacity(0.08)
        ..style = PaintingStyle.fill;

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(12)),
        fillPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(12)),
        outlinePaint,
      );

      final textPainter = TextPainter(
        text: TextSpan(
          text: '${result.label} ${(result.score * 100).toStringAsFixed(0)}%',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            shadows: [
              Shadow(
                  color: Colors.black87, blurRadius: 4, offset: Offset(0, 1)),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final textStrokePainter = TextPainter(
        text: TextSpan(
          text: '${result.label} ${(result.score * 100).toStringAsFixed(0)}%',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = Colors.black,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      const EdgeInsets labelPadding =
          EdgeInsets.symmetric(horizontal: 10, vertical: 6);
      final double labelWidth = textPainter.width + labelPadding.horizontal;
      final double labelHeight = textPainter.height + labelPadding.vertical;
      final double labelLeft =
          rect.left.clamp(8.0, size.width - labelWidth - 8.0);
      final double labelTop = (rect.top - labelHeight - 10)
          .clamp(8.0, size.height - labelHeight - 8.0);
      final RRect labelRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(labelLeft, labelTop, labelWidth, labelHeight),
        const Radius.circular(10),
      );

      final Paint labelBackgroundPaint = Paint()
        ..color = Colors.black.withOpacity(0.78)
        ..style = PaintingStyle.fill;

      canvas.drawRRect(labelRect, labelBackgroundPaint);
      textStrokePainter.paint(
        canvas,
        Offset(labelLeft + labelPadding.left, labelTop + labelPadding.top),
      );
      textPainter.paint(
        canvas,
        Offset(labelLeft + labelPadding.left, labelTop + labelPadding.top),
      );

      final TextPainter statusPainter = TextPainter(
        text: const TextSpan(
          text: 'Searching for Road Damage...',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            shadows: [
              Shadow(
                  color: Colors.black87, blurRadius: 4, offset: Offset(0, 1)),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final TextPainter statusStrokePainter = TextPainter(
        text: TextSpan(
          text: 'Searching for Road Damage...',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.8
              ..color = Colors.black,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      const EdgeInsets statusPadding =
          EdgeInsets.symmetric(horizontal: 8, vertical: 5);
      final double statusWidth = statusPainter.width + statusPadding.horizontal;
      final double statusHeight = statusPainter.height + statusPadding.vertical;
      final double statusLeft =
          rect.left.clamp(8.0, size.width - statusWidth - 8.0);
      final double statusTop = (labelTop - statusHeight - 8)
          .clamp(8.0, size.height - statusHeight - 8.0);

      final Paint statusBgPaint = Paint()
        ..color = Colors.blueGrey.withOpacity(0.82)
        ..style = PaintingStyle.fill;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(statusLeft, statusTop, statusWidth, statusHeight),
          const Radius.circular(9),
        ),
        statusBgPaint,
      );
      statusStrokePainter.paint(
        canvas,
        Offset(statusLeft + statusPadding.left, statusTop + statusPadding.top),
      );
      statusPainter.paint(
        canvas,
        Offset(statusLeft + statusPadding.left, statusTop + statusPadding.top),
      );
    }
  }

  @override
  bool shouldRepaint(covariant DamagePainter oldDelegate) {
    return !listEquals(oldDelegate.results, results);
  }
}

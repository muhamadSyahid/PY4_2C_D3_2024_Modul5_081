import 'dart:ui';

class DetectionResult {
  final Offset normalizedCenter;
  final double normalizedWidth;
  final double normalizedHeight;
  final String label;
  final double score;

  const DetectionResult({
    required this.normalizedCenter,
    required this.normalizedWidth,
    required this.normalizedHeight,
    required this.label,
    required this.score,
  });

  Rect toRect(Size canvasSize) {
    final double width = canvasSize.width * normalizedWidth;
    final double height = canvasSize.width * normalizedHeight;
    final double left = (canvasSize.width * normalizedCenter.dx) - width / 2;
    final double top = (canvasSize.height * normalizedCenter.dy) - height / 2;

    return Rect.fromLTWH(
      left.clamp(0.0, canvasSize.width - width),
      top.clamp(0.0, canvasSize.height - height),
      width,
      height,
    );
  }
}

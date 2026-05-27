import 'dart:ui';
import 'dart:typed_data';
import '../models/visualizer_settings.dart';

abstract class SpectrumPainter {
  static void drawSpectrum(
    Canvas canvas,
    Size size,
    Float64List heights,
    VisualizerSettings settings, {
    Color? barColor,
    double? barGap,
    double? cornerRadius,
  }) {
    final barCount = settings.barCount;
    final gap = barGap ?? settings.spacing;
    final barWidth = settings.barWidth;
    final radius = Radius.circular(cornerRadius ?? settings.cornerRadius);

    final actualWidth = barCount * (barWidth + gap) - gap;
    final offsetX = (size.width - actualWidth) / 2;
    final centerY = size.height / 2;

    final paint = Paint()
      ..color = barColor ?? settings.positiveColor
      ..style = PaintingStyle.fill;

    for (int i = 0; i < barCount; i++) {
      final clamped = heights[i].clamp(0.0, 1.0);
      final topH = clamped * size.height * settings.positiveHeightScale;
      final bottomH = clamped * size.height * settings.negativeHeightScale;
      final x = i * (barWidth + gap) + offsetX;

      if (topH > 0) {
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(x, centerY - topH, barWidth, topH),
            topLeft: radius,
            topRight: radius,
          ),
          paint,
        );
      }

      if (bottomH > 0) {
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(x, centerY, barWidth, bottomH),
            bottomLeft: radius,
            bottomRight: radius,
          ),
          paint,
        );
      }
    }
  }
}

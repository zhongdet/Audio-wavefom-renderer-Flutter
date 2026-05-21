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
      final h = heights[i].clamp(0.0, 1.0) * size.height * settings.positiveHeightScale;
      final x = i * (barWidth + gap) + offsetX;
      final top = centerY - h / 2;

      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(x, top, barWidth, h),
        topLeft: radius,
        topRight: radius,
      );

      canvas.drawRRect(rect, paint);
    }
  }
}

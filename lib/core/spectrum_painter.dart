import 'dart:ui';
import 'dart:typed_data';
import '../core/visualizer_settings.dart';

abstract class SpectrumPainter {
  static void drawSpectrum(
    Canvas canvas,
    Size size,
    Float64List heights,
    VisualizerSettings settings, {
    Color barColor = const Color(0xFF00E5FF),
    double barGap = 2.0,
    double cornerRadius = 2.0,
  }) {
    final barCount = settings.barCount;
    final barWidth = (size.width - (barCount - 1) * barGap) / barCount;

    final paint = Paint()
      ..color = barColor
      ..style = PaintingStyle.fill;

    final radius = Radius.circular(cornerRadius);

    for (int i = 0; i < barCount; i++) {
      final h = heights[i].clamp(0.0, 1.0) * size.height;
      final x = i * (barWidth + barGap);
      final top = size.height - h;

      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(x, top, barWidth, h),
        topLeft: radius,
        topRight: radius,
      );

      canvas.drawRRect(rect, paint);
    }
  }

  static void drawWave(
    Canvas canvas,
    Size size,
    Float32List samples, {
    Color waveColor = const Color(0xFFFFFFFF),
    double strokeWidth = 1.5,
    double amplitudeScale = 0.4,
  }) {
    final path = Path();
    final paint = Paint()
      ..color = waveColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final len = samples.length;
    for (int i = 0; i < len; i++) {
      final x = i * (size.width / (len - 1));
      final y = size.height / 2 - samples[i] * size.height * amplitudeScale;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }
}

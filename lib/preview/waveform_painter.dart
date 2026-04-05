import 'dart:typed_data';
import 'package:flutter/widgets.dart';
import '../core/spectrum_painter.dart';
import '../core/visualizer_settings.dart';

class WaveformPainter extends CustomPainter {
  WaveformPainter({
    required this.heights,
    required this.waveformSamples,
    required this.settings,
  });

  final Float64List heights;
  final Float32List waveformSamples;
  final VisualizerSettings settings;

  @override
  void paint(Canvas canvas, Size size) {
    SpectrumPainter.drawSpectrum(canvas, size, heights, settings);
    // SpectrumPainter.drawWave(canvas, size, waveformSamples);
  }

  @override
  bool shouldRepaint(WaveformPainter old) => !identical(heights, old.heights);
}

import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/core/spectrum_painter.dart';
import 'package:flutter_application_1/core/visualizer_settings.dart';

void main() {
  group('SpectrumPainter', () {
    test('drawSpectrum produces a non-empty picture', () {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const settings = VisualizerSettings();
      final heights = Float64List(64);
      for (int i = 0; i < 64; i++) {
        heights[i] = i / 64.0;
      }

      SpectrumPainter.drawSpectrum(
        canvas,
        const Size(390, 200),
        heights,
        settings,
      );

      final picture = recorder.endRecording();
      expect(picture, isNotNull);
      picture.dispose();
    });

    test('drawWave produces a non-empty picture', () {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final samples = Float32List(4096);
      for (int i = 0; i < 4096; i++) {
        samples[i] = (i / 4096.0 * 2 - 1) * 0.5;
      }

      SpectrumPainter.drawWave(canvas, const Size(390, 200), samples);

      final picture = recorder.endRecording();
      expect(picture, isNotNull);
      picture.dispose();
    });

    test('drawSpectrum works with export size', () {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const settings = VisualizerSettings();
      final heights = Float64List(64);

      SpectrumPainter.drawSpectrum(
        canvas,
        const Size(1280, 720),
        heights,
        settings,
      );

      final picture = recorder.endRecording();
      expect(picture, isNotNull);
      picture.dispose();
    });

    test('drawWave works with export size', () {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final samples = Float32List(4096);

      SpectrumPainter.drawWave(canvas, const Size(1280, 720), samples);

      final picture = recorder.endRecording();
      expect(picture, isNotNull);
      picture.dispose();
    });
  });
}

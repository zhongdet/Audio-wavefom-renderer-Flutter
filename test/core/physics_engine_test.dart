import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/core/physics_engine.dart';
import 'package:flutter_application_1/core/visualizer_settings.dart';
import 'package:flutter_application_1/core/frequency_bands.dart';
import 'package:flutter_application_1/core/constants.dart';

void main() {
  group('PhysicsEngine', () {
    late PhysicsEngine engine;
    const settings = VisualizerSettings();
    final bands = generateFrequencyBands(64, 44100);

    setUp(() {
      engine = PhysicsEngine(settings, bands);
    });

    test('initial heights are all zero', () {
      final heights = engine.currentHeights;
      for (final h in heights) {
        expect(h, 0.0);
      }
    });

    test('decay to zero with zero magnitudes', () {
      final magnitudes = Float64List(kFftSize ~/ 2);
      const dt = 1.0 / 60;

      for (int i = 0; i < 60; i++) {
        engine.step(magnitudes, dt);
      }

      final heights = engine.currentHeights;
      for (final h in heights) {
        expect(h, closeTo(0.0, 1e-10), reason: 'height should decay to zero');
      }
    });

    test('attack with max magnitude input', () {
      final magnitudes = Float64List(kFftSize ~/ 2);
      for (int i = 0; i < magnitudes.length; i++) {
        magnitudes[i] = 1.0;
      }
      const dt = 1.0 / 60;

      for (int i = 0; i < 120; i++) {
        engine.step(magnitudes, dt);
      }

      final heights = engine.currentHeights;
      for (final h in heights) {
        expect(h, greaterThan(0.0), reason: 'height should be positive');
        expect(
          h,
          lessThanOrEqualTo(1.1),
          reason: 'height should not exceed 1.1',
        );
      }
    });

    test('soft ceiling compression', () {
      final magnitudes = Float64List(kFftSize ~/ 2);
      for (int i = 0; i < magnitudes.length; i++) {
        magnitudes[i] = 10.0;
      }
      const dt = 1.0 / 60;

      for (int i = 0; i < 200; i++) {
        engine.step(magnitudes, dt);
      }

      final heights = engine.currentHeights;
      for (final h in heights) {
        expect(
          h,
          lessThanOrEqualTo(1.1),
          reason: 'soft ceiling should limit heights',
        );
      }
    });

    test('soft ceiling compression', () {
      final magnitudes = Float64List(kFftSize ~/ 2);
      for (int i = 0; i < magnitudes.length; i++) {
        magnitudes[i] = 10.0;
      }
      const dt = 1.0 / 60;

      for (int i = 0; i < 200; i++) {
        engine.step(magnitudes, dt);
      }

      final heights = engine.currentHeights;
      for (final h in heights) {
        expect(
          h,
          lessThanOrEqualTo(1.1),
          reason: 'soft ceiling should limit heights',
        );
      }
    });

    test('reset clears all heights', () {
      final magnitudes = Float64List(kFftSize ~/ 2);
      for (int i = 0; i < magnitudes.length; i++) {
        magnitudes[i] = 1.0;
      }
      const dt = 1.0 / 60;

      for (int i = 0; i < 10; i++) {
        engine.step(magnitudes, dt);
      }

      engine.reset();
      final heights = engine.currentHeights;
      for (final h in heights) {
        expect(h, 0.0);
      }
    });

    test('step returns same reference', () {
      final magnitudes = Float64List(kFftSize ~/ 2);
      const dt = 1.0 / 60;

      final result1 = engine.step(magnitudes, dt);
      final result2 = engine.step(magnitudes, dt);

      expect(
        identical(result1, result2),
        isTrue,
        reason: 'step should return same reference for efficiency',
      );
    });
  });
}

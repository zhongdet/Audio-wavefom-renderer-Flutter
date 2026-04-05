import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/core/visualizer_settings.dart';

void main() {
  test('const construction with defaults', () {
    const settings = VisualizerSettings();
    expect(settings.barCount, 64);
    expect(settings.attack, 0.05);
    expect(settings.decay, 0.92);
    expect(settings.contrast, 1.2);
    expect(settings.barHeightMultiplier, 1.0);
    expect(settings.softCeilingThreshold, 0.7);
    expect(settings.softCeilingStrength, 2.0);
    expect(settings.referenceFps, 60);
  });

  test('copyWith changes only specified field', () {
    const original = VisualizerSettings();
    final modified = original.copyWith(barCount: 32);

    expect(modified.barCount, 32);
    expect(modified.attack, original.attack);
    expect(modified.decay, original.decay);
    expect(modified.contrast, original.contrast);
    expect(modified.barHeightMultiplier, original.barHeightMultiplier);
    expect(modified.softCeilingThreshold, original.softCeilingThreshold);
    expect(modified.softCeilingStrength, original.softCeilingStrength);
    expect(modified.referenceFps, original.referenceFps);
  });

  test('copyWith with multiple fields', () {
    const original = VisualizerSettings();
    final modified = original.copyWith(barCount: 128, attack: 0.1, decay: 0.8);

    expect(modified.barCount, 128);
    expect(modified.attack, 0.1);
    expect(modified.decay, 0.8);
    expect(modified.contrast, original.contrast);
  });

  test('const instances are identical', () {
    const a = VisualizerSettings();
    const b = VisualizerSettings();
    expect(identical(a, b), isTrue);
  });
}

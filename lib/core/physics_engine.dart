import 'dart:math';
import 'dart:typed_data';
import 'visualizer_settings.dart';

class PhysicsEngine {
  final VisualizerSettings settings;
  final List<(int, int)> bands;
  final Float64List _heights;

  PhysicsEngine(this.settings, this.bands)
    : _heights = Float64List(bands.length);

  Float64List get currentHeights => Float64List.fromList(_heights);

  Float64List step(Float64List magnitudes, double dt) {
    final dtRatio = dt / (1.0 / settings.referenceFps);
    final attack = 1 - pow(1 - settings.attack, dtRatio);
    final decay = pow(settings.decay, dtRatio);

    double maxMag = 0;
    for (var i = 0; i < magnitudes.length; i++) {
      if (magnitudes[i] > maxMag) maxMag = magnitudes[i];
    }
    if (maxMag < 1e-10) maxMag = 1e-10;
    final contrast = settings.contrast;

    for (int b = 0; b < bands.length; b++) {
      final (start, end) = bands[b];
      double sum = 0;
      int count = 0;
      for (int i = start; i < end; i++) {
        sum += magnitudes[i];
        count++;
      }
      double avg = count > 0 ? sum / count : 0;
      double target = (avg / maxMag) * contrast;
      target *= settings.barHeightMultiplier;

      final threshold = settings.softCeilingThreshold;
      final strength = settings.softCeilingStrength;
      if (target > threshold) {
        final excess = target - threshold;
        target = threshold + (1 - exp(-excess * strength)) / strength;
      }

      if (target > _heights[b]) {
        _heights[b] += (target - _heights[b]) * attack;
      } else {
        _heights[b] = max(0, _heights[b] * decay);
      }
    }

    return _heights;
  }

  void reset() {
    for (int i = 0; i < _heights.length; i++) {
      _heights[i] = 0;
    }
  }
}

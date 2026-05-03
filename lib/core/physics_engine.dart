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

    // 计算全局最大值 (与 TypeScript 一致)
    double globalMax = 0;
    for (int i = 0; i < magnitudes.length; i++) {
      if (magnitudes[i] > globalMax) globalMax = magnitudes[i];
    }
    if (globalMax < 0.001) globalMax = 0.001;

    for (int b = 0; b < bands.length; b++) {
      final (start, end) = bands[b];

      // 取 band 内的最大值 (而非平均值)
      double localMax = 0;
      final limit = end < magnitudes.length ? end : magnitudes.length;
      for (int bin = start; bin < limit; bin++) {
        if (magnitudes[bin] > localMax) localMax = magnitudes[bin];
      }

      // 使用 TypeScript 的 target 公式
      double target = pow(localMax / globalMax, settings.contrast).toDouble() *
          settings.barHeightMultiplier;
      target *= 1.1; // 补偿係數
      if (target < 0) target = 0;

      // Soft Ceiling 壓縮邏輯
      final threshold = settings.softCeilingThreshold;
      final strength = settings.softCeilingStrength;
      if (target > threshold) {
        final excess = target - threshold;
        target = threshold + (1 - exp(-excess * strength)) / strength;
      }

      // 應用 Attack 與 Decay (包含 maxDropRatio)
      if (target > _heights[b]) {
        _heights[b] += (target - _heights[b]) * attack;
      } else {
        double nextValue = _heights[b] * decay;
        const maxDropRatio = 1.0;
        if (_heights[b] - nextValue > _heights[b] * maxDropRatio) {
          nextValue = _heights[b] * (1 - maxDropRatio);
        }
        _heights[b] = nextValue;
      }
      _heights[b] = max(0, _heights[b]);
    }

    return _heights;
  }

  void reset() {
    for (int i = 0; i < _heights.length; i++) {
      _heights[i] = 0;
    }
  }
}

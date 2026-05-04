import 'dart:math';
import 'dart:typed_data';
import 'visualizer_settings.dart';

class PhysicsEngine {
  final VisualizerSettings settings;
  final List<(int, int)> bands;
  final Float64List _heights;

  PhysicsEngine(this.settings, this.bands)
    : _heights = Float64List(bands.length);

  Float64List get currentHeights => _heights;

  Float64List step(Float32List magnitudes, double dt) {
    // 根據 dt 計算補償比率，參考 FPS 設為 settings.referenceFps 或預設 60
    final double referenceFps = 60.0; 
    final double dtRatio = dt / (1.0 / referenceFps);

    // 應用精確的 Attack/Decay 插值
    final attack = 1 - pow(1 - settings.attack, dtRatio);
    final decay = pow(settings.decay, dtRatio);

    for (int b = 0; b < bands.length; b++) {
      final (start, end) = bands[b];

      // 取頻段內最大值
      double localMax = 0;
      final limit = end < magnitudes.length ? end : magnitudes.length;
      for (int bin = start; bin < limit; bin++) {
        if (magnitudes[bin] > localMax) localMax = magnitudes[bin];
      }

      // 棄用 globalMax，回歸絕對強度計算
      // 這裡使用 0.007 作為基準縮放係數（與 TypeScript 版本一致）
      double target = pow(localMax, settings.contrast).toDouble() * 
          0.7 * 
          settings.barHeightMultiplier;
          
      target = max(0, target);

      // Soft Ceiling 壓縮邏輯
      final threshold = settings.softCeilingThreshold;
      final strength = settings.softCeilingStrength;
      if (target > threshold) {
        final excess = target - threshold;
        target = threshold + (1 - exp(-excess * strength)) / strength;
      }

      // 應用 Attack 與 Decay
      if (target > _heights[b]) {
        _heights[b] += (target - _heights[b]) * attack;
      } else {
        double nextValue = _heights[b] * decay;
        
        // 保留原有的 maxDropRatio 結構
        const maxDropRatio = 1.0;
        if (_heights[b] - nextValue > _heights[b] * maxDropRatio) {
          nextValue = _heights[b] * (1 - maxDropRatio);
        }
        _heights[b] = nextValue;
      }
      
      _heights[b] = max(0.001, _heights[b]);
    }

    return _heights;
  }

  void reset() {
    for (int i = 0; i < _heights.length; i++) {
      _heights[i] = 0;
    }
  }
}
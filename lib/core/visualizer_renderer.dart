import 'dart:typed_data';
import 'physics_engine.dart';
import 'frequency_bands.dart';
import 'visualizer_settings.dart' as core;

class VisualizerRenderer {
  VisualizerRenderer({
    required core.VisualizerSettings coreSettings,
    required this.barCount,
    required this.sampleRate,
    this.minFreq = 20.0,
    this.maxFreq = 16000.0,
  }) : _engine = PhysicsEngine(coreSettings, _generateBands(barCount, sampleRate, minFreq, maxFreq));

  final int barCount;
  final int sampleRate;
  final double minFreq;
  final double maxFreq;
  final PhysicsEngine _engine;

  static List<(int, int)> _generateBands(int barCount, int sampleRate, double minFreq, double maxFreq) {
    return generateFrequencyBands(
      barCount,
      sampleRate,
      minFreq: minFreq,
      maxFreq: maxFreq,
    );
  }

  Float64List computeHeights(Float64List magnitudes, double dt) {
    return _engine.step(magnitudes, dt);
  }

  Float64List get currentHeights => _engine.currentHeights;

  void reset() {
    _engine.reset();
  }
}

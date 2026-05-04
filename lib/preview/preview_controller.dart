import 'package:flutter/foundation.dart';
import '../core/visualizer_renderer.dart';
import '../audio/audio_processor.dart';
import '../models/visualizer_settings.dart';

class PreviewController extends ChangeNotifier {
  PreviewController(AudioProcessor processor, VisualizerSettings settings)
    : _processor = processor,
      _renderer = VisualizerRenderer(
        coreSettings: settings.toCoreSettings(),
        barCount: settings.barCount,
        sampleRate: processor.sampleRate,
        minFreq: settings.minFreq.toDouble(),
        maxFreq: settings.maxFreq.toDouble(),
      ),
      _stftFps = processor.sampleRate / (4096 * 0.5);

  final AudioProcessor _processor;
  final VisualizerRenderer _renderer;
  final double _stftFps;

  Float64List get heights => _renderer.currentHeights;

  double get timerIntervalMs => 1000.0 / _stftFps;

  void tick(Duration position) {
    if (_processor.totalFrameCount == 0) return;

    final frame = _processor.getFrameAt(position);
    final dt = 1.0 / _stftFps;

    _renderer.computeHeights(frame.magnitudes, dt);
    notifyListeners();
  }

  void stop() {
    _renderer.reset();
    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}

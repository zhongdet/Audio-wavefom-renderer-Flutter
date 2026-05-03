import 'package:flutter/foundation.dart';
import '../core/visualizer_renderer.dart';
import '../audio/audio_processor.dart';
import '../models/visualizer_settings.dart';

class PreviewController extends ChangeNotifier {
  PreviewController(AudioProcessor processor, VisualizerSettings settings)
    : _processor = processor,
      _settings = settings,
      _renderer = VisualizerRenderer(
        coreSettings: settings.toCoreSettings(),
        barCount: settings.barCount,
        sampleRate: processor.sampleRate,
        minFreq: settings.minFreq.toDouble(),
        maxFreq: settings.maxFreq.toDouble(),
      ),
      _heights = Float64List(settings.barCount),
      _lastTickTime = null;

  final AudioProcessor _processor;
  final VisualizerSettings _settings;
  final VisualizerRenderer _renderer;

  Float64List _heights;
  DateTime? _lastTickTime;

  Float64List get heights => _heights;

  double _getDefaultDt() => 1.0 / (_settings.referenceFps > 0 ? _settings.referenceFps : 60);

  void tick(Duration position) {
    if (_processor.frames.isEmpty) return;

    final frame = _processor.getFrameAt(position);

    // 计算实际 dt，与 TypeScript 代码一致
    final now = DateTime.now();
    double dt;
    if (_lastTickTime != null) {
      dt = now.difference(_lastTickTime!).inMicroseconds / 1e6;
    } else {
      dt = _getDefaultDt();
    }
    _lastTickTime = now;

    if (dt <= 0) dt = _getDefaultDt();

    _renderer.computeHeights(frame.magnitudes, dt);
    _heights = _renderer.currentHeights;
    notifyListeners();
  }

  void stop() {
    _renderer.reset();
    _heights = Float64List(_settings.barCount);
    _lastTickTime = null;
    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}

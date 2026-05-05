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

  DateTime? _lastTickTime;
  int _tickCount = 0;

  void tick(Duration position) {
    if (_processor.totalFrameCount == 0) return;

    _tickCount++;
    final now = DateTime.now();
    final timeSinceLastTick = _lastTickTime != null 
        ? now.difference(_lastTickTime!).inMicroseconds / 1000.0 
        : 0.0;
    _lastTickTime = now;

    final stopwatch = Stopwatch()..start();
    final frame = _processor.getFrameAt(position);
    final getFrameTime = stopwatch.elapsedMicroseconds / 1000.0;

    final dt = 1.0 / _stftFps;
    final expectedIntervalMs = dt * 1000;

    stopwatch.reset();
    _renderer.computeHeights(frame.magnitudes, dt);
    final computeTime = stopwatch.elapsedMicroseconds / 1000.0;

    debugPrint('[PreviewController.tick] #$_tickCount: '
        'interval=${timeSinceLastTick.toStringAsFixed(2)}ms '
        '(expected=${expectedIntervalMs.toStringAsFixed(2)}ms), '
        'getFrame=${getFrameTime.toStringAsFixed(2)}ms, '
        'compute=${computeTime.toStringAsFixed(2)}ms, '
        'position=${position.inMilliseconds}ms');

    if (timeSinceLastTick > expectedIntervalMs * 1.5 && _tickCount > 1) {
      debugPrint('[PreviewController] WARNING: Tick interval (${timeSinceLastTick.toStringAsFixed(2)}ms) '
          'is much larger than expected (${expectedIntervalMs.toStringAsFixed(2)}ms)');
    }

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

import 'package:flutter/foundation.dart';
import '../core/physics_engine.dart';
import '../audio/audio_processor.dart';
import '../core/visualizer_settings.dart';
import '../core/frequency_bands.dart';
import '../core/constants.dart';

class PreviewController extends ChangeNotifier {
  PreviewController(this._processor, this._settings)
    : _engine = PhysicsEngine(
        _settings,
        generateFrequencyBands(
          _settings.barCount,
          44100,
          minFreq: kMinFreq,
          maxFreq: kMaxFreq,
        ),
      ),
      _heights = Float64List(_settings.barCount),
      _waveformSamples = Float32List(kFftSize);

  final AudioProcessor _processor;
  final VisualizerSettings _settings;
  final PhysicsEngine _engine;

  Float64List _heights;
  Float32List _waveformSamples;

  Float64List get heights => _heights;
  Float32List get waveformSamples => _waveformSamples;

  void tick(Duration position) {
    if (_processor.frames.isEmpty) return;

    final frame = _processor.getFrameAt(position);
    const dt = 1.0 / 60;

    _engine.step(frame.magnitudes, dt);
    _heights = _engine.currentHeights;
    _waveformSamples = frame.waveformSamples;
    notifyListeners();
  }

  void stop() {
    _engine.reset();
    _heights = Float64List(_settings.barCount);
    _waveformSamples = Float32List(kFftSize);
    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}

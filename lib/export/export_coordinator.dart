import 'dart:async';
import '../core/constants.dart';
import '../core/physics_engine.dart';
import '../core/visualizer_settings.dart';
import '../core/frequency_bands.dart';
import '../audio/audio_processor.dart';
import 'offscreen_renderer.dart';
import 'ffmpeg_exporter.dart';

class ExportCoordinator {
  ExportCoordinator({
    required AudioProcessor processor,
    required VisualizerSettings settings,
  }) : _processor = processor,
       _settings = settings,
       _bands = generateFrequencyBands(
         settings.barCount,
         processor.sampleRate,
         minFreq: kMinFreq,
         maxFreq: kMaxFreq,
       );

  final AudioProcessor _processor;
  final VisualizerSettings _settings;
  final List<(int, int)> _bands;
  final _progressController = StreamController<double>.broadcast();
  bool _cancelled = false;

  Stream<double> get progress => _progressController.stream;

  int _estimateTotalFrames() {
    final totalDuration = _processor.totalDuration;
    if (totalDuration.inMicroseconds <= 0) return 0;
    return (totalDuration.inMicroseconds / 1e6 / kExportDt).ceil();
  }

  Future<String> startExport() async {
    _cancelled = false;
    final exporter = FFmpegExporter();
    final renderer = OffscreenRenderer();
    final engine = PhysicsEngine(_settings, _bands);

    final rawPath = await exporter.setupRawFile();

    int frameIndex = 0;
    final totalFrames = _estimateTotalFrames();

    try {
      final frames = _processor.frames;
      for (final frame in frames) {
        if (_cancelled) break;

        final heights = engine.step(frame.magnitudes, kExportDt);
        final pixels = await renderer.renderFrame(
          heights,
          frame.waveformSamples,
          _settings,
        );
        exporter.writeFrame(pixels);
        _progressController.add(frameIndex / totalFrames);
        frameIndex++;
      }

      final outputPath = await exporter.executeCommand();
      _progressController.add(1.0);
      return outputPath;
    } catch (e) {
      rethrow;
    } finally {
      await exporter.cleanup();
    }
  }

  void cancel() {
    _cancelled = true;
  }

  void dispose() {
    _progressController.close();
  }
}

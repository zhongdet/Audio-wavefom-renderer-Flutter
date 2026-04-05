import 'dart:async';
import 'dart:io';
import 'package:pool/pool.dart';
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
    final pool = Pool(kPoolSize);
    final pipe = File(await exporter.setupPipe());

    final ffmpegFuture = exporter.executeCommand();

    int frameIndex = 0;
    final totalFrames = _estimateTotalFrames();

    try {
      final frames = _processor.frames;
      for (final frame in frames) {
        if (_cancelled) break;

        await pool.withResource(() async {
          if (_cancelled) return;

          final heights = engine.step(frame.magnitudes, kExportDt);
          final pixels = await renderer.renderFrame(
            heights,
            frame.waveformSamples,
            _settings,
          );
          await pipe.writeAsBytes(pixels, mode: FileMode.append, flush: false);
          _progressController.add(frameIndex / totalFrames);
          frameIndex++;
        });
      }

      await exporter.closePipe();
      final outputPath = await ffmpegFuture;
      _progressController.add(1.0);
      return outputPath;
    } catch (e) {
      await exporter.closePipe();
      rethrow;
    }
  }

  void cancel() {
    _cancelled = true;
  }

  void dispose() {
    _progressController.close();
  }
}

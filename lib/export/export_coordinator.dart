import 'dart:async';
import 'dart:io';
import '../core/visualizer_renderer.dart';
import '../audio/audio_processor.dart';
import '../models/visualizer_settings.dart';
import '../core/constants.dart';
import '../core/visualizer_frame.dart';
import 'native_gpu_renderer.dart';
import 'offscreen_renderer.dart';
import 'ffmpeg_exporter.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

enum ExportMethod { nativeGpu, ffmpeg }

class ExportCoordinator {
  ExportCoordinator({
    required AudioProcessor processor,
    required VisualizerSettings settings,
    required String audioFilePath,
    this.method = ExportMethod.nativeGpu,
  }) : _processor = processor,
       _settings = settings,
       _audioFilePath = audioFilePath,
       _renderer = VisualizerRenderer(
         coreSettings: settings.toCoreSettings(),
         barCount: settings.barCount,
         sampleRate: processor.sampleRate,
         minFreq: settings.minFreq.toDouble(),
         maxFreq: settings.maxFreq.toDouble(),
       );

  final AudioProcessor _processor;
  final VisualizerSettings _settings;
  final String _audioFilePath;
  final VisualizerRenderer _renderer;
  final ExportMethod method;
  final _progressController = StreamController<double>.broadcast();
  bool _cancelled = false;

  Stream<double> get progress => _progressController.stream;

  double get _stftFps => _processor.sampleRate / (kFftSize * kHopRatio);

  VisualizerSettings get settings => _settings;

  Future<String> startExport() async {
    _cancelled = false;

    final frames = await _processor.getAllFrames();

    if (_settings.includeAudio) {
      return await _exportWithNativeGpuAndMuxAudio(frames);
    }

    if (method == ExportMethod.nativeGpu) {
      return await _exportWithNativeGpu(frames);
    } else {
      return await _exportWithOffscreenRenderer(frames);
    }
  }

  Future<String> _exportWithNativeGpu(List<VisualizerFrame> frames) async {
    final gpuRenderer = NativeGpuRenderer();
    final fps = _stftFps.round();
    final dt = 1.0 / _stftFps;
    final barCount = _settings.barCount;
    final totalFrames = frames.length;

    final flatHeights = Float64List(totalFrames * barCount);
    for (int i = 0; i < totalFrames; i++) {
      final heights = _renderer.computeHeights(frames[i].magnitudes, dt);
      for (int j = 0; j < barCount; j++) {
        flatHeights[i * barCount + j] = heights[j];
      }
    }

    final dir = await getTemporaryDirectory();
    final outputPath = '${dir.path}/export_${DateTime.now().millisecondsSinceEpoch}.mp4';

    final progressSub = gpuRenderer.progress.listen((p) {
      _progressController.add(p);
    });

    try {
      final resultPath = await gpuRenderer.startExport(
        outputPath: outputPath,
        width: _settings.resolution.width,
        height: _settings.resolution.height,
        fps: fps,
        backgroundColor: _settings.backgroundColor.toARGB32(),
        barCount: barCount,
        barWidth: _settings.barWidth,
        barSpacing: _settings.spacing,
        cornerRadius: _settings.cornerRadius,
        barColorArgb: _settings.positiveColor.toARGB32(),
        frameHeights: flatHeights,
      );
      _progressController.add(1.0);
      return resultPath;
    } finally {
      await progressSub.cancel();
      gpuRenderer.disposeProgress();
      await gpuRenderer.dispose();
    }
  }

  Future<String> _exportWithNativeGpuAndMuxAudio(
    List<VisualizerFrame> frames,
  ) async {
    final silentVideoPath = await _exportWithNativeGpu(frames);

    final exporter = FFmpegExporter();
    try {
      final muxedPath = silentVideoPath.replaceAll('.mp4', '_with_audio.mp4');
      final resultPath = await exporter.muxAudio(
        videoPath: silentVideoPath,
        audioPath: _audioFilePath,
        outputPath: muxedPath,
      );
      final videoFile = File(silentVideoPath);
      if (await videoFile.exists()) {
        await videoFile.delete();
      }
      _progressController.add(1.0);
      return resultPath;
    } catch (e) {
      debugPrint('Audio mux failed: $e');
      _progressController.add(1.0);
      return silentVideoPath;
    }
  }

  Future<String> _exportWithOffscreenRenderer(List<VisualizerFrame> frames) async {
    final exporter = FFmpegExporter();
    final renderer = OffscreenRenderer(
      width: _settings.resolution.width,
      height: _settings.resolution.height,
    );

    await exporter.setupRawFile();

    int frameIndex = 0;
    final totalFrames = frames.length;
    final dt = 1.0 / _stftFps;

    try {
      for (final frame in frames) {
        if (_cancelled) break;

        final heights = _renderer.computeHeights(frame.magnitudes, dt);
        final pixels = await renderer.renderFrame(heights, _settings);
        exporter.writeFrame(pixels);

        _progressController.add(frameIndex / totalFrames);
        frameIndex++;
      }

      final videoPath = await exporter.executeCommand(
        width: _settings.resolution.width,
        height: _settings.resolution.height,
        fps: _stftFps.round(),
        preset: _settings.preset.value,
        crf: _settings.crf,
      );
      _progressController.add(1.0);
      return videoPath;
    } finally {
      await exporter.cleanup();
    }
  }

  void cancel() {
    _cancelled = true;
    NativeGpuRenderer.cancelCurrentExport();
  }

  void dispose() {
    _progressController.close();
  }
}

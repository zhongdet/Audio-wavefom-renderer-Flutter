import 'dart:async';
import 'dart:io';
import '../core/visualizer_renderer.dart';
import '../audio/audio_processor.dart';
import '../models/visualizer_settings.dart';
import '../core/constants.dart';
import '../core/visualizer_frame.dart';
import 'offscreen_renderer.dart';
import 'ffmpeg_exporter.dart';
import 'hardware_exporter.dart';

enum ExportMethod { ffmpeg, hardware }

class ExportCoordinator {
  ExportCoordinator({
    required AudioProcessor processor,
    required VisualizerSettings settings,
    required String audioFilePath,
    this.method = ExportMethod.hardware,
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

    // 导出前，确保所有帧都已计算完成
    final frames = await _processor.getAllFrames();

    // 含音频时，统一使用硬件编码生成无声视频 + FFmpeg 混流
    // 避免 FFmpeg 导出产生的 RGBA 临时文件占满存储
    if (_settings.includeAudio) {
      return await _exportWithHardwareAndMuxAudio(frames);
    }

    if (method == ExportMethod.hardware) {
      return await _exportWithHardware(frames);
    } else {
      return await _exportWithFFmpeg(frames);
    }
  }

  Future<String> _exportWithHardware(List<VisualizerFrame> frames, {int? fpsOverride}) async {
    final exporter = HardwareExporter();
    final renderer = OffscreenRenderer(
      width: _settings.resolution.width,
      height: _settings.resolution.height,
    );
    final fps = fpsOverride ?? _stftFps.round();
    await exporter.setup(
      width: _settings.resolution.width,
      height: _settings.resolution.height,
      fps: fps,
    );

    int frameIndex = 0;
    final totalFrames = frames.length;
    final dt = 1.0 / _stftFps;

    try {
      for (final frame in frames) {
        if (_cancelled) break;

        final heights = _renderer.computeHeights(frame.magnitudes, dt);
        final pixels = await renderer.renderFrame(
          heights,
          _settings,
        );
        await exporter.appendVideoFrame(pixels);
        _progressController.add(frameIndex / totalFrames);
        frameIndex++;
      }

      final outputPath = await exporter.finish();
      _progressController.add(1.0);
      return outputPath;
    } catch (e) {
      rethrow;
    }
  }

  Future<String> _exportWithFFmpeg(List<VisualizerFrame> frames) async {
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
        final pixels = await renderer.renderFrame(
          heights,
          _settings,
        );
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
    } catch (e) {
      rethrow;
    } finally {
      await exporter.cleanup();
    }
  }

  Future<String> _exportWithHardwareAndMuxAudio(List<VisualizerFrame> frames) async {
    // 使用正确的 FPS 生成无声视频，匹配音频时长
    final correctFps = _stftFps.round();
    final silentVideoPath = await _exportWithHardware(frames, fpsOverride: correctFps);

    // 用 FFmpeg 混入音频
    final exporter = FFmpegExporter();
    try {
      final muxedPath = silentVideoPath.replaceAll('.mp4', '_with_audio.mp4');
      final resultPath = await exporter.muxAudio(
        videoPath: silentVideoPath,
        audioPath: _audioFilePath,
        outputPath: muxedPath,
      );
      // 删除无声视频
      final videoFile = File(silentVideoPath);
      if (await videoFile.exists()) {
        await videoFile.delete();
      }
      _progressController.add(1.0);
      return resultPath;
    } catch (e) {
      // 混流失败，返回无声视频
      print('Audio mux failed: $e');
      _progressController.add(1.0);
      return silentVideoPath;
    }
  }

  void cancel() {
    _cancelled = true;
  }

  void dispose() {
    _progressController.close();
  }
}

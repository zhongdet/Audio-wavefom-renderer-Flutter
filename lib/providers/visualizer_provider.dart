import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../audio/audio_processor.dart';
import '../models/music_items.dart';
import '../preview/preview_controller.dart';
import '../export/export_coordinator.dart';
import 'audio_provider.dart';
import 'music_list_provider.dart';
import 'visualizer_settings_provider.dart';

class VisualizerState {
  final AudioProcessor? processor;
  final PreviewController? previewController;
  final ExportCoordinator? exportCoordinator;
  final String? filePath;
  final bool isExporting;
  final double exportProgress;
  final String? exportError;
  final String? exportOutputPath;

  const VisualizerState({
    this.processor,
    this.previewController,
    this.exportCoordinator,
    this.filePath,
    this.isExporting = false,
    this.exportProgress = 0.0,
    this.exportError,
    this.exportOutputPath,
  });

  VisualizerState copyWith({
    AudioProcessor? processor,
    PreviewController? previewController,
    ExportCoordinator? exportCoordinator,
    String? filePath,
    bool? isExporting,
    double? exportProgress,
    String? exportError,
    String? exportOutputPath,
  }) {
    return VisualizerState(
      processor: processor ?? this.processor,
      previewController: previewController ?? this.previewController,
      exportCoordinator: exportCoordinator ?? this.exportCoordinator,
      filePath: filePath ?? this.filePath,
      isExporting: isExporting ?? this.isExporting,
      exportProgress: exportProgress ?? this.exportProgress,
      exportError: exportError,
      exportOutputPath: exportOutputPath,
    );
  }
}

class VisualizerNotifier extends Notifier<VisualizerState> {
  PreviewController? _previewController;
  AudioProcessor? _processor;
  ExportCoordinator? _exportCoordinator;
  StreamSubscription<double>? _exportProgressSub;
  StreamSubscription<Duration>? _positionSub;
  Timer? _previewTimer;

  // Position interpolation fields
  DateTime? _playbackStartTime;
  Duration? _playbackStartPosition;
  bool _isPlaying = false;

  void _startPreviewTimer() {
    _stopPreviewTimer();
    final intervalMs = _previewController?.timerIntervalMs ?? (1000.0 / 60.0);
    _previewTimer = Timer.periodic(
      Duration(milliseconds: intervalMs.round()),
      (_) {
        if (_isPlaying) {
          final position = _getInterpolatedPosition();
          _previewController?.tick(position);
        }
      },
    );
  }

  void _stopPreviewTimer() {
    _previewTimer?.cancel();
    _previewTimer = null;
  }

  Duration _getInterpolatedPosition() {
    if (!_isPlaying || _playbackStartTime == null || _playbackStartPosition == null) {
      return _playbackStartPosition ?? Duration.zero;
    }

    final elapsed = DateTime.now().difference(_playbackStartTime!);
    final interpolated = _playbackStartPosition! + elapsed;
    return interpolated;
  }

   @override
   VisualizerState build() {
    ref.listen(audioNotifierProvider, (prev, next) {
      final wasPlaying = prev?.value?.isPlaying ?? false;
      final isPlaying = next.value?.isPlaying ?? false;
      final position = next.value?.position ?? Duration.zero;

      if (isPlaying && !wasPlaying) {
        // Just started playing
        _playbackStartTime = DateTime.now();
        _playbackStartPosition = position;
        _isPlaying = true;
        _startPreviewTimer();
        _previewController?.tick(position);
      } else if (!isPlaying && wasPlaying) {
        // Just stopped playing
        _stopPreviewTimer();
        _previewController?.stop();
        _playbackStartTime = null;
        _playbackStartPosition = null;
        _isPlaying = false;
      } else if (isPlaying) {
        // Still playing - update base position for interpolation
        _playbackStartTime = DateTime.now();
        _playbackStartPosition = position;
      }
    });

     ref.listen(visualizerSettingsProvider, (prev, next) {
       final processor = _processor;
       if (processor == null) return;

       final wasPlaying = ref.read(audioNotifierProvider).value?.isPlaying ?? false;
       _stopPreviewTimer();

       _previewController?.dispose();
       _exportCoordinator?.dispose();

       final filePath = state.filePath;
       if (filePath == null) return;

       final previewController = PreviewController(processor, next);
       final exportCoordinator = ExportCoordinator(
         processor: processor,
         settings: next,
         audioFilePath: filePath,
       );

       _previewController = previewController;
       _exportCoordinator = exportCoordinator;

       // 如果正在播放，重新启动定时器
       if (wasPlaying) {
         _startPreviewTimer();
       }

       state = state.copyWith(
         previewController: previewController,
         exportCoordinator: exportCoordinator,
       );
     });

      ref.onDispose(() {
        _stopPreviewTimer();
        _positionSub?.cancel();
        _exportProgressSub?.cancel();
        _previewController?.dispose();
        _processor?.dispose();
        _exportCoordinator?.dispose();
        // Reset interpolation state
        _playbackStartTime = null;
        _playbackStartPosition = null;
        _isPlaying = false;
      });
      return const VisualizerState();
    }

  Future<void> pickAndLoadAudio() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'm4a', 'flac', 'ogg', 'wav'],
    );

    if (result == null || result.files.isEmpty) return;

    final path = result.files.single.path;
    if (path == null) return;

    await loadAudioFile(path);
  }

   Future<void> loadAudioFile(String path) async {
     _stopPreviewTimer(); // 停止现有定时器
     _positionSub?.cancel();
     _positionSub = null;
     _previewController?.dispose();
     _processor?.dispose();
     _exportCoordinator?.dispose();
     _exportProgressSub?.cancel();

     // Reset interpolation state
     _playbackStartTime = null;
     _playbackStartPosition = null;
     _isPlaying = false;

     final processor = AudioProcessor();
     await processor.load(path);

     final settings = ref.read(visualizerSettingsProvider);
     final previewController = PreviewController(processor, settings);
     final exportCoordinator = ExportCoordinator(
       processor: processor,
       settings: settings,
       audioFilePath: path,
     );

     _processor = processor;
     _previewController = previewController;
     _exportCoordinator = exportCoordinator;

     state = state.copyWith(
       processor: processor,
       previewController: previewController,
       exportCoordinator: exportCoordinator,
       filePath: path,
       isExporting: false,
       exportProgress: 0.0,
       exportError: null,
       exportOutputPath: null,
     );

     ref.read(audioNotifierProvider.notifier).loadFile(path);

     // 如果正在播放，启动定时器
     final isPlaying = ref.read(audioNotifierProvider).value?.isPlaying ?? false;
     if (isPlaying) {
       _startPreviewTimer();
     }

     final file = File(path);
     final fileSize = await file.length();
     ref
         .read(musicListProvider.notifier)
         .addItem(
           MusicItem(
             title: path.split('/').last,
             id: path,
             size: fileSize,
             duration: '0:00',
           ),
         );
   }

  Future<void> startExport() async {
    final coordinator = _exportCoordinator;
    if (coordinator == null || state.isExporting) return;

    state = state.copyWith(
      isExporting: true,
      exportProgress: 0.0,
      exportError: null,
    );

    _exportProgressSub = coordinator.progress.listen((progress) {
      state = state.copyWith(exportProgress: progress);
    });

    try {
      final outputPath = await coordinator.startExport();
      state = state.copyWith(
        isExporting: false,
        exportProgress: 1.0,
        exportOutputPath: outputPath,
      );
    } catch (e) {
      state = state.copyWith(isExporting: false, exportError: e.toString());
    } finally {
      await _exportProgressSub?.cancel();
      _exportProgressSub = null;
    }
  }

  void cancelExport() {
    _exportCoordinator?.cancel();
    _exportProgressSub?.cancel();
    _exportProgressSub = null;
    state = state.copyWith(isExporting: false);
  }

  void clearExportStatus() {
    state = state.copyWith(
      isExporting: false,
      exportProgress: 0.0,
      exportError: null,
      exportOutputPath: null,
    );
  }
}

final visualizerProvider =
    NotifierProvider<VisualizerNotifier, VisualizerState>(
      VisualizerNotifier.new,
    );

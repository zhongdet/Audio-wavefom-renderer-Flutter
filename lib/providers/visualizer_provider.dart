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

  @override
  VisualizerState build() {
    ref.listen(audioNotifierProvider, (prev, next) {
      final wasPlaying = prev?.value?.isPlaying ?? false;
      final isPlaying = next.value?.isPlaying ?? false;
      final position = next.value?.position ?? Duration.zero;

      if (isPlaying && !wasPlaying) {
        _positionSub =
            Stream.periodic(
              const Duration(milliseconds: 16),
              (_) =>
                  ref.read(audioNotifierProvider).value?.position ??
                  Duration.zero,
            ).listen((pos) {
              _previewController?.tick(pos);
            });
      } else if (!isPlaying && wasPlaying) {
        _positionSub?.cancel();
        _positionSub = null;
        _previewController?.stop();
      } else if (isPlaying) {
        _previewController?.tick(position);
      }
    });

    ref.onDispose(() {
      _positionSub?.cancel();
      _exportProgressSub?.cancel();
      _previewController?.dispose();
      _processor?.dispose();
      _exportCoordinator?.dispose();
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
    _positionSub?.cancel();
    _positionSub = null;
    _previewController?.dispose();
    _processor?.dispose();
    _exportCoordinator?.dispose();
    _exportProgressSub?.cancel();

    final processor = AudioProcessor();
    await processor.load(path);

    final settings = ref.read(visualizerSettingsProvider);
    final previewController = PreviewController(
      processor,
      settings.toCoreSettings(),
    );
    final exportCoordinator = ExportCoordinator(
      processor: processor,
      settings: settings.toCoreSettings(),
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

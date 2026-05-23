import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../audio/audio_processor.dart';
import '../export/export_coordinator.dart';
import '../models/visualizer_settings.dart';

enum ExportStatus { queued, rendering, completed, failed, cancelled }

class ExportQueueItem {
  final String id;
  final String audioFilePath;
  final String audioFileName;
  final VisualizerSettings settings;
  final DateTime createdAt;
  ExportStatus status;
  double progress;
  String? outputPath;
  String? errorMessage;
  String? elapsedTime;
  DateTime? _startTime;
  Timer? _timer;
  StreamSubscription<double>? _progressSub;
  AudioProcessor? _processor;
  ExportCoordinator? _coordinator;

  ExportQueueItem({
    required this.id,
    required this.audioFilePath,
    required this.audioFileName,
    required this.settings,
    DateTime? createdAt,
    this.status = ExportStatus.queued,
    this.progress = 0.0,
    this.outputPath,
    this.errorMessage,
    this.elapsedTime,
  }) : createdAt = createdAt ?? DateTime.now();

  ExportQueueItem copyWith({
    ExportStatus? status,
    double? progress,
    String? outputPath,
    String? errorMessage,
    String? elapsedTime,
  }) {
    return ExportQueueItem(
      id: id,
      audioFilePath: audioFilePath,
      audioFileName: audioFileName,
      settings: settings,
      createdAt: createdAt,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      outputPath: outputPath ?? this.outputPath,
      errorMessage: errorMessage ?? this.errorMessage,
      elapsedTime: elapsedTime ?? this.elapsedTime,
    );
  }

  void _startTimer() {
    _startTime = DateTime.now();
  }

  String? _getElapsedTime() {
    if (_startTime == null) return null;
    final elapsed = DateTime.now().difference(_startTime!);
    final minutes = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _cancelTimers() {
    _timer?.cancel();
    _timer = null;
    _progressSub?.cancel();
    _progressSub = null;
  }
}

class ExportQueueState {
  final List<ExportQueueItem> items;
  final bool isProcessing;

  const ExportQueueState({this.items = const [], this.isProcessing = false});

  ExportQueueState copyWith({
    List<ExportQueueItem>? items,
    bool? isProcessing,
  }) {
    return ExportQueueState(
      items: items ?? this.items,
      isProcessing: isProcessing ?? this.isProcessing,
    );
  }
}

class ExportQueueNotifier extends Notifier<ExportQueueState> {
  bool _processing = false;

  @override
  ExportQueueState build() {
    ref.onDispose(() {
      for (final item in state.items) {
        item._processor?.dispose();
        item._coordinator?.dispose();
      }
    });
    return const ExportQueueState();
  }

  void addToQueue(
    String audioFilePath,
    String audioFileName,
    VisualizerSettings settings,
  ) {
    final id = '${DateTime.now().millisecondsSinceEpoch}_$audioFileName';
    final item = ExportQueueItem(
      id: id,
      audioFilePath: audioFilePath,
      audioFileName: audioFileName,
      settings: settings,
    );
    state = state.copyWith(items: [...state.items, item]);
    _processNext();
  }

  void removeFromQueue(String id) {
    final item = state.items.firstWhere((i) => i.id == id);
    item._cancelTimers();
    if (item.status == ExportStatus.rendering) {
      item._coordinator?.cancel();
    }
    item._processor?.dispose();
    item._coordinator?.dispose();
    state = state.copyWith(
      items: state.items.where((i) => i.id != id).toList(),
    );
    _processNext();
  }

  void cancelItem(String id) {
    final index = state.items.indexWhere((i) => i.id == id);
    if (index < 0) return;
    final item = state.items[index];
    item._cancelTimers();
    if (item.status == ExportStatus.rendering) {
      item._coordinator?.cancel();
    }
    item._processor?.dispose();
    item._coordinator?.dispose();
    final updated = List<ExportQueueItem>.from(state.items);
    updated[index] = item.copyWith(status: ExportStatus.cancelled);
    state = state.copyWith(items: updated);
    _processNext();
  }

  void clearCompleted() {
    state = state.copyWith(
      items: state.items
          .where((i) => i.status != ExportStatus.completed)
          .toList(),
    );
  }

  Future<void> _processNext() async {
    if (_processing) return;
    _processing = true;

    while (true) {
      final nextIndex = state.items.indexWhere(
        (i) => i.status == ExportStatus.queued,
      );
      if (nextIndex < 0) break;

      await _renderItem(nextIndex);
    }

    _processing = false;
  }

  Future<void> _renderItem(int index) async {
    final item = state.items[index];

    try {
      final processor = AudioProcessor();
      item._processor = processor;
      await processor.load(item.audioFilePath);

      final coordinator = ExportCoordinator(
        processor: processor,
        settings: item.settings,
        audioFilePath: item.audioFilePath,
      );
      item._coordinator = coordinator;

      final updated = List<ExportQueueItem>.from(state.items);
      updated[index] = item.copyWith(
        status: ExportStatus.rendering,
        progress: 0.0,
      );
      state = state.copyWith(items: updated, isProcessing: true);

      item._startTimer();

      item._timer = Timer.periodic(const Duration(seconds: 1), (_) {
        final idx = state.items.indexWhere((i) => i.id == item.id);
        if (idx < 0) {
          item._timer?.cancel();
          return;
        }
        final current = state.items[idx];
        if (current.status == ExportStatus.rendering) {
          final u = List<ExportQueueItem>.from(state.items);
          u[idx] = current.copyWith(elapsedTime: item._getElapsedTime());
          state = state.copyWith(items: u);
        } else {
          item._timer?.cancel();
        }
      });

      item._progressSub = coordinator.progress.listen((progress) {
        final idx = state.items.indexWhere((i) => i.id == item.id);
        if (idx < 0) return;
        final current = state.items[idx];
        final u = List<ExportQueueItem>.from(state.items);
        u[idx] = current.copyWith(progress: progress);
        state = state.copyWith(items: u);
      });

      final outputPath = await coordinator.startExport();
      item._cancelTimers();

      final finalElapsedTime = item._getElapsedTime();
      final finalIdx = state.items.indexWhere((i) => i.id == item.id);
      if (finalIdx >= 0) {
        final u = List<ExportQueueItem>.from(state.items);
        u[finalIdx] = item.copyWith(
          status: ExportStatus.completed,
          progress: 1.0,
          outputPath: outputPath,
          elapsedTime: finalElapsedTime,
        );
        state = state.copyWith(items: u);
      }
    } catch (e) {
      item._cancelTimers();
      final finalElapsedTime = item._getElapsedTime();
      final errIdx = state.items.indexWhere((i) => i.id == item.id);
      if (errIdx >= 0) {
        final u = List<ExportQueueItem>.from(state.items);
        u[errIdx] = item.copyWith(
          status: ExportStatus.failed,
          errorMessage: e.toString(),
          elapsedTime: finalElapsedTime,
        );
        state = state.copyWith(items: u);
      }
    } finally {
      item._cancelTimers();
      item._processor?.dispose();
      item._coordinator?.dispose();
      item._processor = null;
      item._coordinator = null;

      final cleanIdx = state.items.indexWhere((i) => i.id == item.id);
      if (cleanIdx >= 0) {
        final u = List<ExportQueueItem>.from(state.items);
        final current = state.items[cleanIdx];
        if (current.status != ExportStatus.completed &&
            current.status != ExportStatus.failed &&
            current.status != ExportStatus.cancelled) {
          u[cleanIdx] = item.copyWith(status: ExportStatus.failed);
          state = state.copyWith(items: u);
        }
      }
    }
  }
}

final exportQueueProvider =
    NotifierProvider<ExportQueueNotifier, ExportQueueState>(
      ExportQueueNotifier.new,
    );

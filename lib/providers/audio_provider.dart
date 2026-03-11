import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../models/music_items.dart';

final audioNotifierProvider = AsyncNotifierProvider<AudioNotifier, AudioState>(
  () {
    return AudioNotifier();
  },
);

class AudioState {
  final MusicItem? currentItem;
  final bool isPlaying;
  final bool isLoading;
  final Duration position;
  final Duration duration;

  AudioState({
    this.currentItem,
    this.isPlaying = false,
    this.isLoading = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
  });

  AudioState copyWith({
    MusicItem? currentItem,
    bool? isPlaying,
    bool? isLoading,
    Duration? position,
    Duration? duration,
  }) {
    return AudioState(
      currentItem: currentItem ?? this.currentItem,
      isPlaying: isPlaying ?? this.isPlaying,
      isLoading: isLoading ?? this.isLoading,
      position: position ?? this.position,
      duration: duration ?? this.duration,
    );
  }
}

class AudioNotifier extends AsyncNotifier<AudioState> {
  late AudioPlayer _player;
  StreamSubscription? _posSub;
  StreamSubscription? _durSub;
  StreamSubscription? _stateSub;

  @override
  FutureOr<AudioState> build() {
    _player = AudioPlayer();

    _posSub = _player.positionStream.listen((p) {
      state = AsyncData(state.value!.copyWith(position: p));
    });

    _durSub = _player.durationStream.listen((d) {
      state = AsyncData(state.value!.copyWith(duration: d ?? Duration.zero));
    });

    _stateSub = _player.playerStateStream.listen((s) {
      state = AsyncData(state.value!.copyWith(isPlaying: s.playing));
    });

    ref.onDispose(() {
      _posSub?.cancel();
      _durSub?.cancel();
      _stateSub?.cancel();
      _player.dispose();
    });

    return AudioState();
  }

  Future<void> selectMusic(MusicItem item) async {
    final currentState = state.value!;
    state = AsyncData(
      currentState.copyWith(isLoading: true, currentItem: item),
    );

    try {
      await _player.stop();
      if (item.id.startsWith('assets/')) {
        await _player.setAsset(item.id, preload: false);
      } else {
        await _player.setFilePath(item.id, preload: false);
      }
    } catch (e) {
      debugPrint('Audio Load Error: $e');
    } finally {
      state = AsyncData(state.value!.copyWith(isLoading: false));
    }
  }

  Future<void> playPause() async {
    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }
}

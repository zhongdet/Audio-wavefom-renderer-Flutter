import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../models/music_items.dart';

class AudioProvider extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();
  MusicItem? _currentItem;
  Duration? _duration;
  Duration? _currentTime;

  MusicItem? get currentItem => _currentItem;
  Duration? get duration => _duration;
  Duration? get currentTime => _currentTime;
  bool get isPlaying => _player.playing;
  Stream<Duration?> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;

  AudioProvider() {
    _player.positionStream.listen((position) {
      _currentTime = position;
      notifyListeners();
    });
    _player.durationStream.listen((duration) {
      _duration = duration;
      notifyListeners();
    });
    _player.playerStateStream.listen((state) {
      notifyListeners();
    });
  }

  Future<void> selectMusic(MusicItem item) async {
    _currentItem = item;
    await _player.setFilePath(item.id); // assume id is file URL
    _duration = _player.duration; // await
    notifyListeners();
  }

  // play/pause
  Future<void> playPause() async {
    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
    notifyListeners();
  }

  // seek current position (for progress bar)
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  // release resource
  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../models/music_items.dart';

class AudioProvider extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();
  MusicItem? _currentItem;
  Duration? _duration;
  Duration? _currentTime;
  bool _isLoading = false;

  MusicItem? get currentItem => _currentItem;
  Duration? get duration => _duration;
  Duration? get currentTime => _currentTime;
  bool get isPlaying => _player.playing;
  bool get isLoading => _isLoading;
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
    print(item.id);
    _isLoading = true;
    notifyListeners();

    try {
      _currentItem = item;
      await _player.stop();

      if (item.id.startsWith('assets/')) {
        await _player.setAsset(item.id);
      } else {
        await _player.setFilePath(item.id);
      }

      await _player.play();
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> playPause() async {
    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
    notifyListeners();
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}

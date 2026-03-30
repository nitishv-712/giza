// lib/providers/audio_provider.dart

import 'package:flutter/foundation.dart';
import '../models/song.dart';
import '../services/audio_service.dart';

class AudioProvider extends ChangeNotifier {
  final _audioService = AudioService.instance;

  Song? get currentSong => _audioService.currentSong;
  bool get isPlaying => _audioService.isPlaying;
  Duration get position => _audioService.position;
  Duration? get duration => _audioService.duration;
  bool get isShuffle => _audioService.isShuffle;
  bool get isRepeat => _audioService.isRepeat;

  GizaPlayerStatus _status = GizaPlayerStatus.idle;
  GizaPlayerStatus get status => _status;

  double? _downloadProgress;
  double? get downloadProgress => _downloadProgress;

  AudioProvider() {
    _audioService.playerStateStream.listen((state) {
      _status = state.status;
      _downloadProgress = state.downloadProgress;
      notifyListeners();
    });

    _audioService.positionStream.listen((_) => notifyListeners());
    _audioService.durationStream.listen((_) => notifyListeners());
  }

  Future<void> play(Song song, {List<Song>? playlist}) async {
    await _audioService.play(song, playlist: playlist);
    notifyListeners();
  }

  Future<void> togglePlayPause() async {
    await _audioService.togglePlayPause();
    notifyListeners();
  }

  Future<void> next() async {
    await _audioService.next();
    notifyListeners();
  }

  Future<void> previous() async {
    await _audioService.previous();
    notifyListeners();
  }

  Future<void> seek(Duration position) async {
    await _audioService.seek(position);
    notifyListeners();
  }

  void toggleShuffle() {
    _audioService.toggleShuffle();
    notifyListeners();
  }

  void toggleRepeat() {
    _audioService.toggleRepeat();
    notifyListeners();
  }
}

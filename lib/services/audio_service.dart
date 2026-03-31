// lib/services/audio_service.dart

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import '../models/song.dart';
import '../db/hive_helper.dart';
import '../services/youtube_service.dart';
import '../services/notification_service.dart';

// ── Playback state ────────────────────────────────────────────────────────────

enum GizaPlayerStatus { idle, downloading, loading, playing, paused, ended, error }

class GizaPlayerState {
  final GizaPlayerStatus status;
  final bool playing;
  final double? downloadProgress;
  final bool isShuffle;
  final bool isRepeat;

  const GizaPlayerState({
    required this.status,
    required this.playing,
    this.downloadProgress,
    this.isShuffle = false,
    this.isRepeat = false,
  });
}

// ── AudioService ──────────────────────────────────────────────────────────────

class AudioService {
  AudioService._();
  static final AudioService instance = AudioService._();

  final _player    = AudioPlayer();
  final _db        = HiveHelper.instance;
  final _ytService = YoutubeService.instance;
  final _notificationService = NotificationService.instance;

  Song?   _currentSong;
  Song?   get currentSong => _currentSong;

  String? _currentVideoId;
  String? get currentVideoId => _currentVideoId;

  bool _isStreaming = false;
  bool get isStreaming => _isStreaming;

  // Queue Management
  List<Song> _playlist = [];
  int _currentIndex = -1;
  bool _isShuffle = false;
  bool _isRepeat = false;

  bool get isShuffle => _isShuffle;
  bool get isRepeat => _isRepeat;

  // ── Streams ────────────────────────────────────────────────────────────────

  final _stateCtrl    = StreamController<GizaPlayerState>.broadcast();
  final _positionCtrl = StreamController<Duration>.broadcast();
  final _durationCtrl = StreamController<Duration?>.broadcast();

  Stream<GizaPlayerState> get playerStateStream => _stateCtrl.stream;
  Stream<Duration>         get positionStream    => _positionCtrl.stream;
  Stream<Duration?>        get durationStream    => _durationCtrl.stream;
  Stream<bool>             get playingStream     => playerStateStream.map((s) => s.playing);

  bool      _playing  = false;
  Duration  _position = Duration.zero;
  Duration? _duration;

  bool      get isPlaying => _playing;
  Duration  get position  => _position;
  Duration? get duration  => _duration;

  // ── Initialization ─────────────────────────────────────────────────────────

  void init() {
    _setupNotificationHandlers();
    
    _player.onPlayerStateChanged.listen((state) {
      _playing = state == PlayerState.playing;
      switch (state) {
        case PlayerState.playing:   _emit(GizaPlayerStatus.playing); break;
        case PlayerState.paused:    _emit(GizaPlayerStatus.paused);  break;
        case PlayerState.stopped:   _emit(GizaPlayerStatus.idle);    break;
        case PlayerState.completed: 
          _emit(GizaPlayerStatus.ended);
          if (_isRepeat) {
            resume();
          } else {
            next();
          }
          break;
        case PlayerState.disposed:  break;
      }
    });

    _player.onPositionChanged.listen((pos) {
      _position = pos;
      _positionCtrl.add(pos);
      _updateNotification();
    });

    _player.onDurationChanged.listen((dur) {
      _duration = dur;
      _durationCtrl.add(dur);
      _updateNotification();
    });
  }

  void _setupNotificationHandlers() {
    _notificationService.setHandlers(
      onPlay: () => resume(),
      onPause: () => pause(),
      onNext: () => next(),
      onPrevious: () => previous(),
      onSeek: (position) => seek(position),
    );
  }

  void _updateNotification() {
    if (_currentSong != null && _duration != null) {
      _notificationService.updateNotification(
        song: _currentSong!,
        isPlaying: _playing,
        position: _position,
        duration: _duration!,
      );
    }
  }

  // ── Playlist Management ────────────────────────────────────────────────────

  void setPlaylist(List<Song> songs, {int initialIndex = 0}) {
    _playlist = List.from(songs);
    _currentIndex = initialIndex;
  }

  // ── Playback Controls ──────────────────────────────────────────────────────

  Future<void> play(Song song, {List<Song>? playlist}) async {
    if (playlist != null) {
      _playlist = List.from(playlist);
      _currentIndex = _playlist.indexWhere((s) => s.youtubeVideoId == song.youtubeVideoId);
    } else if (!_playlist.any((s) => s.youtubeVideoId == song.youtubeVideoId)) {
      _playlist = [song];
      _currentIndex = 0;
    } else {
      _currentIndex = _playlist.indexWhere((s) => s.youtubeVideoId == song.youtubeVideoId);
    }

    _currentSong    = song;
    _currentVideoId = song.youtubeVideoId;
    _isStreaming    = false;

    try {
      final localPath = _getCachedPath(song);

      if (localPath != null && File(localPath).existsSync()) {
        _emit(GizaPlayerStatus.loading);
        await _player.play(DeviceFileSource(localPath));
      } else {
        await _downloadAndPlay(song);
      }

      _logPlay(song);
    } catch (e) {
      debugPrint('Playback error for "${song.title}": $e');
      _emit(GizaPlayerStatus.error);
      
      // If this was auto-play from queue, don't rethrow
      // Let the caller handle it (next/previous will retry)
      throw Exception('Failed to play: ${song.title}');
    }
  }

  Future<void> next() async {
    if (_playlist.isEmpty) return;

    final startIndex = _currentIndex;
    int attempts = 0;
    final maxAttempts = _playlist.length;

    while (attempts < maxAttempts) {
      if (_isShuffle) {
        _currentIndex = Random().nextInt(_playlist.length);
      } else {
        _currentIndex = (_currentIndex + 1) % _playlist.length;
      }

      // Prevent infinite loop on same song
      if (attempts > 0 && _currentIndex == startIndex) break;

      try {
        await play(_playlist[_currentIndex]);
        return; // Success, exit
      } catch (e) {
        debugPrint('Failed to play ${_playlist[_currentIndex].title}: $e');
        attempts++;
        // Continue to next song
      }
    }

    // All songs failed, stop playback
    debugPrint('All songs in playlist failed to play');
    _emit(GizaPlayerStatus.error);
  }

  Future<void> previous() async {
    if (_playlist.isEmpty) return;

    if (_position.inSeconds > 3) {
      await seek(Duration.zero);
      return;
    }

    final startIndex = _currentIndex;
    int attempts = 0;
    final maxAttempts = _playlist.length;

    while (attempts < maxAttempts) {
      _currentIndex = (_currentIndex - 1) % _playlist.length;
      if (_currentIndex < 0) _currentIndex = _playlist.length - 1;

      // Prevent infinite loop
      if (attempts > 0 && _currentIndex == startIndex) break;

      try {
        await play(_playlist[_currentIndex]);
        return; // Success, exit
      } catch (e) {
        debugPrint('Failed to play ${_playlist[_currentIndex].title}: $e');
        attempts++;
        // Continue to previous song
      }
    }

    // All songs failed
    debugPrint('All songs in playlist failed to play');
    _emit(GizaPlayerStatus.error);
  }

  void toggleShuffle() {
    _isShuffle = !_isShuffle;
    _emit(_playing ? GizaPlayerStatus.playing : GizaPlayerStatus.paused);
  }

  void toggleRepeat() {
    _isRepeat = !_isRepeat;
    _emit(_playing ? GizaPlayerStatus.playing : GizaPlayerStatus.paused);
  }

  Future<void> stream(Song song) => play(song);

  // ── Background download ────────────────────────────────────────────────────

  Future<void> downloadOnly(
    Song song, {
    void Function(double)? onProgress,
    void Function(Song saved)? onDone,
    void Function(Object error)? onError,
  }) async {
    if (song.youtubeVideoId == null) {
      onError?.call(Exception('No video ID'));
      return;
    }

    try {
      final appDir   = await getApplicationDocumentsDirectory();
      final musicDir = Directory('${appDir.path}/music');
      if (!musicDir.existsSync()) await musicDir.create(recursive: true);

      // Get quality preference from settings
      final quality = _db.getSetting<String>('audio_quality') ?? 'best';

      final savePath = await _ytService.downloadAudio(
        song.youtubeVideoId!,
        musicDir.path,
        onProgress: onProgress,
        quality: quality,
      );

      if (!File(savePath).existsSync() || File(savePath).lengthSync() == 0) {
        throw Exception('Downloaded file is empty or missing: $savePath');
      }

      final updatedSong = song.copyWith(isDownloaded: true, localPath: savePath);
      await _db.saveSong(updatedSong);

      if (_currentVideoId == song.youtubeVideoId) {
        _currentSong = updatedSong;
      }

      onDone?.call(updatedSong);
    } catch (e) {
      debugPrint('Download error: $e');
      onError?.call(e);
    }
  }

  // ── Download & Play ────────────────────────────────────────────────────────

  Future<void> _downloadAndPlay(Song song) async {
    if (song.youtubeVideoId == null) {
      throw Exception('No video ID for song: ${song.title}');
    }

    _emit(GizaPlayerStatus.downloading, downloadProgress: 0.0);

    try {
      final appDir   = await getApplicationDocumentsDirectory();
      final musicDir = Directory('${appDir.path}/music');
      if (!musicDir.existsSync()) await musicDir.create(recursive: true);

      // Get quality preference from settings
      final quality = _db.getSetting<String>('audio_quality') ?? 'best';

      final savePath = await _ytService.downloadAudio(
        song.youtubeVideoId!,
        musicDir.path,
        onProgress: (p) => _emit(GizaPlayerStatus.downloading, downloadProgress: p),
        quality: quality,
      );

      if (!File(savePath).existsSync() || File(savePath).lengthSync() == 0) {
        throw Exception('Downloaded file is empty or missing');
      }

      final updatedSong = song.copyWith(isDownloaded: true, localPath: savePath);
      await _db.saveSong(updatedSong);
      _currentSong = updatedSong;

      _emit(GizaPlayerStatus.loading);
      await _player.play(DeviceFileSource(savePath));
    } catch (e) {
      throw Exception('Download failed for "${song.title}": $e');
    }
  }

  // ── Controls ───────────────────────────────────────────────────────────────

  Future<void> resume()                async {
    await _player.resume();
    _updateNotification();
  }
  
  Future<void> pause()                 async {
    await _player.pause();
    _updateNotification();
  }
  
  Future<void> stop()                  async {
    await _player.stop();
    await _notificationService.clearNotification();
  }
  Future<void> seek(Duration position) async => _player.seek(position);

  Future<void> togglePlayPause() async {
    if (_playing) {await pause();} else {await resume();}
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String? _getCachedPath(Song song) {
    String? check(String? path) {
      if (path == null) return null;
      return File(path).existsSync() ? path : null;
    }

    if (song.isDownloaded) {
      final p = check(song.localPath);
      if (p != null) return p;
    }

    if (song.youtubeVideoId != null) {
      final saved = _db.getSongByVideoId(song.youtubeVideoId!);
      if (saved != null && saved.isDownloaded) return check(saved.localPath);
    }

    return null;
  }

  void _logPlay(Song song) {
    if (song.youtubeVideoId == null) return;
    final saved = _db.getSongByVideoId(song.youtubeVideoId!);
    if (saved != null) _db.logPlay(saved).catchError((_) {});
  }

  void _emit(GizaPlayerStatus status, {double? downloadProgress}) {
    _stateCtrl.add(GizaPlayerState(
      status:           status,
      playing:          status == GizaPlayerStatus.playing,
      downloadProgress: downloadProgress,
      isShuffle:        _isShuffle,
      isRepeat:         _isRepeat,
    ));
  }

  Future<void> dispose() async {
    await _player.dispose();
    await _stateCtrl.close();
    await _positionCtrl.close();
    await _durationCtrl.close();
  }
}

// lib/services/audio_service.dart

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import '../models/song.dart';
import '../db/hive_helper.dart';
import '../services/youtube_service.dart';

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
    });

    _player.onDurationChanged.listen((dur) {
      _duration = dur;
      _durationCtrl.add(dur);
    });
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
      print('Playback error: $e');
      _emit(GizaPlayerStatus.error);
      rethrow;
    }
  }

  Future<void> next() async {
    if (_playlist.isEmpty) return;

    if (_isShuffle) {
      _currentIndex = Random().nextInt(_playlist.length);
    } else {
      _currentIndex = (_currentIndex + 1) % _playlist.length;
    }

    await play(_playlist[_currentIndex]);
  }

  Future<void> previous() async {
    if (_playlist.isEmpty) return;

    if (_position.inSeconds > 3) {
      await seek(Duration.zero);
      return;
    }

    _currentIndex = (_currentIndex - 1) % _playlist.length;
    if (_currentIndex < 0) _currentIndex = _playlist.length - 1;

    await play(_playlist[_currentIndex]);
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

      final savePath = await _ytService.downloadAudio(
        song.youtubeVideoId!,
        musicDir.path,
        onProgress: onProgress,
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
      print('Download error: $e');
      onError?.call(e);
    }
  }

  // ── Download & Play ────────────────────────────────────────────────────────

  Future<void> _downloadAndPlay(Song song) async {
    if (song.youtubeVideoId == null) throw Exception('No video ID for song');

    _emit(GizaPlayerStatus.downloading, downloadProgress: 0.0);

    final appDir   = await getApplicationDocumentsDirectory();
    final musicDir = Directory('${appDir.path}/music');
    if (!musicDir.existsSync()) await musicDir.create(recursive: true);

    final savePath = await _ytService.downloadAudio(
      song.youtubeVideoId!,
      musicDir.path,
      onProgress: (p) => _emit(GizaPlayerStatus.downloading, downloadProgress: p),
    );

    if (!File(savePath).existsSync() || File(savePath).lengthSync() == 0) {
      throw Exception('Downloaded file is empty or missing: $savePath');
    }

    final updatedSong = song.copyWith(isDownloaded: true, localPath: savePath);
    await _db.saveSong(updatedSong);
    _currentSong = updatedSong;

    _emit(GizaPlayerStatus.loading);
    await _player.play(DeviceFileSource(savePath));
  }

  // ── Controls ───────────────────────────────────────────────────────────────

  Future<void> resume()                async => _player.resume();
  Future<void> pause()                 async => _player.pause();
  Future<void> stop()                  async => _player.stop();
  Future<void> seek(Duration position) async => _player.seek(position);

  Future<void> togglePlayPause() async {
    if (_playing) await pause(); else await resume();
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

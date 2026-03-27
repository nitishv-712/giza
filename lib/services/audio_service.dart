// lib/services/audio_service.dart
//
// Downloads audio from YouTube using youtube_explode_dart, caches it locally,
// then plays via just_audio (or audioplayers). Shows download progress.

import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:just_audio/just_audio.dart';

import '../models/song.dart';
import '../db/hive_helper.dart';
import '../services/youtube_service.dart';

// ── Playback state ────────────────────────────────────────────────────────────

enum GizaPlayerStatus { idle, downloading, loading, playing, paused, ended, error }

class GizaPlayerState {
  final GizaPlayerStatus status;
  final bool playing;
  final double? downloadProgress; // 0.0 to 1.0 during download
  
  const GizaPlayerState({
    required this.status,
    required this.playing,
    this.downloadProgress,
  });
}

// ── AudioService ──────────────────────────────────────────────────────────────

class AudioService {
  AudioService._();
  static final AudioService instance = AudioService._();

  final _player = AudioPlayer();
  final _db = HiveHelper.instance;
  final _ytService = YoutubeService.instance;

  Song?   _currentSong;
  Song?   get currentSong => _currentSong;

  String? _currentVideoId;
  String? get currentVideoId => _currentVideoId;

  // ── Streams ────────────────────────────────────────────────────────────────

  final _stateCtrl    = StreamController<GizaPlayerState>.broadcast();
  final _positionCtrl = StreamController<Duration>.broadcast();
  final _durationCtrl = StreamController<Duration?>.broadcast();

  Stream<GizaPlayerState> get playerStateStream => _stateCtrl.stream;
  Stream<Duration>         get positionStream    => _positionStream;
  Stream<Duration?>        get durationStream    => _durationStream;
  Stream<bool>             get playingStream     => playerStateStream.map((s) => s.playing);

  bool      _playing  = false;
  Duration  _position = Duration.zero;
  Duration? _duration;

  bool      get isPlaying => _playing;
  Duration  get position  => _position;
  Duration? get duration  => _duration;

  // Listen to player streams
  Stream<Duration> get _positionStream => _player.positionStream;
  Stream<Duration?> get _durationStream => _player.durationStream;

  // ── Initialization ─────────────────────────────────────────────────────────

  void init() {
    // Listen to player state changes
    _player.playerStateStream.listen((state) {
      _playing = state.playing;
      
      switch (state.processingState) {
        case ProcessingState.idle:
          _emit(GizaPlayerStatus.idle);
          break;
        case ProcessingState.loading:
        case ProcessingState.buffering:
          _emit(GizaPlayerStatus.loading);
          break;
        case ProcessingState.ready:
          _emit(_playing ? GizaPlayerStatus.playing : GizaPlayerStatus.paused);
          break;
        case ProcessingState.completed:
          _emit(GizaPlayerStatus.ended);
          break;
      }
    });

    // Listen to position and duration
    _player.positionStream.listen((pos) {
      _position = pos;
      _positionCtrl.add(pos);
    });

    _player.durationStream.listen((dur) {
      _duration = dur;
      _durationCtrl.add(dur);
    });
  }

  // ── Play ───────────────────────────────────────────────────────────────────

  /// Downloads the song if not cached, then plays it
  Future<void> play(Song song) async {
    _currentSong = song;
    _currentVideoId = song.youtubeVideoId;
    
    try {
      // Check if already downloaded
      String? localPath = await _getLocalPath(song);
      
      if (localPath != null && File(localPath).existsSync()) {
        // Already downloaded, play directly
        print('Playing from cache: $localPath');
        await _playFromFile(localPath);
        
        // Log play in database
        if (song.youtubeVideoId != null) {
          final saved = _db.getSongByVideoId(song.youtubeVideoId!);
          if (saved != null) {
            _db.logPlay(saved).catchError((_) {});
          }
        }
      } else {
        // Need to download first
        await _downloadAndPlay(song);
      }
    } catch (e) {
      print('Playback error: $e');
      _emit(GizaPlayerStatus.error);
      rethrow;
    }
  }

  // ── Download & Play ────────────────────────────────────────────────────────

  Future<void> _downloadAndPlay(Song song) async {
    if (song.youtubeVideoId == null) {
      throw Exception('No video ID for song');
    }

    _emit(GizaPlayerStatus.downloading, downloadProgress: 0.0);

    try {
      // Get audio stream URL
      final audioUrl = await _ytService.getBestAudioStreamLikeYtDlp(song.youtubeVideoId!);
      if (audioUrl == null) {
        throw Exception('Could not get audio stream URL');
      }

      // Prepare local file path
      final appDir = await getApplicationDocumentsDirectory();
      final musicDir = Directory('${appDir.path}/music');
      if (!musicDir.existsSync()) {
        await musicDir.create(recursive: true);
      }

      final fileName = '${song.youtubeVideoId}.webm'; // or .m4a depending on format
      final savePath = '${musicDir.path}/$fileName';

      // Download with progress
      print('Downloading: $audioUrl -> $savePath');
      await _downloadWithProgress(audioUrl, savePath, (progress) {
        _emit(GizaPlayerStatus.downloading, downloadProgress: progress);
      });

      print('Download complete: $savePath');

      // Update song in database with local path
      final updatedSong = song.copyWith(
        isDownloaded: true,
        localPath: savePath,
      );
      await _db.saveSong(updatedSong);
      _currentSong = updatedSong;

      // Log play
      if (song.youtubeVideoId != null) {
        final saved = _db.getSongByVideoId(song.youtubeVideoId!);
        if (saved != null) {
          _db.logPlay(saved).catchError((_) {});
        }
      }

      // Play the downloaded file
      await _playFromFile(savePath);
    } catch (e) {
      print('Download/Play error: $e');
      _emit(GizaPlayerStatus.error);
      rethrow;
    }
  }

  Future<void> _downloadWithProgress(
    String url,
    String savePath,
    Function(double) onProgress,
  ) async {
    await _ytService.downloadInFragments(url, savePath, onProgress: onProgress);
  }

  // ── Play from file ─────────────────────────────────────────────────────────

  Future<void> _playFromFile(String filePath) async {
    _emit(GizaPlayerStatus.loading);
    
    await _player.setFilePath(filePath);
    await _player.play();
    
    _playing = true;
    _emit(GizaPlayerStatus.playing);
  }

  // ── Controls ───────────────────────────────────────────────────────────────

  Future<void> resume() async {
    await _player.play();
    _playing = true;
    _emit(GizaPlayerStatus.playing);
  }

  Future<void> pause() async {
    await _player.pause();
    _playing = false;
    _emit(GizaPlayerStatus.paused);
  }

  Future<void> stop() async {
    await _player.stop();
    _playing = false;
    _emit(GizaPlayerStatus.idle);
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
    _position = position;
    _positionCtrl.add(position);
  }

  Future<void> togglePlayPause() async {
    if (_playing) {
      await pause();
    } else {
      await resume();
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Future<String?> _getLocalPath(Song song) async {
    // First check if song has localPath set
    if (song.isDownloaded && song.localPath != null) {
      return song.localPath;
    }

    // Check in database
    if (song.youtubeVideoId != null) {
      final saved = _db.getSongByVideoId(song.youtubeVideoId!);
      if (saved != null && saved.isDownloaded && saved.localPath != null) {
        return saved.localPath;
      }
    }

    return null;
  }

  void _emit(GizaPlayerStatus status, {double? downloadProgress}) {
    _stateCtrl.add(GizaPlayerState(
      status:  status,
      playing: status == GizaPlayerStatus.playing,
      downloadProgress: downloadProgress,
    ));
  }

  Future<void> dispose() async {
    await _player.dispose();
    await _stateCtrl.close();
    await _positionCtrl.close();
    await _durationCtrl.close();
  }
}
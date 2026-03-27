// lib/services/audio_service.dart
//
// Plays audio via YouTube IFrame (youtube_player_flutter).
// Uses youtube_explode_dart to search YouTube for a video ID
// matching the song title + artist — no API key required.
//
// The YoutubePlayerController is mounted in the widget tree (1×1 px, hidden)
// via HomeScreen and PlayScreen. This service manages its lifecycle and
// exposes reactive streams for the UI.

import 'dart:async';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../models/song.dart';
import '../db/hive_helper.dart';

// ── Playback state ────────────────────────────────────────────────────────────

enum GizaPlayerStatus { idle, loading, playing, paused, ended, error }

class GizaPlayerState {
  final GizaPlayerStatus status;
  final bool playing;
  const GizaPlayerState({required this.status, required this.playing});
}

// ── AudioService ──────────────────────────────────────────────────────────────

class AudioService {
  AudioService._();
  static final AudioService instance = AudioService._();

  final _yt = YoutubeExplode();
  final _db = HiveHelper.instance;

  YoutubePlayerController? _controller;

  /// Expose controller so widgets can mount the hidden YoutubePlayer widget.
  YoutubePlayerController? get controller => _controller;

  Song?   _currentSong;
  Song?   get currentSong => _currentSong;

  String? _currentVideoId;
  String? get currentVideoId => _currentVideoId;

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

  // ── Play ───────────────────────────────────────────────────────────────────

  /// Resolves a YouTube video ID for [song], then creates/updates the controller.
  Future<void> play(Song song) async {
    _currentSong = song;
    _emit(GizaPlayerStatus.loading);

    // Log play in Hive if the song is saved
    if (song.audiusTrackId != null) {
      final saved = _db.getSongByAudiusId(song.audiusTrackId!);
      if (saved != null) _db.logPlay(saved).catchError((_) {});
    }

    try {
      final videoId = await _resolveVideoId(song);
      _currentVideoId = videoId;
      _launchController(videoId);
    } catch (e) {
      _emit(GizaPlayerStatus.error);
      rethrow;
    }
  }

  // ── Controls ───────────────────────────────────────────────────────────────

  void resume() {
    _controller?.play();
    _playing = true;
    _emit(GizaPlayerStatus.playing);
  }

  void pause() {
    _controller?.pause();
    _playing = false;
    _emit(GizaPlayerStatus.paused);
  }

  void stop() {
    _controller?.pause();
    _playing = false;
    _emit(GizaPlayerStatus.idle);
  }

  void seek(Duration position) {
    _controller?.seekTo(position);
    _position = position;
    _positionCtrl.add(position);
  }

  void togglePlayPause() => _playing ? pause() : resume();

  // ── Internal ───────────────────────────────────────────────────────────────

  /// Search YouTube for "[title] [artist] audio" and return the best video ID.
  Future<String> _resolveVideoId(Song song) async {
    final query   = '${song.title} ${song.artist} audio';
    final results = await _yt.search.search(query);
    if (results.isEmpty) {
      throw Exception('No YouTube results for "${song.title}"');
    }
    // Prefer a result whose title contains the song name
    final preferred = results.firstWhere(
      (v) => v.title.toLowerCase().contains(song.title.toLowerCase()),
      orElse: () => results.first,
    );
    return preferred.id.value;
  }

  void _launchController(String videoId) {
    // Tear down previous controller
    _controller?.removeListener(_onUpdate);
    _controller?.dispose();

    _controller = YoutubePlayerController(
      initialVideoId: videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        disableDragSeek: false,
        loop: false,
        isLive: false,
        forceHD: false,
        enableCaption: false,
        hideControls: true,      // hide YouTube chrome — we use our own UI
        hideThumbnail: true,
        useHybridComposition: true,
      ),
    )..addListener(_onUpdate);

    _emit(GizaPlayerStatus.loading);
  }

  void _onUpdate() {
    final ctrl = _controller;
    if (ctrl == null) return;

    final value     = ctrl.value;
    final nowPlaying = value.isPlaying;

    // Duration
    final dur = value.metaData.duration;
    if (dur != Duration.zero && dur != _duration) {
      _duration = dur;
      _durationCtrl.add(dur);
    }

    // Position
    _position = value.position;
    _positionCtrl.add(_position);

    // State transitions
    if (value.playerState == PlayerState.ended) {
      if (_playing) {
        _playing = false;
        _emit(GizaPlayerStatus.ended);
      }
    } else if (nowPlaying != _playing) {
      _playing = nowPlaying;
      _emit(nowPlaying ? GizaPlayerStatus.playing : GizaPlayerStatus.paused);
    }
  }

  void _emit(GizaPlayerStatus status) {
    _stateCtrl.add(GizaPlayerState(
      status:  status,
      playing: status == GizaPlayerStatus.playing,
    ));
  }

  void dispose() {
    _controller?.removeListener(_onUpdate);
    _controller?.dispose();
    _stateCtrl.close();
    _positionCtrl.close();
    _durationCtrl.close();
    _yt.close();
  }
}

// lib/screens/play_screen.dart

import 'package:flutter/material.dart';
import '../models/song.dart';
import '../services/audio_service.dart';
import '../db/hive_helper.dart';

class PlayScreen extends StatefulWidget {
  const PlayScreen({super.key});

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen> with SingleTickerProviderStateMixin {
  final _audioService = AudioService.instance;
  final _db           = HiveHelper.instance;

  late AnimationController _rotationController;

  bool _isFavourite   = false;
  bool _isDownloading = false;
  bool _isDownloaded  = false;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _loadSongStatus();
  }

  void _loadSongStatus() {
    final song = _audioService.currentSong;
    if (song?.youtubeVideoId != null) {
      final saved = _db.getSongByVideoId(song!.youtubeVideoId!);
      setState(() {
        _isFavourite  = saved?.isFavourite  ?? false;
        _isDownloaded = saved?.isDownloaded ?? song.isDownloaded;
      });
    }
  }

  // ── Favourite ──────────────────────────────────────────────────────────────

  Future<void> _toggleFavourite() async {
    final song = _audioService.currentSong;
    if (song == null) return;

    final newValue = !_isFavourite;
    await _db.saveSong(song.copyWith(isFavourite: newValue));
    await _db.toggleFavourite(song, newValue);
    setState(() => _isFavourite = newValue);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newValue ? 'Added to favourites' : 'Removed from favourites'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  // ── Download current streaming song ───────────────────────────────────────

  Future<void> _downloadCurrentSong() async {
    final song = _audioService.currentSong;
    if (song == null || _isDownloading || _isDownloaded) return;

    setState(() => _isDownloading = true);

    _audioService.downloadOnly(
      song,
      onDone: (saved) {
        if (mounted) {
          setState(() {
            _isDownloading = false;
            _isDownloaded  = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('"${saved.title}" saved for offline'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
      onError: (e) {
        if (mounted) {
          setState(() => _isDownloading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Download failed: $e')),
          );
        }
      },
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final song = _audioService.currentSong;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF080810),
              const Color(0xFF080810).withOpacity(0.95),
              const Color(0xFF18182A).withOpacity(0.8),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height - 
                           MediaQuery.of(context).padding.top - 
                           MediaQuery.of(context).padding.bottom,
              ),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    _buildHeader(),
                    const Spacer(),
                    _buildArtwork(song),
                    const Spacer(),
                    _buildSongInfo(song),
                    const SizedBox(height: 24),
                    _buildProgressBar(),
                    const SizedBox(height: 32),
                    _buildControls(),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final streaming = _audioService.isStreaming && !_isDownloaded;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down, size: 32),
            color: const Color(0xFFECECFF),
            onPressed: () => Navigator.pop(context),
          ),

          // Title + streaming badge
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Now Playing',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFECECFF)),
              ),
              if (streaming)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.wifi, size: 11,
                        color: const Color(0xFF00E5FF).withOpacity(0.8)),
                    const SizedBox(width: 3),
                    Text('Streaming',
                        style: TextStyle(
                            fontSize: 11,
                            color: const Color(0xFF00E5FF).withOpacity(0.8))),
                  ],
                ),
            ],
          ),

          // Right actions: download (if streaming) + favourite
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (streaming)
                _isDownloading
                    ? const SizedBox(
                        width: 24, height: 24,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Color(0xFF00E5FF)),
                      )
                    : IconButton(
                        tooltip: 'Save for offline',
                        icon: const Icon(Icons.download_outlined, size: 26),
                        color: const Color(0xFFECECFF),
                        onPressed: _downloadCurrentSong,
                      ),
              IconButton(
                icon: Icon(
                    _isFavourite ? Icons.favorite : Icons.favorite_border,
                    size: 28),
                color: _isFavourite ? Colors.red : const Color(0xFFECECFF),
                onPressed: _toggleFavourite,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Rotating artwork ───────────────────────────────────────────────────────

  Widget _buildArtwork(Song? song) {
    return StreamBuilder<bool>(
      stream: _audioService.playingStream,
      initialData: _audioService.isPlaying,
      builder: (context, snapshot) {
        final isPlaying = snapshot.data ?? false;

        if (isPlaying &&
            _rotationController.status != AnimationStatus.forward) {
          _rotationController.repeat();
        } else if (!isPlaying) {
          _rotationController.stop();
        }

        return RotationTransition(
          turns: _rotationController,
          child: Container(
            width: 280, height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00E5FF).withOpacity(0.3),
                  blurRadius: 40, spreadRadius: 5,
                ),
              ],
            ),
            child: ClipOval(
              child: song != null
                  ? Image.network(song.artworkUrl, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _artworkFallback())
                  : _artworkFallback(),
            ),
          ),
        );
      },
    );
  }

  Widget _artworkFallback() => Container(
        color: const Color(0xFF18182A),
        child: const Icon(Icons.music_note, size: 100, color: Color(0xFF00E5FF)),
      );

  // ── Song info ──────────────────────────────────────────────────────────────

  Widget _buildSongInfo(Song? song) {
    if (song == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        children: [
          Text(song.title,
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFECECFF)),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          Text(song.artist,
              style: TextStyle(
                  fontSize: 16,
                  color: const Color(0xFFECECFF).withOpacity(0.7)),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  // ── Progress bar ───────────────────────────────────────────────────────────

  Widget _buildProgressBar() {
    return StreamBuilder<Duration>(
      stream: _audioService.positionStream,
      initialData: _audioService.position,
      builder: (context, posSnap) {
        return StreamBuilder<Duration?>(
          stream: _audioService.durationStream,
          initialData: _audioService.duration,
          builder: (context, durSnap) {
            final position = posSnap.data ?? Duration.zero;
            final duration = durSnap.data ?? Duration.zero;
            final progress = duration.inMilliseconds > 0
                ? position.inMilliseconds / duration.inMilliseconds
                : 0.0;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                children: [
                  SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 6),
                      overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 14),
                      activeTrackColor:   const Color(0xFF00E5FF),
                      inactiveTrackColor: const Color(0xFF18182A),
                      thumbColor:         const Color(0xFF00E5FF),
                      overlayColor: const Color(0xFF00E5FF).withOpacity(0.2),
                    ),
                    child: Slider(
                      value: progress.clamp(0.0, 1.0),
                      onChanged: _audioService.isStreaming
                          ? null
                          : (v) {
                              _audioService.seek(Duration(
                                milliseconds:
                                    (v * duration.inMilliseconds).round(),
                              ));
                            },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_formatDuration(position),
                            style: TextStyle(
                                fontSize: 12,
                                color: const Color(0xFFECECFF).withOpacity(0.6))),
                        Text(_formatDuration(duration),
                            style: TextStyle(
                                fontSize: 12,
                                color: const Color(0xFFECECFF).withOpacity(0.6))),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Controls ───────────────────────────────────────────────────────────────

  Widget _buildControls() {
    return StreamBuilder<GizaPlayerState>(
      stream: _audioService.playerStateStream,
      builder: (context, snapshot) {
        final state = snapshot.data;
        final status = state?.status ?? GizaPlayerStatus.idle;
        final isPlaying = state?.playing ?? false;
        final isShuffle = state?.isShuffle ?? false;
        final isRepeat = state?.isRepeat ?? false;

        final showLoader = status == GizaPlayerStatus.downloading || 
                           status == GizaPlayerStatus.loading;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _controlBtn(
                size: 44,
                icon: Icons.shuffle,
                color: isShuffle ? const Color(0xFF00E5FF) : const Color(0xFFECECFF).withOpacity(0.5),
                onPressed: _audioService.toggleShuffle,
              ),
              _controlBtn(
                size: 52,
                icon: Icons.skip_previous,
                iconSize: 28,
                onPressed: _audioService.previous,
              ),

              // Play / Pause / Loading Container
              Container(
                width: 68, height: 68,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF00E5FF), Color(0xFF0080FF)]),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00E5FF).withOpacity(0.4),
                      blurRadius: 15, spreadRadius: 1,
                    ),
                  ],
                ),
                child: showLoader
                    ? const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      )
                    : IconButton(
                        icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow, size: 36),
                        color: Colors.white,
                        onPressed: _audioService.togglePlayPause,
                      ),
              ),

              _controlBtn(
                size: 52,
                icon: Icons.skip_next,
                iconSize: 28,
                onPressed: _audioService.next,
              ),
              _controlBtn(
                size: 44,
                icon: Icons.repeat,
                color: isRepeat ? const Color(0xFF00E5FF) : const Color(0xFFECECFF).withOpacity(0.5),
                onPressed: _audioService.toggleRepeat,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _controlBtn({
    required double size,
    required IconData icon,
    double iconSize = 24,
    Color color = const Color(0xFFECECFF),
    required VoidCallback onPressed,
  }) {
    return Container(
      width: size, height: size,
      decoration: const BoxDecoration(
          color: Color(0xFF18182A), shape: BoxShape.circle),
      child: IconButton(
        icon: Icon(icon, size: iconSize),
        color: color,
        onPressed: onPressed,
      ),
    );
  }
}

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
  final _db = HiveHelper.instance;

  late AnimationController _rotationController;
  bool _isFavourite = false;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _loadFavouriteStatus();
  }

  void _loadFavouriteStatus() {
    final song = _audioService.currentSong;
    if (song?.youtubeVideoId != null) {
      final saved = _db.getSongByVideoId(song!.youtubeVideoId!);
      setState(() => _isFavourite = saved?.isFavourite ?? false);
    }
  }

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

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

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
          child: Column(
            children: [
              // Header
              _buildHeader(),

              const Spacer(),

              // Artwork
              _buildArtwork(song),

              const Spacer(),

              // Song info
              _buildSongInfo(song),

              const SizedBox(height: 24),

              // Progress bar
              _buildProgressBar(),

              const SizedBox(height: 32),

              // Controls
              _buildControls(),

              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down, size: 32),
            color: const Color(0xFFECECFF),
            onPressed: () => Navigator.pop(context),
          ),
          const Text(
            'Now Playing',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFFECECFF),
            ),
          ),
          IconButton(
            icon: Icon(
              _isFavourite ? Icons.favorite : Icons.favorite_border,
              size: 28,
            ),
            color: _isFavourite ? Colors.red : const Color(0xFFECECFF),
            onPressed: _toggleFavourite,
          ),
        ],
      ),
    );
  }

  Widget _buildArtwork(Song? song) {
    return StreamBuilder<bool>(
      stream: _audioService.playingStream,
      initialData: _audioService.isPlaying,
      builder: (context, snapshot) {
        final isPlaying = snapshot.data ?? false;

        if (isPlaying && _rotationController.status != AnimationStatus.forward) {
          _rotationController.repeat();
        } else if (!isPlaying) {
          _rotationController.stop();
        }

        return RotationTransition(
          turns: _rotationController,
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00E5FF).withOpacity(0.3),
                  blurRadius: 40,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: ClipOval(
              child: song != null
                  ? Image.network(
                      song.artworkUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFF18182A),
                        child: const Icon(
                          Icons.music_note,
                          size: 100,
                          color: Color(0xFF00E5FF),
                        ),
                      ),
                    )
                  : Container(
                      color: const Color(0xFF18182A),
                      child: const Icon(
                        Icons.music_note,
                        size: 100,
                        color: Color(0xFF00E5FF),
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSongInfo(Song? song) {
    if (song == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        children: [
          Text(
            song.title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFFECECFF),
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            song.artist,
            style: TextStyle(
              fontSize: 16,
              color: const Color(0xFFECECFF).withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return StreamBuilder<Duration>(
      stream: _audioService.positionStream,
      initialData: _audioService.position,
      builder: (context, positionSnapshot) {
        return StreamBuilder<Duration?>(
          stream: _audioService.durationStream,
          initialData: _audioService.duration,
          builder: (context, durationSnapshot) {
            final position = positionSnapshot.data ?? Duration.zero;
            final duration = durationSnapshot.data ?? Duration.zero;
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
                        enabledThumbRadius: 6,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 14,
                      ),
                      activeTrackColor: const Color(0xFF00E5FF),
                      inactiveTrackColor: const Color(0xFF18182A),
                      thumbColor: const Color(0xFF00E5FF),
                      overlayColor: const Color(0xFF00E5FF).withOpacity(0.2),
                    ),
                    child: Slider(
                      value: progress.clamp(0.0, 1.0),
                      onChanged: (value) {
                        final newPosition = Duration(
                          milliseconds: (value * duration.inMilliseconds).round(),
                        );
                        _audioService.seek(newPosition);
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(position),
                          style: TextStyle(
                            fontSize: 12,
                            color: const Color(0xFFECECFF).withOpacity(0.6),
                          ),
                        ),
                        Text(
                          _formatDuration(duration),
                          style: TextStyle(
                            fontSize: 12,
                            color: const Color(0xFFECECFF).withOpacity(0.6),
                          ),
                        ),
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

  Widget _buildControls() {
    return StreamBuilder<bool>(
      stream: _audioService.playingStream,
      initialData: _audioService.isPlaying,
      builder: (context, snapshot) {
        final isPlaying = snapshot.data ?? false;

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Shuffle (placeholder)
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF18182A),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.shuffle),
                color: const Color(0xFFECECFF).withOpacity(0.5),
                onPressed: () {
                  // Shuffle functionality can be implemented
                },
              ),
            ),

            const SizedBox(width: 24),

            // Previous
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFF18182A),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.skip_previous, size: 32),
                color: const Color(0xFFECECFF),
                onPressed: () {
                  // Previous song functionality can be implemented
                },
              ),
            ),

            const SizedBox(width: 24),

            // Play/Pause
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00E5FF), Color(0xFF0080FF)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00E5FF).withOpacity(0.4),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: IconButton(
                icon: Icon(
                  isPlaying ? Icons.pause : Icons.play_arrow,
                  size: 40,
                ),
                color: Colors.white,
                onPressed: _audioService.togglePlayPause,
              ),
            ),

            const SizedBox(width: 24),

            // Next
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFF18182A),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.skip_next, size: 32),
                color: const Color(0xFFECECFF),
                onPressed: () {
                  // Next song functionality can be implemented
                },
              ),
            ),

            const SizedBox(width: 24),

            // Repeat (placeholder)
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF18182A),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.repeat),
                color: const Color(0xFFECECFF).withOpacity(0.5),
                onPressed: () {
                  // Repeat functionality can be implemented
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
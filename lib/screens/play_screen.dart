import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/audio_service.dart';
import '../db/hive_helper.dart';
import '../providers/audio_provider.dart';

// ── Color tokens (match home/login) ────────────────────────────────────────
const _bg        = Color(0xFF0C0C14);
const _surface   = Color(0xFF141420);
const _surface2  = Color(0xFF1C1C2A);
const _accent    = Color(0xFFFF8C42);
const _accent2   = Color(0xFFFF5F6D);
const _textPri   = Color(0xFFF0EFFF);
const _textSec   = Color(0xFF6E6E8A);

class PlayScreen extends StatefulWidget {
  const PlayScreen({super.key});

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen>
    with SingleTickerProviderStateMixin {
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
      duration: const Duration(seconds: 24),
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

  Future<void> _toggleFavourite() async {
    final song = _audioService.currentSong;
    if (song == null) return;
    final newValue = !_isFavourite;
    await _db.saveSong(song.copyWith(isFavourite: newValue));
    await _db.toggleFavourite(song, newValue);
    setState(() => _isFavourite = newValue);
    if (mounted) {
      _showSnack(newValue ? 'Added to favourites' : 'Removed from favourites');
    }
  }

  Future<void> _downloadCurrentSong() async {
    final song = _audioService.currentSong;
    if (song == null || _isDownloading || _isDownloaded) return;
    setState(() => _isDownloading = true);
    _audioService.downloadOnly(
      song,
      onDone: (saved) {
        if (mounted) {
          setState(() { _isDownloading = false; _isDownloaded = true; });
          _showSnack('"${saved.title}" saved for offline');
        }
      },
      onError: (e) {
        if (mounted) {
          setState(() => _isDownloading = false);
          _showSnack('Download failed: $e');
        }
      },
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: _textPri, fontSize: 13)),
        backgroundColor: _surface2,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioProvider>(
      builder: (context, audioProvider, _) {
        final song = audioProvider.currentSong;

        return Scaffold(
          backgroundColor: _bg,
          body: Stack(
            children: [
              // Ambient glow behind artwork
              Positioned(
                top: MediaQuery.of(context).size.height * 0.15,
                left: MediaQuery.of(context).size.width * 0.1,
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.8,
                  height: MediaQuery.of(context).size.width * 0.8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        _accent.withOpacity(0.12),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              SafeArea(
                child: Column(
                  children: [
                    _buildHeader(),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const NeverScrollableScrollPhysics(),
                        child: SizedBox(
                          height: MediaQuery.of(context).size.height -
                              MediaQuery.of(context).padding.top -
                              MediaQuery.of(context).padding.bottom -
                              72, // header height approx
                          child: Column(
                            children: [
                              const SizedBox(height: 16),
                              _buildArtwork(audioProvider),
                              const SizedBox(height: 32),
                              _buildSongInfo(audioProvider),
                              const SizedBox(height: 28),
                              _buildProgressBar(audioProvider),
                              const SizedBox(height: 32),
                              _buildControls(audioProvider),
                              const Spacer(),
                            ],
                          ),
                        ),
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
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Consumer<AudioProvider>(
      builder: (context, audioProvider, _) {
        final streaming = _audioService.isStreaming && !_isDownloaded;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Back chevron
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFF2A2A3E), width: 1),
                  ),
                  child: const Icon(Icons.keyboard_arrow_down_rounded,
                      color: _textPri, size: 24),
                ),
              ),

              // Title + streaming badge
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Now Playing',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _textPri,
                      letterSpacing: -0.3,
                    ),
                  ),
                  if (streaming) ...[
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _accent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: _accent.withOpacity(0.3), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.wifi_rounded,
                              size: 10,
                              color: _accent.withOpacity(0.9)),
                          const SizedBox(width: 3),
                          Text(
                            'Streaming',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: _accent.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),

              // Action buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (streaming)
                    _isDownloading
                        ? const SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: _accent),
                          )
                        : _HeaderBtn(
                            icon: Icons.download_outlined,
                            onPressed: _downloadCurrentSong,
                          ),
                  const SizedBox(width: 4),
                  _HeaderBtn(
                    icon: _isFavourite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: _isFavourite ? _accent2 : _textSec,
                    onPressed: _toggleFavourite,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Artwork ────────────────────────────────────────────────────────────────

  Widget _buildArtwork(AudioProvider audioProvider) {
    final currentSong = audioProvider.currentSong;
    final isPlaying   = audioProvider.isPlaying;

    if (isPlaying &&
        _rotationController.status != AnimationStatus.forward) {
      _rotationController.repeat();
    } else if (!isPlaying) {
      _rotationController.stop();
    }

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer ring pulse decoration
          Container(
            width: 300, height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: _accent.withOpacity(0.08), width: 20),
            ),
          ),
          Container(
            width: 268, height: 268,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: _accent.withOpacity(0.05), width: 8),
            ),
          ),

          // Rotating artwork disc
          RotationTransition(
            turns: _rotationController,
            child: Container(
              width: 248, height: 248,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _accent.withOpacity(isPlaying ? 0.30 : 0.12),
                    blurRadius: isPlaying ? 48 : 24,
                    spreadRadius: isPlaying ? 6 : 0,
                  ),
                ],
              ),
              child: ClipOval(
                child: currentSong != null
                    ? Image.network(
                        currentSong.artworkUrl,
                        key: ValueKey(currentSong.youtubeVideoId),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _artworkFallback(),
                      )
                    : _artworkFallback(),
              ),
            ),
          ),

          // Center vinyl hole
          Container(
            width: 20, height: 20,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: _bg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _artworkFallback() => Container(
        color: _surface2,
        child: const Icon(Icons.music_note_rounded,
            size: 90, color: _accent),
      );

  // ── Song info ──────────────────────────────────────────────────────────────

  Widget _buildSongInfo(AudioProvider audioProvider) {
    final song = audioProvider.currentSong;
    if (song == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  song.title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: _textPri,
                    letterSpacing: -0.6,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  song.artist,
                  style: const TextStyle(
                    fontSize: 14,
                    color: _textSec,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Progress bar ───────────────────────────────────────────────────────────

  // Widget _buildProgressBar() {
  //   return Consumer<AudioProvider>(
  //     builder: (context, audioProvider, _) {
  //       final position = audioProvider.position;
  //       final duration = audioProvider.duration ?? Duration.zero;
  //       final progress = duration.inMilliseconds > 0
  //           ? position.inMilliseconds / duration.inMilliseconds
  //           : 0.0;

  //       return Padding(
  //         padding: const EdgeInsets.symmetric(horizontal: 32.0),
  //         child: Column(
  //           children: [
  //             SliderTheme(
  //               data: SliderThemeData(
  //                 trackHeight: 4,
  //                 thumbShape: const RoundSliderThumbShape(
  //                     enabledThumbRadius: 6),
  //                 overlayShape: const RoundSliderOverlayShape(
  //                     overlayRadius: 14),
  //                 activeTrackColor:   const Color(0xFF00E5FF),
  //                 inactiveTrackColor: const Color(0xFF18182A),
  //                 thumbColor:         const Color(0xFF00E5FF),
  //                 overlayColor: const Color(0xFF00E5FF).withOpacity(0.2),
  //               ),
  //               child: Slider(
  //                 value: progress.clamp(0.0, 1.0),
  //                 onChanged: _audioService.isStreaming
  //                     ? null
  //                     : (v) {
  //                         audioProvider.seek(Duration(
  //                           milliseconds:
  //                               (v * duration.inMilliseconds).round(),
  //                         ));
  //                       },
  //               ),
  //             ),
  //             Padding(
  //               padding: const EdgeInsets.symmetric(horizontal: 8.0),
  //               child: Row(
  //                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //                 children: [
  //                   Text(_formatDuration(position),
  //                       style: TextStyle(
  //                           fontSize: 12,
  //                           color: const Color(0xFFECECFF).withOpacity(0.6))),
  //                   Text(_formatDuration(duration),
  //                       style: TextStyle(
  //                           fontSize: 12,
  //                           color: const Color(0xFFECECFF).withOpacity(0.6))),
  //                 ],
  //               ),
  //             ),
  //           ],
  //         ),
  //       );
  //     },
  //   );
  // }


  Widget _buildProgressBar(AudioProvider audioProvider) {
    final position = audioProvider.position;
    final duration = audioProvider.duration ?? Duration.zero;
    final progress = duration.inMilliseconds > 0
        ? position.inMilliseconds / duration.inMilliseconds
        : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          // Custom track
          LayoutBuilder(
            builder: (context, constraints) {
              final trackWidth = constraints.maxWidth;
              final filled    = trackWidth * progress.clamp(0.0, 1.0);
              return GestureDetector(
                onHorizontalDragUpdate: _audioService.isStreaming
                    ? null
                    : (details) {
                        final ratio = (details.localPosition.dx / trackWidth)
                            .clamp(0.0, 1.0);
                        audioProvider.seek(Duration(
                          milliseconds:
                              (ratio * duration.inMilliseconds).round(),
                        ));
                      },
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    // Track background
                    Container(
                      height: 4,
                      width: trackWidth,
                      decoration: BoxDecoration(
                        color: _surface2,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    // Filled portion
                    Container(
                      height: 4,
                      width: filled,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_accent, _accent2]),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    // Thumb
                    Positioned(
                      left: (filled - 7).clamp(0.0, trackWidth - 14),
                      child: Container(
                        width: 14, height: 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _textPri,
                          boxShadow: [
                            BoxShadow(
                              color: _accent.withOpacity(0.4),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_fmt(position),
                  style: const TextStyle(
                      color: _textSec, fontSize: 11,
                      fontWeight: FontWeight.w600)),
              Text(_fmt(duration),
                  style: const TextStyle(
                      color: _textSec, fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Controls ───────────────────────────────────────────────────────────────

  Widget _buildControls(AudioProvider audioProvider) {
    final isPlaying = audioProvider.isPlaying;
    final isShuffle = audioProvider.isShuffle;
    final isRepeat  = audioProvider.isRepeat;
    final status    = audioProvider.status;
    final showLoader = status == GizaPlayerStatus.downloading ||
                       status == GizaPlayerStatus.loading;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Shuffle
          _ControlBtn(
            size: 44,
            icon: Icons.shuffle_rounded,
            iconSize: 20,
            color: isShuffle ? _accent : _textSec,
            filled: isShuffle,
            onPressed: audioProvider.toggleShuffle,
          ),

          // Previous
          _ControlBtn(
            size: 52,
            icon: Icons.skip_previous_rounded,
            iconSize: 28,
            color: _textPri,
            onPressed: audioProvider.previous,
          ),

          // Play / Pause
          GestureDetector(
            onTap: showLoader ? null : audioProvider.togglePlayPause,
            child: Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_accent, _accent2],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _accent.withOpacity(0.45),
                    blurRadius: 20, spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: showLoader
                  ? const Padding(
                      padding: EdgeInsets.all(18),
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5),
                    )
                  : Icon(
                      isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white, size: 36,
                    ),
            ),
          ),

          // Next
          _ControlBtn(
            size: 52,
            icon: Icons.skip_next_rounded,
            iconSize: 28,
            color: _textPri,
            onPressed: audioProvider.next,
          ),

          // Repeat
          _ControlBtn(
            size: 44,
            icon: Icons.repeat_rounded,
            iconSize: 20,
            color: isRepeat ? _accent : _textSec,
            filled: isRepeat,
            onPressed: audioProvider.toggleRepeat,
          ),
        ],
      ),
    );
  }
}

// ── Helper widgets ──────────────────────────────────────────────────────────

class _HeaderBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _HeaderBtn({
    required this.icon,
    required this.onPressed,
    this.color = _textSec,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2A2A3E), width: 1),
        ),
        child: Icon(icon, size: 20, color: color),
      ),
    );
  }
}

class _ControlBtn extends StatelessWidget {
  final double size;
  final IconData icon;
  final double iconSize;
  final Color color;
  final bool filled;
  final VoidCallback onPressed;

  const _ControlBtn({
    required this.size,
    required this.icon,
    required this.iconSize,
    required this.color,
    required this.onPressed,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(
          color: filled ? _accent.withOpacity(0.1) : _surface,
          shape: BoxShape.circle,
          border: Border.all(
            color: filled
                ? _accent.withOpacity(0.3)
                : const Color(0xFF2A2A3E),
            width: 1,
          ),
        ),
        child: Icon(icon, size: iconSize, color: color),
      ),
    );
  }
}
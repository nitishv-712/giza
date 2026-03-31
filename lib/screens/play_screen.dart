// lib/screens/play_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/audio_service.dart';
import '../db/hive_helper.dart';
import '../providers/audio_provider.dart';

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

  // ── Theme helpers ──────────────────────────────────────────────────────────

  ColorScheme _cs(BuildContext ctx) => Theme.of(ctx).colorScheme;
  Color _bg(BuildContext ctx)      => Theme.of(ctx).scaffoldBackgroundColor;
  Color _surf(BuildContext ctx)    => _cs(ctx).surface;
  Color _surf2(BuildContext ctx)   => _cs(ctx).surfaceContainerHighest;
  Color _accent(BuildContext ctx)  => _cs(ctx).primary;
  Color _accent2(BuildContext ctx) => _cs(ctx).secondary;
  Color _textPri(BuildContext ctx) => _cs(ctx).onSurface;
  Color _textSec(BuildContext ctx) => _cs(ctx).onSurface.withOpacity(0.55);
  Color _border(BuildContext ctx)  => _cs(ctx).outline;

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
        content: Text(msg,
            style: TextStyle(color: _textPri(context), fontSize: 13)),
        backgroundColor: _surf2(context),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        final accent = _accent(context);

        return Scaffold(
          backgroundColor: _bg(context),
          body: Stack(
            children: [
              // Ambient glow — uses theme accent, visible on both light & dark
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
                        accent.withOpacity(0.10),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              SafeArea(
                child: Column(
                  children: [
                    _buildHeader(context),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const NeverScrollableScrollPhysics(),
                        child: SizedBox(
                          height: MediaQuery.of(context).size.height -
                              MediaQuery.of(context).padding.top -
                              MediaQuery.of(context).padding.bottom -
                              72,
                          child: Column(
                            children: [
                              const SizedBox(height: 16),
                              _buildArtwork(context, audioProvider),
                              const SizedBox(height: 32),
                              _buildSongInfo(context, audioProvider),
                              const SizedBox(height: 28),
                              _buildProgressBar(context, audioProvider),
                              const SizedBox(height: 32),
                              _buildControls(context, audioProvider),
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

  Widget _buildHeader(BuildContext context) {
    return Consumer<AudioProvider>(
      builder: (ctx, audioProvider, _) {
        final streaming = _audioService.isStreaming && !_isDownloaded;
        final accent    = _accent(ctx);
        final textPri   = _textPri(ctx);
        final textSec   = _textSec(ctx);
        final surf      = _surf(ctx);
        final border    = _border(ctx);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Back button
              GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: surf,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: border, width: 0.5),
                  ),
                  child: Icon(Icons.keyboard_arrow_down_rounded,
                      color: textPri, size: 24),
                ),
              ),

              // Title + streaming badge
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Now Playing',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: textPri,
                      letterSpacing: -0.3,
                    ),
                  ),
                  if (streaming) ...[
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: accent.withOpacity(0.3), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.wifi_rounded,
                              size: 10,
                              color: accent.withOpacity(0.9)),
                          const SizedBox(width: 3),
                          Text(
                            'Streaming',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: accent.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),

              // Actions
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (streaming)
                    _isDownloading
                        ? SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: accent),
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
                    color: _isFavourite ? _accent2(ctx) : textSec,
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

  Widget _buildArtwork(BuildContext context, AudioProvider audioProvider) {
    final currentSong = audioProvider.currentSong;
    final isPlaying   = audioProvider.isPlaying;
    final accent      = _accent(context);
    final bg          = _bg(context);
    final surf2       = _surf2(context);

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
          Container(
            width: 300, height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: accent.withOpacity(0.08), width: 20),
            ),
          ),
          Container(
            width: 268, height: 268,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: accent.withOpacity(0.05), width: 8),
            ),
          ),
          RotationTransition(
            turns: _rotationController,
            child: Container(
              width: 248, height: 248,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: accent.withOpacity(isPlaying ? 0.28 : 0.10),
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
                        errorBuilder: (_, __, ___) =>
                            _artworkFallback(surf2, accent),
                      )
                    : _artworkFallback(surf2, accent),
              ),
            ),
          ),
          // Vinyl center hole — uses scaffold bg so it punches through cleanly
          Container(
            width: 20, height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: bg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _artworkFallback(Color surf2, Color accent) => Container(
        color: surf2,
        child: Icon(Icons.music_note_rounded, size: 90, color: accent),
      );

  // ── Song info ──────────────────────────────────────────────────────────────

  Widget _buildSongInfo(BuildContext context, AudioProvider audioProvider) {
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
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: _textPri(context),
                    letterSpacing: -0.6,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  song.artist,
                  style: TextStyle(
                    fontSize: 14,
                    color: _textSec(context),
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

  Widget _buildProgressBar(
      BuildContext context, AudioProvider audioProvider) {
    final position = audioProvider.position;
    final duration = audioProvider.duration ?? Duration.zero;
    final progress = duration.inMilliseconds > 0
        ? position.inMilliseconds / duration.inMilliseconds
        : 0.0;
    final accent  = _accent(context);
    final accent2 = _accent2(context);
    final surf2   = _surf2(context);
    final textPri = _textPri(context);
    final textSec = _textSec(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          LayoutBuilder(
            builder: (ctx, constraints) {
              final trackWidth = constraints.maxWidth;
              final filled     = trackWidth * progress.clamp(0.0, 1.0);
              return GestureDetector(
                onHorizontalDragUpdate: _audioService.isStreaming
                    ? null
                    : (details) {
                        final ratio =
                            (details.localPosition.dx / trackWidth)
                                .clamp(0.0, 1.0);
                        audioProvider.seek(Duration(
                          milliseconds:
                              (ratio * duration.inMilliseconds).round(),
                        ));
                      },
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    Container(
                      height: 4,
                      width: trackWidth,
                      decoration: BoxDecoration(
                        color: surf2,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Container(
                      height: 4,
                      width: filled,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                            colors: [accent, accent2]),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Positioned(
                      left: (filled - 7).clamp(0.0, trackWidth - 14),
                      child: Container(
                        width: 14, height: 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: textPri,
                          boxShadow: [
                            BoxShadow(
                              color: accent.withOpacity(0.4),
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
                  style: TextStyle(
                      color: textSec,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
              Text(_fmt(duration),
                  style: TextStyle(
                      color: textSec,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Controls ───────────────────────────────────────────────────────────────

  Widget _buildControls(BuildContext context, AudioProvider audioProvider) {
    final isPlaying  = audioProvider.isPlaying;
    final isShuffle  = audioProvider.isShuffle;
    final isRepeat   = audioProvider.isRepeat;
    final status     = audioProvider.status;
    final showLoader = status == GizaPlayerStatus.downloading ||
                       status == GizaPlayerStatus.loading;
    final accent  = _accent(context);
    final accent2 = _accent2(context);
    final textPri = _textPri(context);
    final textSec = _textSec(context);
    final surf    = _surf(context);
    final border  = _border(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _ControlBtn(
            size: 44,
            icon: Icons.shuffle_rounded,
            iconSize: 20,
            color: isShuffle ? accent : textSec,
            filled: isShuffle,
            surface: surf,
            border: border,
            accent: accent,
            onPressed: audioProvider.toggleShuffle,
          ),
          _ControlBtn(
            size: 52,
            icon: Icons.skip_previous_rounded,
            iconSize: 28,
            color: textPri,
            surface: surf,
            border: border,
            accent: accent,
            onPressed: audioProvider.previous,
          ),
          GestureDetector(
            onTap: showLoader ? null : audioProvider.togglePlayPause,
            child: Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [accent, accent2],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: accent.withOpacity(0.45),
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
          _ControlBtn(
            size: 52,
            icon: Icons.skip_next_rounded,
            iconSize: 28,
            color: textPri,
            surface: surf,
            border: border,
            accent: accent,
            onPressed: audioProvider.next,
          ),
          _ControlBtn(
            size: 44,
            icon: Icons.repeat_rounded,
            iconSize: 20,
            color: isRepeat ? accent : textSec,
            filled: isRepeat,
            surface: surf,
            border: border,
            accent: accent,
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
  final Color? color;
  final VoidCallback onPressed;

  const _HeaderBtn({
    required this.icon,
    required this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outline, width: 0.5),
        ),
        child: Icon(icon, size: 20,
            color: color ?? cs.onSurface.withOpacity(0.55)),
      ),
    );
  }
}

class _ControlBtn extends StatelessWidget {
  final double size;
  final IconData icon;
  final double iconSize;
  final Color color;
  final Color surface;
  final Color border;
  final Color accent;
  final bool filled;
  final VoidCallback onPressed;

  const _ControlBtn({
    required this.size,
    required this.icon,
    required this.iconSize,
    required this.color,
    required this.surface,
    required this.border,
    required this.accent,
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
          color: filled ? accent.withOpacity(0.12) : surface,
          shape: BoxShape.circle,
          border: Border.all(
            color: filled ? accent.withOpacity(0.35) : border,
            width: filled ? 1 : 0.5,
          ),
        ),
        child: Icon(icon, size: iconSize, color: color),
      ),
    );
  }
}
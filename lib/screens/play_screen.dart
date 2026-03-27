// lib/screens/play_screen.dart
//
// Full-screen now-playing UI.
// Audio source : YouTube IFrame (YoutubePlayerController, hidden 1×1 px)
// Metadata     : Audius (title, artist, artwork, genre, play counts)
// Downloads    : REMOVED — streaming only

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../db/hive_helper.dart';
import '../models/song.dart';
import '../services/audio_service.dart';

// ─── Theme ────────────────────────────────────────────────────────────────────

const _kBg     = Color(0xFF080810);
const _kCard   = Color(0xFF18182A);
const _kCyan   = Color(0xFF00E5FF);
const _kText   = Color(0xFFECECFF);
const _kSub    = Color(0xFF6060A0);
const _kBorder = Color(0xFF242438);

// ─── PlayScreen ───────────────────────────────────────────────────────────────

class PlayScreen extends StatefulWidget {
  final Song song;
  const PlayScreen({super.key, required this.song});

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen>
    with TickerProviderStateMixin {
  final _audio = AudioService.instance;
  final _db    = HiveHelper.instance;

  late Song _song;
  bool _isShuffle = false;
  bool _isRepeat  = false;

  late AnimationController _artworkAnim;

  @override
  void initState() {
    super.initState();
    _song = widget.song;

    _artworkAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    // Trigger playback only if this is a different track
    if (_audio.currentSong?.audiusTrackId != _song.audiusTrackId ||
        !_audio.isPlaying) {
      _audio.play(_song).catchError((e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ));
        }
      });
    }

    // Rebuild on player state changes
    _audio.playerStateStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _artworkAnim.dispose();
    super.dispose();
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _toggleFavourite() async {
    Song song = _song;
    if (song.audiusTrackId != null) {
      final existing = _db.getSongByAudiusId(song.audiusTrackId!);
      if (existing == null) {
        song = await _db.saveSong(song.copyWith(createdAt: DateTime.now()));
      } else {
        song = existing;
      }
    }
    final newVal = !song.isFavourite;
    await _db.toggleFavourite(song, newVal);
    if (mounted) setState(() => _song = song.copyWith(isFavourite: newVal));
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: Stack(
        children: [
          // ── Blurred artwork backdrop ──────────────────────────────────────
          if (_song.artworkUrl.isNotEmpty) ...[
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                child: Opacity(
                  opacity: 0.12,
                  child: _ArtWidget(_song.artworkUrl, fit: BoxFit.cover),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.6, -0.8),
                    radius: 0.9,
                    colors: [
                      _kCyan.withOpacity(0.06),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],

          // ── Hidden YouTube IFrame (1×1 px — audio only) ───────────────────
          if (_audio.controller != null)
            Positioned(
              left: -1,
              top: -1,
              width: 1,
              height: 1,
              child: YoutubePlayer(
                controller: _audio.controller!,
                showVideoProgressIndicator: false,
              ),
            ),

          // ── Custom player UI ──────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                _buildArtwork(),
                const SizedBox(height: 20),
                _buildSongInfo(),
                const SizedBox(height: 16),
                _buildProgressBar(),
                const SizedBox(height: 20),
                _buildTransport(),
                const SizedBox(height: 16),
                _buildBottomRow(),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Top bar ────────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
            color: _kSub,
            onPressed: () => Navigator.maybePop(context),
          ),
          const Spacer(),
          Column(children: [
            Text(
              'NOW PLAYING',
              style: TextStyle(
                color: _kSub,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 32,
              height: 2,
              decoration: BoxDecoration(
                color: _kCyan,
                borderRadius: BorderRadius.circular(1),
                boxShadow: [
                  BoxShadow(color: _kCyan.withOpacity(0.6), blurRadius: 6),
                ],
              ),
            ),
          ]),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.more_vert_rounded, size: 24),
            color: _kSub,
            onPressed: _showOptions,
          ),
        ],
      ),
    );
  }

  // ── Artwork ────────────────────────────────────────────────────────────────

  Widget _buildArtwork() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 4),
      child: AnimatedBuilder(
        animation: _artworkAnim,
        builder: (_, child) => Transform.scale(
          scale: 0.85 + 0.15 * _artworkAnim.value,
          child: Opacity(
            opacity: _artworkAnim.value.clamp(0.0, 1.0),
            child: child,
          ),
        ),
        child: StreamBuilder<GizaPlayerState>(
          stream: _audio.playerStateStream,
          builder: (_, snap) {
            final playing = snap.data?.playing ?? false;
            return AnimatedScale(
              scale: playing ? 1.0 : 0.88,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              child: AspectRatio(
                aspectRatio: 1,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: _kCyan
                            .withOpacity(playing ? 0.3 : 0.06),
                        blurRadius: playing ? 60 : 20,
                        offset: const Offset(0, 20),
                        spreadRadius: playing ? 4 : 0,
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.6),
                        blurRadius: 30,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: _ArtWidget(_song.artworkUrl),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Song info ──────────────────────────────────────────────────────────────

  Widget _buildSongInfo() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _song.title,
                  style: const TextStyle(
                    color: _kText,
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(_song.artist,
                    style: TextStyle(color: _kSub, fontSize: 14)),
                if (_song.genre.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                          color: _kCyan, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _song.genre.toUpperCase(),
                      style: TextStyle(
                        color: _kCyan.withOpacity(0.7),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                    if (_song.audiusPlayCount != null) ...[
                      const SizedBox(width: 10),
                      Icon(Icons.play_arrow_rounded,
                          size: 12, color: _kSub),
                      Text(_song.formattedPlayCount,
                          style:
                              TextStyle(color: _kSub, fontSize: 10)),
                    ],
                  ]),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _toggleFavourite,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Icon(
                _song.isFavourite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                key: ValueKey(_song.isFavourite),
                color: _song.isFavourite ? _kCyan : _kSub,
                size: 26,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Progress bar ───────────────────────────────────────────────────────────

  Widget _buildProgressBar() {
    return StreamBuilder<Duration>(
      stream: _audio.positionStream,
      builder: (_, posSnap) => StreamBuilder<Duration?>(
        stream: _audio.durationStream,
        builder: (_, durSnap) {
          final pos = posSnap.data ?? Duration.zero;
          final dur = durSnap.data ?? Duration.zero;
          final frac = dur.inMilliseconds > 0
              ? (pos.inMilliseconds / dur.inMilliseconds)
                  .clamp(0.0, 1.0)
              : 0.0;

          return Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 30),
            child: Column(children: [
              SliderTheme(
                data: SliderThemeData(
                  trackHeight: 2.5,
                  thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 5),
                  activeTrackColor: _kCyan,
                  inactiveTrackColor: _kBorder,
                  thumbColor: _kCyan,
                  overlayColor: _kCyan.withOpacity(0.12),
                ),
                child: Slider(
                  value: frac,
                  onChanged: (v) => _audio.seek(Duration(
                      milliseconds:
                          (v * dur.inMilliseconds).round())),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_fmt(pos),
                        style: TextStyle(
                            color: _kSub, fontSize: 11)),
                    Text(_fmt(dur),
                        style: TextStyle(
                            color: _kSub, fontSize: 11)),
                  ],
                ),
              ),
            ]),
          );
        },
      ),
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ── Transport ──────────────────────────────────────────────────────────────

  Widget _buildTransport() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _ctrlBtn(
            icon: Icons.shuffle_rounded,
            size: 20,
            color: _isShuffle ? _kCyan : _kSub,
            bg: _isShuffle
                ? _kCyan.withOpacity(0.12)
                : Colors.transparent,
            onTap: () => setState(() => _isShuffle = !_isShuffle),
          ),
          _ctrlBtn(
            icon: Icons.skip_previous_rounded,
            size: 30,
            color: _kText,
            bg: _kCard,
            onTap: () => _audio.seek(Duration.zero),
          ),
          // Main play / pause
          StreamBuilder<GizaPlayerState>(
            stream: _audio.playerStateStream,
            builder: (_, snap) {
              final state   = snap.data?.status ?? GizaPlayerStatus.idle;
              final playing = snap.data?.playing ?? false;
              final loading = state == GizaPlayerStatus.loading;
              return GestureDetector(
                onTap: _audio.togglePlayPause,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _kCyan,
                    boxShadow: [
                      BoxShadow(
                        color: _kCyan
                            .withOpacity(playing ? 0.5 : 0.2),
                        blurRadius: playing ? 30 : 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: loading
                      ? const Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Color(0xFF080810),
                              strokeWidth: 2.5,
                            ),
                          ),
                        )
                      : Icon(
                          playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: const Color(0xFF080810),
                          size: 38,
                        ),
                ),
              );
            },
          ),
          _ctrlBtn(
            icon: Icons.skip_next_rounded,
            size: 30,
            color: _kText,
            bg: _kCard,
            onTap: () {},
          ),
          _ctrlBtn(
            icon: Icons.repeat_rounded,
            size: 20,
            color: _isRepeat ? _kCyan : _kSub,
            bg: _isRepeat
                ? _kCyan.withOpacity(0.12)
                : Colors.transparent,
            onTap: () => setState(() => _isRepeat = !_isRepeat),
          ),
        ],
      ),
    );
  }

  Widget _ctrlBtn({
    required IconData   icon,
    required double     size,
    required Color      color,
    required Color      bg,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(shape: BoxShape.circle, color: bg),
        child: Icon(icon, color: color, size: size),
      ),
    );
  }

  // ── Bottom row ─────────────────────────────────────────────────────────────

  Widget _buildBottomRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // YouTube stream badge
          _badge(
            icon: Icons.smart_display_rounded,
            label: 'YouTube Stream',
            color: Colors.redAccent,
          ),
          // Audius metadata badge
          _badge(
            icon: Icons.library_music_rounded,
            label: 'Audius',
            color: _kCyan,
          ),
        ],
      ),
    );
  }

  Widget _badge({
    required IconData icon,
    required String   label,
    required Color    color,
  }) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kBorder),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ]),
    );
  }

  // ── Options sheet ──────────────────────────────────────────────────────────

  void _showOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _kCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 3,
              decoration: BoxDecoration(
                color: _kBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: _ArtWidget(_song.artworkUrl, size: 40),
              ),
              title: Text(_song.title,
                  style: TextStyle(color: _kText, fontSize: 14)),
              subtitle: Text(
                '${_song.artist} · ${_song.durationFormatted}',
                style: TextStyle(color: _kSub, fontSize: 12),
              ),
            ),
            const Divider(color: _kBorder, height: 1),
            if (_song.audiusTrackId != null)
              ListTile(
                leading:
                    Icon(Icons.open_in_browser_rounded, color: _kCyan),
                title: Text('Open on Audius',
                    style: TextStyle(color: _kText)),
                subtitle: Text('audius.co',
                    style:
                        TextStyle(color: _kSub, fontSize: 11)),
                onTap: () => Navigator.pop(context),
              ),
            if (_song.tags != null && _song.tags!.isNotEmpty)
              ListTile(
                leading: Icon(Icons.tag_rounded, color: _kSub),
                title: Text(_song.tags!,
                    style:
                        TextStyle(color: _kSub, fontSize: 12)),
              ),
            if (_song.audiusPlayCount != null)
              ListTile(
                leading:
                    Icon(Icons.bar_chart_rounded, color: _kSub),
                title: Text(
                  '${_song.formattedPlayCount} plays'
                  ' · ${_song.repostCount ?? 0} reposts'
                  ' · ${_song.favouriteCount ?? 0} favourites',
                  style: TextStyle(color: _kText, fontSize: 13),
                ),
              ),
            if (_song.mood != null)
              ListTile(
                leading:
                    Icon(Icons.mood_rounded, color: _kSub),
                title: Text('Mood: ${_song.mood}',
                    style:
                        TextStyle(color: _kText, fontSize: 13)),
              ),
            const Divider(color: _kBorder, height: 1),
            ListTile(
              leading: Icon(Icons.share_rounded, color: _kSub),
              title: Text('Share',
                  style: TextStyle(color: _kText)),
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ─── Widgets ──────────────────────────────────────────────────────────────────

class _ArtWidget extends StatelessWidget {
  final String  url;
  final double? size;
  final BoxFit  fit;

  const _ArtWidget(this.url, {this.size, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return _ph();
    return CachedNetworkImage(
      imageUrl: url,
      width: size,
      height: size,
      fit: fit,
      placeholder: (_, __) => _ph(),
      errorWidget: (_, __, ___) => _ph(),
    );
  }

  Widget _ph() => Container(
        width: size,
        height: size,
        color: const Color(0xFF18182A),
        child: Center(
          child: Icon(
            Icons.album_rounded,
            size: (size ?? 60) * 0.4,
            color: const Color(0xFF242438),
          ),
        ),
      );
}

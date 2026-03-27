// lib/screens/home_screen.dart
//
// Editorial dark aesthetic — "underground music platform" vibe.
// Ink-black base · electric cyan accent · bold typography.
//
// Discovery  : Audius REST API (free, no key)
// Audio      : YouTube IFrame via AudioService (hidden 1×1 player)
// Downloads  : REMOVED — streaming only

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../db/hive_helper.dart';
import '../models/song.dart';
import '../services/audio_service.dart';
import '../services/audius_service.dart';
import 'play_screen.dart';

// ─── Theme ────────────────────────────────────────────────────────────────────

const _kBg      = Color(0xFF080810);
const _kCard    = Color(0xFF18182A);
const _kCyan    = Color(0xFF00E5FF);
const _kCyanDim = Color(0xFF007A8A);
const _kText    = Color(0xFFECECFF);
const _kSub     = Color(0xFF6060A0);
const _kBorder  = Color(0xFF242438);

// ─── HomeScreen ───────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final _audius = AudiusService.instance;
  final _audio  = AudioService.instance;
  final _db     = HiveHelper.instance;

  final _searchCtrl  = TextEditingController();
  final _searchFocus = FocusNode();
  final _scrollCtrl  = ScrollController();

  bool    _searchOpen    = false;
  bool    _searchLoading = false;
  String? _searchError;
  int     _trendingTab   = 0; // 0 = weekly, 1 = underground

  List<Song>           _searchResults  = [];
  List<Song>           _trending       = [];
  List<Song>           _underground    = [];
  List<AudiusPlaylist> _playlists      = [];
  List<Song>           _savedSongs     = [];
  List<Song>           _recentlyPlayed = [];

  bool _trendingLoading    = true;
  bool _undergroundLoading = true;
  bool _playlistsLoading   = true;

  Song? _nowPlaying;
  bool  _isPlaying = false;

  late AnimationController _heroAnim;
  late AnimationController _listAnim;

  static const _genres = [
    'All', 'Electronic', 'Hip-Hop', 'Pop', 'Ambient', 'R&B', 'Jazz', 'Rock',
  ];
  String _selectedGenre = 'All';

  @override
  void initState() {
    super.initState();
    _heroAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000))
      ..forward();
    _listAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));

    _searchCtrl.addListener(_onSearchChanged);
    _loadAll();

    _audio.playerStateStream.listen((s) {
      if (mounted) {
        setState(() {
          _isPlaying = s.playing;
          _nowPlaying = _audio.currentSong;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl
      ..removeListener(_onSearchChanged)
      ..dispose();
    _searchFocus.dispose();
    _scrollCtrl.dispose();
    _heroAnim.dispose();
    _listAnim.dispose();
    super.dispose();
  }

  // ── Data ───────────────────────────────────────────────────────────────────

  Future<void> _loadAll() async {
    _loadSaved();
    _loadTrending();
    _loadUnderground();
    _loadPlaylists();
  }

  void _loadSaved() {
    if (!mounted) return;
    setState(() {
      _savedSongs     = _db.getAllSavedSongs();
      _recentlyPlayed = _db.getRecentlyPlayed(limit: 10);
    });
  }

  Future<void> _loadTrending() async {
    try {
      final tracks = await _audius.getTrendingTracks(limit: 25);
      if (mounted) {
        setState(() {
          _trending       = tracks;
          _trendingLoading = false;
        });
        _listAnim.forward(from: 0);
      }
    } catch (_) {
      if (mounted) setState(() => _trendingLoading = false);
    }
  }

  Future<void> _loadUnderground() async {
    try {
      final tracks = await _audius.getUndergroundTrending(limit: 20);
      if (mounted) {
        setState(() {
          _underground       = tracks;
          _undergroundLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _undergroundLoading = false);
    }
  }

  Future<void> _loadPlaylists() async {
    try {
      final playlists = await _audius.getTrendingPlaylists(limit: 8);
      if (mounted) {
        setState(() {
          _playlists      = playlists;
          _playlistsLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _playlistsLoading = false);
    }
  }

  void _onSearchChanged() {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) {
      setState(() {
        _searchResults = [];
        _searchError   = null;
      });
      return;
    }
    _doSearch(q);
  }

  Future<void> _doSearch(String q) async {
    setState(() {
      _searchLoading = true;
      _searchError   = null;
    });
    try {
      final r = await _audius.searchTracks(q, limit: 30);
      if (mounted) setState(() { _searchResults = r; _searchLoading = false; });
    } catch (e) {
      if (mounted) {
        setState(() {
          _searchError   = e.toString();
          _searchLoading = false;
        });
      }
    }
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _playSong(Song song) async {
    try {
      await _audio.play(song);
      final resolved = _audio.currentSong ?? song;
      if (mounted) setState(() { _nowPlaying = resolved; _isPlaying = true; });
      if (!mounted) return;
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => PlayScreen(song: resolved),
          transitionsBuilder: (_, anim, __, child) => SlideTransition(
            position: Tween(begin: const Offset(0, 1), end: Offset.zero)
                .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
            child: child,
          ),
          transitionDuration: const Duration(milliseconds: 420),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  List<Song> get _currentTabTracks {
    final list = _trendingTab == 0 ? _trending : _underground;
    if (_selectedGenre == 'All') return list;
    return list
        .where((s) => s.genre.toLowerCase().contains(_selectedGenre.toLowerCase()))
        .toList();
  }

  bool get _currentTabLoading =>
      _trendingTab == 0 ? _trendingLoading : _undergroundLoading;

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          _searchOpen ? _buildSearchView() : _buildMainScroll(),

          // Mini player
          if (_nowPlaying != null && !_searchOpen)
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: _buildMiniPlayer(),
            ),

          // Hidden YouTube IFrame — kept alive at root so audio continues
          // while navigating. PlayScreen also mounts this same controller.
          if (_audio.controller != null)
            Positioned(
              left: -1, top: -1, width: 1, height: 1,
              child: YoutubePlayer(
                controller: _audio.controller!,
                showVideoProgressIndicator: false,
              ),
            ),
        ],
      ),
    );
  }

  // ── Main scroll ────────────────────────────────────────────────────────────

  Widget _buildMainScroll() {
    return RefreshIndicator(
      color: _kCyan,
      backgroundColor: _kCard,
      onRefresh: _loadAll,
      child: CustomScrollView(
        controller: _scrollCtrl,
        slivers: [
          _buildAppBar(),
          if (_trending.isNotEmpty)
            SliverToBoxAdapter(child: _buildHero(_trending.first)),
          SliverToBoxAdapter(child: _buildSearchTap()),
          if (_recentlyPlayed.isNotEmpty) ...[
            _sliverTitle('Continue Listening', Icons.play_circle_outline_rounded),
            SliverToBoxAdapter(child: _buildHorizontalSongs(_recentlyPlayed)),
          ],
          if (_playlists.isNotEmpty || _playlistsLoading) ...[
            _sliverTitle('Trending Playlists', Icons.queue_music_rounded),
            SliverToBoxAdapter(
              child: _playlistsLoading
                  ? _skeletonRow(120, 130)
                  : _buildPlaylistShelf(),
            ),
          ],
          if (_savedSongs.isNotEmpty) ...[
            _sliverTitle('Your Library', Icons.library_music_outlined),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _FadeSlide(
                    index: i,
                    ctrl:  _listAnim,
                    child: _trackRow(_savedSongs[i]),
                  ),
                  childCount: _savedSongs.length,
                ),
              ),
            ),
          ],
          _sliverTitle('Tracks', Icons.trending_up_rounded,
              trailing: _buildTabs()),
          SliverToBoxAdapter(child: _buildGenreChips()),
          if (_currentTabLoading)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(48),
                child: Center(
                  child: CircularProgressIndicator(
                      color: _kCyan, strokeWidth: 1.5),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 130),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) {
                    final tracks = _currentTabTracks;
                    if (i >= tracks.length) return null;
                    return _FadeSlide(
                      index: i,
                      ctrl:  _listAnim,
                      child: _trackRow(tracks[i], showRank: true, rank: i + 1),
                    );
                  },
                  childCount: _currentTabTracks.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── App bar ────────────────────────────────────────────────────────────────

  Widget _buildAppBar() {
    final top = MediaQuery.of(context).padding.top;
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      expandedHeight: 0,
      floating: true,
      snap: true,
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            color: _kBg.withOpacity(0.88),
            padding: EdgeInsets.fromLTRB(22, top + 10, 12, 12),
            child: Row(
              children: [
                // Logo
                RichText(
                  text: TextSpan(children: [
                    TextSpan(
                      text: 'G',
                      style: TextStyle(
                        color: _kCyan,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'serif',
                      ),
                    ),
                    TextSpan(
                      text: 'IZA',
                      style: TextStyle(
                        color: _kText,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'serif',
                        letterSpacing: 4,
                      ),
                    ),
                  ]),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    border: Border.all(color: _kCyan.withOpacity(0.5)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'AUDIUS',
                    style: TextStyle(
                      color: _kCyan,
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => setState(() {
                    _searchOpen = true;
                    Future.delayed(
                        const Duration(milliseconds: 50),
                        _searchFocus.requestFocus);
                  }),
                  icon: Icon(Icons.search_rounded,
                      color: _kText.withOpacity(0.8), size: 22),
                ),
                IconButton(
                  onPressed: () {},
                  icon: Icon(Icons.person_outline_rounded,
                      color: _kSub, size: 22),
                ),
              ],
            ),
          ),
        ),
      ),
      toolbarHeight: 64 + top,
    );
  }

  // ── Hero ───────────────────────────────────────────────────────────────────

  Widget _buildHero(Song song) {
    return AnimatedBuilder(
      animation: _heroAnim,
      builder: (_, child) => Opacity(
        opacity: _heroAnim.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, 28 * (1 - _heroAnim.value)),
          child: child,
        ),
      ),
      child: GestureDetector(
        onTap: () => _playSong(song),
        child: Container(
          margin: const EdgeInsets.fromLTRB(14, 8, 14, 8),
          height: 250,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _kCyan.withOpacity(0.2)),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _ArtImg(url: song.artworkUrl, fit: BoxFit.cover),
              ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: _ArtImg(url: song.artworkUrl, fit: BoxFit.cover),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      _kBg.withOpacity(0.55),
                      _kBg.withOpacity(0.96),
                    ],
                    stops: const [0.0, 0.4, 1.0],
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-0.8, -0.6),
                    radius: 0.8,
                    colors: [_kCyan.withOpacity(0.08), Colors.transparent],
                  ),
                ),
              ),
              Positioned(
                bottom: 18,
                left: 18,
                right: 18,
                child: Row(
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: _kCyan.withOpacity(0.25),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: _ArtImg(url: song.artworkUrl),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: _kCyan.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                    color: _kCyan.withOpacity(0.4)),
                              ),
                              child: Text(
                                '# 1 TRENDING',
                                style: TextStyle(
                                  color: _kCyan,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                            if (song.audiusPlayCount != null) ...[
                              const SizedBox(width: 8),
                              Icon(Icons.play_arrow_rounded,
                                  color: _kSub, size: 13),
                              Text(song.formattedPlayCount,
                                  style:
                                      TextStyle(color: _kSub, fontSize: 10)),
                            ],
                          ]),
                          const SizedBox(height: 6),
                          Text(
                            song.title,
                            style: const TextStyle(
                              color: _kText,
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            song.artist,
                            style: TextStyle(color: _kSub, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (song.genre.isNotEmpty)
                            Text(song.genre,
                                style: TextStyle(
                                    color: _kCyanDim, fontSize: 10)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _kCyan,
                        boxShadow: [
                          BoxShadow(
                            color: _kCyan.withOpacity(0.35),
                            blurRadius: 18,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.play_arrow_rounded,
                          color: _kBg, size: 26),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 14,
                right: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Text(
                    song.durationFormatted,
                    style: TextStyle(color: _kText, fontSize: 10),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Search tap ─────────────────────────────────────────────────────────────

  Widget _buildSearchTap() {
    return GestureDetector(
      onTap: () => setState(() {
        _searchOpen = true;
        Future.delayed(
            const Duration(milliseconds: 50), _searchFocus.requestFocus);
      }),
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 6, 14, 0),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kBorder),
        ),
        child: Row(
          children: [
            Icon(Icons.search_rounded, color: _kSub, size: 19),
            const SizedBox(width: 12),
            Text('Search tracks, artists, genres…',
                style: TextStyle(color: _kSub, fontSize: 13)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: _kCyan.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: _kCyan.withOpacity(0.3)),
              ),
              child: Text(
                'FREE',
                style: TextStyle(
                  color: _kCyan,
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Horizontal songs ───────────────────────────────────────────────────────

  Widget _buildHorizontalSongs(List<Song> songs) {
    return SizedBox(
      height: 148,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        itemCount: songs.length,
        itemBuilder: (_, i) {
          final s = songs[i];
          return GestureDetector(
            onTap: () => _playSong(s),
            child: Container(
              width: 106,
              margin: const EdgeInsets.only(right: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: _ArtImg(url: s.artworkUrl, size: 106),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    s.title,
                    style: const TextStyle(
                        color: _kText,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    s.artist,
                    style: TextStyle(color: _kSub, fontSize: 10),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Playlist shelf ─────────────────────────────────────────────────────────

  Widget _buildPlaylistShelf() {
    return SizedBox(
      height: 168,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        itemCount: _playlists.length,
        itemBuilder: (_, i) {
          final pl = _playlists[i];
          return GestureDetector(
            onTap: () async {
              final tracks = await _audius.getPlaylistTracks(pl.id);
              if (tracks.isNotEmpty && mounted) _playSong(tracks.first);
            },
            child: Container(
              width: 130,
              margin: const EdgeInsets.only(right: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: _ArtImg(url: pl.artworkUrl, size: 130),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(10)),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              _kBg.withOpacity(0.9),
                            ],
                          ),
                        ),
                        child: Row(children: [
                          Icon(Icons.queue_music_rounded,
                              color: _kCyan, size: 10),
                          const SizedBox(width: 3),
                          Text(
                            '${pl.trackCount} tracks',
                            style: TextStyle(
                              color: _kCyan,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  Text(
                    pl.name,
                    style: const TextStyle(
                        color: _kText,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    pl.curator,
                    style: TextStyle(color: _kSub, fontSize: 10),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _skeletonRow(double h, double w) => SizedBox(
        height: h,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          itemCount: 5,
          itemBuilder: (_, __) => Container(
            width: w,
            height: h - 16,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
                color: _kCard,
                borderRadius: BorderRadius.circular(10)),
          ),
        ),
      );

  // ── Tabs ───────────────────────────────────────────────────────────────────

  Widget _buildTabs() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _tab('Weekly', 0),
        const SizedBox(width: 4),
        _tab('Underground', 1),
      ],
    );
  }

  Widget _tab(String label, int idx) {
    final active = _trendingTab == idx;
    return GestureDetector(
      onTap: () => setState(() => _trendingTab = idx),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? _kCyan.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: active ? _kCyan.withOpacity(0.5) : _kBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? _kCyan : _kSub,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  // ── Genre chips ────────────────────────────────────────────────────────────

  Widget _buildGenreChips() {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        itemCount: _genres.length,
        itemBuilder: (_, i) {
          final g      = _genres[i];
          final active = _selectedGenre == g;
          return GestureDetector(
            onTap: () => setState(() => _selectedGenre = g),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
              decoration: BoxDecoration(
                color: active ? _kCyan : _kCard,
                borderRadius: BorderRadius.circular(20),
                border:
                    Border.all(color: active ? _kCyan : _kBorder),
              ),
              child: Center(
                child: Text(
                  g,
                  style: TextStyle(
                    color: active ? _kBg : _kSub,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Section title sliver ───────────────────────────────────────────────────

  Widget _sliverTitle(String title, IconData icon, {Widget? trailing}) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 26, 16, 10),
        child: Row(
          children: [
            Icon(icon, color: _kCyan, size: 15),
            const SizedBox(width: 8),
            Text(
              title.toUpperCase(),
              style: const TextStyle(
                color: _kText,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
              ),
            ),
            const Spacer(),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  // ── Track row ──────────────────────────────────────────────────────────────

  Widget _trackRow(Song song, {bool showRank = false, int rank = 0}) {
    final isCurrentlyPlaying =
        _nowPlaying?.audiusTrackId == song.audiusTrackId;

    return GestureDetector(
      onTap: () => _playSong(song),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 5),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isCurrentlyPlaying
              ? _kCyan.withOpacity(0.07)
              : _kCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isCurrentlyPlaying
                ? _kCyan.withOpacity(0.35)
                : _kBorder.withOpacity(0.5),
          ),
        ),
        child: Row(
          children: [
            // Rank number
            if (showRank)
              SizedBox(
                width: 28,
                child: Text(
                  rank.toString().padLeft(2, '0'),
                  style: TextStyle(
                    color: rank == 1
                        ? _kCyan
                        : (rank <= 3
                            ? _kCyan.withOpacity(0.6)
                            : _kSub),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            // Artwork
            Stack(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _ArtImg(url: song.artworkUrl, size: 50),
              ),
              if (isCurrentlyPlaying && _isPlaying)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(child: _PulsingBars()),
                  ),
                ),
            ]),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    style: TextStyle(
                      color: isCurrentlyPlaying ? _kCyan : _kText,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    song.artist,
                    style: TextStyle(color: _kSub, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(children: [
                    Text(song.durationFormatted,
                        style: TextStyle(color: _kSub, fontSize: 10)),
                    if (song.genre.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text('·',
                          style:
                              TextStyle(color: _kSub, fontSize: 10)),
                      const SizedBox(width: 6),
                      Text(song.genre,
                          style:
                              TextStyle(color: _kSub, fontSize: 10)),
                    ],
                    if (song.audiusPlayCount != null) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.play_arrow_rounded,
                          size: 11, color: _kSub),
                      Text(song.formattedPlayCount,
                          style:
                              TextStyle(color: _kSub, fontSize: 10)),
                    ],
                  ]),
                ],
              ),
            ),
            // YouTube stream badge icon
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Icon(
                Icons.smart_display_rounded,
                color: _kSub.withOpacity(0.45),
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Search view ────────────────────────────────────────────────────────────

  Widget _buildSearchView() {
    return Column(
      children: [
        ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              color: _kBg.withOpacity(0.94),
              padding: EdgeInsets.fromLTRB(
                14,
                MediaQuery.of(context).padding.top + 12,
                14,
                12,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: _kCard,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: _kCyan.withOpacity(0.4)),
                      ),
                      child: TextField(
                        controller: _searchCtrl,
                        focusNode: _searchFocus,
                        style: const TextStyle(
                            color: _kText, fontSize: 14),
                        cursorColor: _kCyan,
                        decoration: InputDecoration(
                          hintText: 'Search Audius…',
                          hintStyle:
                              TextStyle(color: _kSub, fontSize: 14),
                          prefixIcon: Icon(Icons.search_rounded,
                              color: _kCyan, size: 20),
                          suffixIcon: _searchCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.close,
                                      color: _kSub, size: 18),
                                  onPressed: () => setState(() {
                                    _searchCtrl.clear();
                                    _searchResults = [];
                                  }),
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 13),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => setState(() {
                      _searchOpen = false;
                      _searchCtrl.clear();
                      _searchResults = [];
                      _searchFocus.unfocus();
                    }),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: _kCyan,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(child: _buildSearchResults()),
      ],
    );
  }

  Widget _buildSearchResults() {
    if (_searchLoading) {
      return Center(
          child: CircularProgressIndicator(
              color: _kCyan, strokeWidth: 1.5));
    }
    if (_searchError != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.wifi_off_rounded, size: 48, color: _kSub),
          const SizedBox(height: 12),
          Text('Could not reach Audius',
              style: TextStyle(color: _kText)),
        ]),
      );
    }
    if (_searchCtrl.text.trim().isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.search_rounded,
              size: 60, color: _kSub.withOpacity(0.25)),
          const SizedBox(height: 12),
          Text('Discover independent music',
              style: TextStyle(color: _kSub)),
        ]),
      );
    }
    if (_searchResults.isEmpty) {
      return Center(
          child: Text('No results', style: TextStyle(color: _kSub)));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: _searchResults.length,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: _trackRow(_searchResults[i]),
      ),
    );
  }

  // ── Mini player ────────────────────────────────────────────────────────────

  Widget _buildMiniPlayer() {
    final song = _nowPlaying!;
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => PlayScreen(song: song),
          transitionsBuilder: (_, anim, __, child) => SlideTransition(
            position: Tween(begin: const Offset(0, 1), end: Offset.zero)
                .animate(CurvedAnimation(
                    parent: anim, curve: Curves.easeOutCubic)),
            child: child,
          ),
          transitionDuration: const Duration(milliseconds: 420),
        ),
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _kCard.withOpacity(0.92),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _kCyan.withOpacity(0.3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.45),
                  blurRadius: 28,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                // Accent bar
                Container(
                  width: 3,
                  height: 40,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: _kCyan,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(
                          color: _kCyan.withOpacity(0.5),
                          blurRadius: 8),
                    ],
                  ),
                ),
                // Artwork
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _ArtImg(url: song.artworkUrl, size: 42),
                ),
                const SizedBox(width: 12),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        song.title,
                        style: const TextStyle(
                          color: _kText,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        song.artist,
                        style: TextStyle(color: _kSub, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Play / pause
                StreamBuilder<GizaPlayerState>(
                  stream: _audio.playerStateStream,
                  builder: (_, __) => IconButton(
                    icon: Icon(
                      _audio.isPlaying
                          ? Icons.pause_circle_rounded
                          : Icons.play_circle_rounded,
                      color: _kCyan,
                      size: 38,
                    ),
                    onPressed: () {
                      _audio.togglePlayPause();
                      if (mounted) {
                        setState(() => _isPlaying = _audio.isPlaying);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Shared widgets ───────────────────────────────────────────────────────────

class _FadeSlide extends StatelessWidget {
  final int                index;
  final AnimationController ctrl;
  final Widget             child;

  const _FadeSlide(
      {required this.index, required this.ctrl, required this.child});

  @override
  Widget build(BuildContext context) {
    final start = (index * 0.07).clamp(0.0, 0.65);
    final end   = (start + 0.3).clamp(0.0, 1.0);
    final anim  = CurvedAnimation(
      parent: ctrl,
      curve: Interval(start, end, curve: Curves.easeOut),
    );
    return AnimatedBuilder(
      animation: anim,
      builder: (_, c) => Opacity(
        opacity: anim.value,
        child: Transform.translate(
            offset: Offset(0, 14 * (1 - anim.value)), child: c),
      ),
      child: child,
    );
  }
}

class _PulsingBars extends StatefulWidget {
  @override
  State<_PulsingBars> createState() => _PulsingBarsState();
}

class _PulsingBarsState extends State<_PulsingBars>
    with TickerProviderStateMixin {
  late List<AnimationController> _ctrls;

  @override
  void initState() {
    super.initState();
    _ctrls = List.generate(3, (i) {
      return AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 400 + i * 100),
      )..repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    for (final c in _ctrls) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _ctrls[i],
          builder: (_, __) => Container(
            width: 3,
            height: 8 + _ctrls[i].value * 10,
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            decoration: BoxDecoration(
              color: _kCyan,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}

class _ArtImg extends StatelessWidget {
  final String  url;
  final double? size;
  final BoxFit  fit;

  const _ArtImg({required this.url, this.size, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return _placeholder();
    return CachedNetworkImage(
      imageUrl: url,
      width: size,
      height: size,
      fit: fit,
      placeholder: (_, __) => _placeholder(),
      errorWidget: (_, __, ___) => _placeholder(),
    );
  }

  Widget _placeholder() => Container(
        width: size,
        height: size,
        color: _kCard,
        child: Center(
          child: Icon(
            Icons.music_note_rounded,
            color: _kBorder,
            size: (size ?? 40) * 0.38,
          ),
        ),
      );
}

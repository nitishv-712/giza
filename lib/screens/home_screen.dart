// lib/screens/home_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/song.dart';
import '../services/audio_service.dart';
import '../services/youtube_service.dart';
import '../db/hive_helper.dart';
import '../providers/audio_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/playlist_provider.dart';
import 'play_screen.dart';
import 'playlists_screen.dart';
import 'settings_screen.dart';

// No top-level color consts — all colors are read from Theme.of(context)
// so the screen reacts correctly to light / dark / custom themes.

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final _audioService   = AudioService.instance;
  final _youtubeService = YoutubeService.instance;
  final _db             = HiveHelper.instance;

  late TabController _tabController;
  final _searchController = TextEditingController();
  Timer? _searchDebounce;

  List<Song> _searchResults  = [];
  List<Song> _trendingTracks = [];
  List<Song> _savedSongs     = [];
  List<Song> _favourites     = [];
  List<Song> _recentlyPlayed = [];

  bool _isSearching     = false;
  bool _loadingTrending = false;
  bool _loadingSaved    = false;

  final Set<String> _downloading = {};

  // ── Theme shorthand helpers ────────────────────────────────────────────────

  ColorScheme _cs(BuildContext ctx) => Theme.of(ctx).colorScheme;
  Color _surf(BuildContext ctx)     => _cs(ctx).surface;
  Color _surf2(BuildContext ctx)    => _cs(ctx).surfaceContainerHighest;
  Color _accent(BuildContext ctx)   => _cs(ctx).primary;
  Color _accent2(BuildContext ctx)  => _cs(ctx).secondary;
  Color _textPri(BuildContext ctx)  => _cs(ctx).onSurface;
  Color _textSec(BuildContext ctx)  => _cs(ctx).onSurface.withOpacity(0.55);
  Color _border(BuildContext ctx)   => _cs(ctx).outline;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loadingTrending = true);
    try {
      final trending = await _youtubeService.getTrendingTracks(limit: 25);
      if (mounted) setState(() => _trendingTracks = trending);
    } catch (e) {
      if (mounted) _showSnack('Failed to load trending: $e');
    } finally {
      if (mounted) setState(() => _loadingTrending = false);
    }
    _loadSavedData();
  }

  void _loadSavedData() {
    setState(() => _loadingSaved = true);
    try {
      _savedSongs     = _db.getAllSavedSongs();
      _favourites     = _db.getFavourites();
      _recentlyPlayed = _db.getRecentlyPlayed(limit: 20);
    } finally {
      setState(() => _loadingSaved = false);
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() { _searchResults = []; _isSearching = false; });
      return;
    }
    setState(() => _isSearching = true);
    try {
      final results = await _youtubeService.searchTracks(query, limit: 30);
      if (mounted) setState(() => _searchResults = results);
    } catch (e) {
      if (mounted) _showSnack('Search failed: $e');
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _handlePlay(Song song, List<Song> playlist) async {
    final audioProvider = context.read<AudioProvider>();
    _audioService.setPlaylist(playlist);
    if (mounted) {
      Navigator.push(context,
        MaterialPageRoute(builder: (_) => const PlayScreen()),
      ).then((_) => _loadSavedData());
    }
    try {
      await audioProvider.play(song);
    } catch (e) {
      if (mounted) _showSnack('Playback error: $e');
    }
  }

  Future<void> _downloadSong(Song song) async {
    final id = song.youtubeVideoId;
    if (id == null) return;
    final existing = _db.getSongByVideoId(id);
    if (existing != null && existing.isDownloaded) {
      _showSnack('Already downloaded', duration: const Duration(seconds: 1));
      return;
    }
    setState(() => _downloading.add(id));
    _audioService.downloadOnly(
      song,
      onDone: (saved) {
        if (mounted) {
          setState(() => _downloading.remove(id));
          _loadSavedData();
          _showSnack('"${saved.title}" downloaded',
              duration: const Duration(seconds: 2));
        }
      },
      onError: (e) {
        if (mounted) {
          setState(() => _downloading.remove(id));
          _showSnack('Download failed: $e');
        }
      },
    );
  }

  Future<void> _toggleFavourite(Song song) async {
    final newValue = !song.isFavourite;
    await _db.saveSong(song.copyWith(isFavourite: newValue));
    await _db.toggleFavourite(song, newValue);
    _loadSavedData();
  }

  Future<void> _deleteSong(Song song) async {
    await _db.deleteSong(song);
    _loadSavedData();
    if (mounted) _showSnack('Song removed');
  }

  void _showSnack(String msg,
      {Duration duration = const Duration(seconds: 2)}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg,
            style: TextStyle(
                color: _textPri(context), fontSize: 13)),
        backgroundColor: _surf2(context),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        duration: duration,
      ),
    );
  }

  Future<void> _showAddToPlaylist(Song song) async {
    final playlistProvider = context.read<PlaylistProvider>();
    final playlists = playlistProvider.playlists;
    if (playlists.isEmpty) {
      _showSnack('Create a playlist first');
      return;
    }
    final videoId = song.youtubeVideoId;
    if (videoId == null) return;

    await showModalBottomSheet(
      context: context,
      backgroundColor: _surf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final accent  = _accent(context);
        final accent2 = _accent2(context);
        final textPri = _textPri(context);
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add to Playlist',
                style: TextStyle(
                  color: textPri,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              ...playlists.map((playlist) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                            colors: [accent, accent2]),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.playlist_play_rounded,
                          color: Colors.white, size: 20),
                    ),
                    title: Text(playlist.name,
                        style:
                            TextStyle(color: textPri, fontSize: 14)),
                    onTap: () async {
                      await playlistProvider.addSongToPlaylist(
                          playlist.id, videoId, song);
                      if (mounted) {
                        Navigator.pop(ctx);
                        _showSnack('Added to ${playlist.name}');
                      }
                    },
                  )),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchBar(),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildDiscoverTab(),
                  _buildLibraryTab(),
                  _buildFavouritesTab(),
                  _buildRecentTab(),
                ],
              ),
            ),
            _buildMiniPlayer(),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_accent(context), _accent2(context)],
              ),
              boxShadow: [
                BoxShadow(
                  color: _accent(context).withOpacity(0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.music_note_rounded,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Text(
            'Giza',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: _textPri(context),
              letterSpacing: -0.8,
            ),
          ),
          const Spacer(),
          _HeaderIconBtn(
            icon: Icons.playlist_play_rounded,
            isLoading: false,
            onPressed: () => Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => const PlaylistsScreen()))
                .then((_) => _loadSavedData()),
          ),
          const SizedBox(width: 8),
          _HeaderIconBtn(
            icon: Icons.settings_rounded,
            isLoading: false,
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
          const SizedBox(width: 8),
          Consumer<AuthProvider>(
            builder: (context, authProvider, _) => _HeaderIconBtn(
              icon: Icons.logout_rounded,
              isLoading: authProvider.isLoading,
              onPressed: authProvider.isLoading
                  ? null
                  : authProvider.signOut,
            ),
          ),
        ],
      ),
    );
  }

  // ── Search bar ─────────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: _surf(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border(context), width: 0.5),
        ),
        child: TextField(
          controller: _searchController,
          onSubmitted: _performSearch,
          onChanged: (value) {
            setState(() {});
            _searchDebounce?.cancel();
            _searchDebounce = Timer(const Duration(milliseconds: 500),
                () => _performSearch(value));
          },
          style: TextStyle(color: _textPri(context), fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Search tracks, artists…',
            hintStyle: TextStyle(color: _textSec(context), fontSize: 14),
            prefixIcon: Icon(Icons.search_rounded,
                color: _accent(context), size: 20),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.cancel_rounded,
                        color: _textSec(context), size: 18),
                    onPressed: () {
                      _searchController.clear();
                      _performSearch('');
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          ),
        ),
      ),
    );
  }

  // ── Tab bar ────────────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    final accent  = _accent(context);
    final textSec = _textSec(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: TabBar(
        controller: _tabController,
        splashFactory: NoSplash.splashFactory,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        splashBorderRadius: BorderRadius.circular(20),
        isScrollable: true,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        tabAlignment: TabAlignment.start,
        indicator: BoxDecoration(
          color: accent.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent.withOpacity(0.4), width: 1),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: accent,
        unselectedLabelColor: textSec,
        labelStyle: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: -0.2),
        unselectedLabelStyle:
            const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        tabs: const [
          Tab(text: 'Discover'),
          Tab(text: 'Library'),
          Tab(text: 'Favourites'),
          Tab(text: 'Recent'),
        ],
      ),
    );
  }

  // ── Tab content ────────────────────────────────────────────────────────────

  Widget _buildDiscoverTab() => _buildSongList(
        songs: _searchController.text.isNotEmpty
            ? _searchResults
            : _trendingTracks,
        loading: _searchController.text.isNotEmpty
            ? _isSearching
            : _loadingTrending,
        emptyMessage: _searchController.text.isNotEmpty
            ? 'No results found'
            : 'No trending tracks',
        sectionTitle:
            _searchController.text.isEmpty ? 'Trending Now 🔥' : null,
      );

  Widget _buildLibraryTab() => _buildSongList(
      songs: _savedSongs,
      loading: _loadingSaved,
      emptyMessage: 'No saved songs',
      showActions: true);

  Widget _buildFavouritesTab() => _buildSongList(
      songs: _favourites,
      loading: false,
      emptyMessage: 'No favourites',
      showActions: true);

  Widget _buildRecentTab() => _buildSongList(
      songs: _recentlyPlayed,
      loading: false,
      emptyMessage: 'No history');

  Widget _buildSongList({
    required List<Song> songs,
    required bool loading,
    required String emptyMessage,
    String? sectionTitle,
    bool showActions = false,
  }) {
    if (loading) {
      return Center(
          child: CircularProgressIndicator(
              color: _accent(context), strokeWidth: 2));
    }
    if (songs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.music_off_rounded,
                size: 56, color: _textSec(context).withOpacity(0.4)),
            const SizedBox(height: 14),
            Text(emptyMessage,
                style: TextStyle(
                    color: _textSec(context),
                    fontSize: 15,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      itemCount: songs.length + (sectionTitle != null ? 1 : 0),
      addAutomaticKeepAlives: true,
      cacheExtent: 500,
      itemBuilder: (context, index) {
        if (sectionTitle != null && index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 14, top: 4),
            child: Text(
              sectionTitle,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _textPri(context),
                letterSpacing: -0.5,
              ),
            ),
          );
        }
        final song = songs[sectionTitle != null ? index - 1 : index];
        return _buildSongTile(song, songs, showActions: showActions);
      },
    );
  }

  Widget _buildSongTile(Song song, List<Song> currentList,
      {bool showActions = false}) {
    final videoId      = song.youtubeVideoId ?? '';
    final isDownloaded = song.isDownloaded ||
        (_db.getSongByVideoId(videoId)?.isDownloaded ?? false);
    final isDownloading = _downloading.contains(videoId);

    return _SongTile(
      song: song,
      currentList: currentList,
      showActions: showActions,
      isDownloaded: isDownloaded,
      isDownloading: isDownloading,
      onPlay: () => _handlePlay(song, currentList),
      onToggleFavourite: () => _toggleFavourite(song),
      onDelete: () => _deleteSong(song),
      onAddToPlaylist: () => _showAddToPlaylist(song),
      onDownload: () => _downloadSong(song),
    );
  }

// ── Mini player ────────────────────────────────────────────────────────────

  Widget _buildMiniPlayer() {
    return Consumer<AudioProvider>(
      builder: (context, audioProvider, child) {
        final song = audioProvider.currentSong;
        if (song == null) return const SizedBox.shrink();
        return child!;
      },
      child: _MiniPlayerContent(),
    );
  }
}

// ── Helper widgets ─────────────────────────────────────────────────────────

class _MiniPlayerContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final audioProvider = context.watch<AudioProvider>();
    final song = audioProvider.currentSong;
    if (song == null) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    final accent = cs.primary;
    final accent2 = cs.secondary;
    final textPri = cs.onSurface;
    final textSec = cs.onSurface.withOpacity(0.55);
    final surf2 = cs.surfaceContainerHighest;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final playerBg = isDark ? const Color(0xFF1E1520) : accent.withOpacity(0.06);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PlayScreen()),
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 4, 12, 10),
        height: 68,
        decoration: BoxDecoration(
          color: playerBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accent.withOpacity(0.25), width: 1),
          boxShadow: [
            BoxShadow(
              color: accent.withOpacity(0.12),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(17),
                bottomLeft: Radius.circular(17),
              ),
              child: Image.network(
                song.artworkUrl,
                width: 68,
                height: 68,
                fit: BoxFit.cover,
                cacheWidth: 136,
                cacheHeight: 136,
                errorBuilder: (_, __, ___) => Container(
                  width: 68,
                  height: 68,
                  color: surf2,
                  child: Icon(Icons.music_note_rounded, color: accent, size: 28),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    style: TextStyle(
                      color: textPri,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    song.artist,
                    style: TextStyle(color: textSec, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              width: 40,
              height: 40,
              margin: const EdgeInsets.only(right: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [accent, accent2]),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: accent.withOpacity(0.35),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: Icon(
                  audioProvider.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  size: 22,
                ),
                color: Colors.white,
                onPressed: audioProvider.togglePlayPause,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderIconBtn extends StatelessWidget {
  final IconData icon;
  final bool isLoading;
  final VoidCallback? onPressed;

  const _HeaderIconBtn({
    required this.icon,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 38, height: 38,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline, width: 0.5),
      ),
      child: isLoading
          ? Padding(
              padding: const EdgeInsets.all(10),
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: cs.primary),
            )
          : IconButton(
              padding: EdgeInsets.zero,
              icon: Icon(icon, size: 18,
                  color: cs.onSurface.withOpacity(0.55)),
              onPressed: onPressed,
            ),
    );
  }
}

class _TileIconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  const _TileIconBtn({
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 20, color: color),
      ),
    );
  }
}

class _SongTile extends StatelessWidget {
  final Song song;
  final List<Song> currentList;
  final bool showActions;
  final bool isDownloaded;
  final bool isDownloading;
  final VoidCallback onPlay;
  final VoidCallback onToggleFavourite;
  final VoidCallback onDelete;
  final VoidCallback onAddToPlaylist;
  final VoidCallback onDownload;

  const _SongTile({
    required this.song,
    required this.currentList,
    required this.showActions,
    required this.isDownloaded,
    required this.isDownloading,
    required this.onPlay,
    required this.onToggleFavourite,
    required this.onDelete,
    required this.onAddToPlaylist,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = cs.primary;
    final accent2 = cs.secondary;
    final textPri = cs.onSurface;
    final textSec = cs.onSurface.withOpacity(0.55);
    final surf = cs.surface;
    final surf2 = cs.surfaceContainerHighest;
    final border = cs.outline;

    return GestureDetector(
      onTap: onPlay,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: surf,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border, width: 0.5),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                song.artworkUrl,
                width: 52,
                height: 52,
                fit: BoxFit.cover,
                cacheWidth: 104,
                cacheHeight: 104,
                errorBuilder: (_, __, ___) => Container(
                  width: 52,
                  height: 52,
                  color: surf2,
                  child: Icon(Icons.music_note_rounded, color: accent, size: 24),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    style: TextStyle(
                      color: textPri,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    song.artist,
                    style: TextStyle(
                      color: textSec,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (showActions) ...[
              _TileIconBtn(
                icon: song.isFavourite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: song.isFavourite ? accent2 : textSec,
                onPressed: onToggleFavourite,
              ),
              _TileIconBtn(
                icon: Icons.delete_outline_rounded,
                color: textSec,
                onPressed: onDelete,
              ),
            ] else ...[
              _TileIconBtn(
                icon: Icons.playlist_add_rounded,
                color: textSec,
                onPressed: onAddToPlaylist,
              ),
              Text(
                song.durationFormatted,
                style: TextStyle(
                  color: textSec,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 4),
              if (song.youtubeVideoId?.isNotEmpty ?? false)
                isDownloading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: accent,
                        ),
                      )
                    : _TileIconBtn(
                        icon: isDownloaded
                            ? Icons.download_done_rounded
                            : Icons.download_outlined,
                        color: isDownloaded ? accent : textSec,
                        onPressed: isDownloaded ? null : onDownload,
                      ),
            ],
          ],
        ),
      ),
    );
  }
}
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

// ── Color tokens ────────────────────────────────────────────────────────────
const _bg        = Color(0xFF0C0C14);
const _surface   = Color(0xFF141420);
const _surface2  = Color(0xFF1C1C2A);
const _accent    = Color(0xFFFF8C42);
const _accent2   = Color(0xFFFF5F6D);
const _textPri   = Color(0xFFF0EFFF);
const _textSec   = Color(0xFF6E6E8A);

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
      if (mounted) {
        _showSnack('Failed to load trending: $e');
      }
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

  void _showSnack(String msg, {Duration duration = const Duration(seconds: 2)}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg,
            style: const TextStyle(color: _textPri, fontSize: 13)),
        backgroundColor: _surface2,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add to Playlist',
              style: TextStyle(
                color: _textPri,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            ...playlists.map((playlist) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_accent, _accent2],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.playlist_play_rounded,
                        color: Colors.white, size: 20),
                  ),
                  title: Text(
                    playlist.name,
                    style: const TextStyle(color: _textPri, fontSize: 14),
                  ),
                  onTap: () async {
                    await playlistProvider.addSongToPlaylist(
                        playlist.id, videoId, song);
                    if (mounted) {
                      Navigator.pop(context);
                      _showSnack('Added to ${playlist.name}');
                    }
                  },
                )),
          ],
        ),
      ),
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
      backgroundColor: _bg,
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
          // Logo
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_accent, _accent2],
              ),
              boxShadow: [
                BoxShadow(
                  color: _accent.withOpacity(0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.music_note_rounded,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          const Text(
            'Giza',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: _textPri,
              letterSpacing: -0.8,
            ),
          ),
          const Spacer(),
          _HeaderIconBtn(
            icon: Icons.playlist_play_rounded,
            isLoading: false,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PlaylistsScreen()),
            ).then((_) => _loadSavedData()),
          ),
          const SizedBox(width: 8),
          _HeaderIconBtn(
            icon: Icons.settings_rounded,
            isLoading: false,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          const SizedBox(width: 8),
          Consumer<AuthProvider>(
            builder: (context, authProvider, _) {
              return _HeaderIconBtn(
                icon: Icons.logout_rounded,
                isLoading: authProvider.isLoading,
                onPressed: authProvider.isLoading
                    ? null
                    : () => authProvider.signOut(),
              );
            },
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
          color: _surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF2A2A3E), width: 1),
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
          style: const TextStyle(color: _textPri, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Search tracks, artists…',
            hintStyle: const TextStyle(color: _textSec, fontSize: 14),
            prefixIcon: const Icon(Icons.search_rounded,
                color: _accent, size: 20),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.cancel_rounded,
                        color: _textSec, size: 18),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        tabAlignment: TabAlignment.start,
        indicator: BoxDecoration(
          color: _accent.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _accent.withOpacity(0.4), width: 1),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: _accent,
        unselectedLabelColor: _textSec,
        labelStyle: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: -0.2),
        unselectedLabelStyle: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w500),
        tabs: const [
          Tab(text: 'Discover'),
          Tab(text: 'Library'),
          Tab(text: 'Favourites'),
          Tab(text: 'Recent'),
        ],
      ),
    );
  }

  // ── Tab content helpers ────────────────────────────────────────────────────

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
    showActions: true,
  );

  Widget _buildFavouritesTab() => _buildSongList(
    songs: _favourites,
    loading: false,
    emptyMessage: 'No favourites',
    showActions: true,
  );

  Widget _buildRecentTab() => _buildSongList(
    songs: _recentlyPlayed,
    loading: false,
    emptyMessage: 'No history',
  );

  Widget _buildSongList({
    required List<Song> songs,
    required bool loading,
    required String emptyMessage,
    String? sectionTitle,
    bool showActions = false,
  }) {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(
            color: _accent, strokeWidth: 2),
      );
    }
    if (songs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.music_off_rounded,
                size: 56, color: _textSec.withOpacity(0.4)),
            const SizedBox(height: 14),
            Text(emptyMessage,
                style: const TextStyle(
                    color: _textSec, fontSize: 15,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      itemCount: songs.length + (sectionTitle != null ? 1 : 0),
      itemBuilder: (context, index) {
        if (sectionTitle != null && index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 14, top: 4),
            child: Text(
              sectionTitle,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _textPri,
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
    final videoId   = song.youtubeVideoId ?? '';
    final isDownloaded = song.isDownloaded ||
        (_db.getSongByVideoId(videoId)?.isDownloaded ?? false);
    final isDownloading = _downloading.contains(videoId);

    return GestureDetector(
      onTap: () => _handlePlay(song, currentList),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF22223A), width: 1),
        ),
        child: Row(
          children: [
            // Artwork
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                song.artworkUrl,
                width: 52, height: 52,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 52, height: 52,
                  color: _surface2,
                  child: const Icon(Icons.music_note_rounded,
                      color: _accent, size: 24),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Title + artist
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    style: const TextStyle(
                      color: _textPri,
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
                    style: const TextStyle(
                        color: _textSec, fontSize: 12,
                        fontWeight: FontWeight.w400),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Actions
            if (showActions) ...[
              _TileIconBtn(
                icon: song.isFavourite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: song.isFavourite ? _accent2 : _textSec,
                onPressed: () => _toggleFavourite(song),
              ),
              _TileIconBtn(
                icon: Icons.delete_outline_rounded,
                color: _textSec,
                onPressed: () => _deleteSong(song),
              ),
            ] else ...[
              _TileIconBtn(
                icon: Icons.playlist_add_rounded,
                color: _textSec,
                onPressed: () => _showAddToPlaylist(song),
              ),
              Text(
                song.durationFormatted,
                style: const TextStyle(
                    color: _textSec, fontSize: 12,
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 4),
              _buildDownloadButton(
                videoId: videoId,
                song: song,
                isDownloaded: isDownloaded,
                isDownloading: isDownloading,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadButton({
    required String videoId,
    required Song song,
    required bool isDownloaded,
    required bool isDownloading,
  }) {
    if (videoId.isEmpty) return const SizedBox.shrink();
    if (isDownloading) {
      return const SizedBox(
        width: 20, height: 20,
        child: CircularProgressIndicator(
            strokeWidth: 2, color: _accent),
      );
    }
    return _TileIconBtn(
      icon: isDownloaded
          ? Icons.download_done_rounded
          : Icons.download_outlined,
      color: isDownloaded ? _accent : _textSec,
      onPressed: isDownloaded ? null : () => _downloadSong(song),
    );
  }

  // ── Mini player ────────────────────────────────────────────────────────────

  Widget _buildMiniPlayer() {
    return Consumer<AudioProvider>(
      builder: (context, audioProvider, _) {
        final song = audioProvider.currentSong;
        if (song == null) return const SizedBox.shrink();

        return GestureDetector(
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const PlayScreen()))
              .then((_) => _loadSavedData()),
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 4, 12, 10),
            height: 68,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E1520), Color(0xFF1A1A2A)],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _accent.withOpacity(0.25), width: 1),
              boxShadow: [
                BoxShadow(
                  color: _accent.withOpacity(0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Artwork
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(17),
                    bottomLeft: Radius.circular(17),
                  ),
                  child: Image.network(
                    song.artworkUrl,
                    width: 68, height: 68,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 68, height: 68, color: _surface2,
                      child: const Icon(Icons.music_note_rounded,
                          color: _accent, size: 28),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Song info
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        style: const TextStyle(
                          color: _textPri,
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
                        style: const TextStyle(
                            color: _textSec, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Play/pause
                Container(
                  width: 40, height: 40,
                  margin: const EdgeInsets.only(right: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [_accent, _accent2]),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _accent.withOpacity(0.35),
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
      },
    );
  }
}

// ── Helper widgets ─────────────────────────────────────────────────────────

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
    return Container(
      width: 38, height: 38,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2A3E), width: 1),
      ),
      child: isLoading
          ? const Padding(
              padding: EdgeInsets.all(10),
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: _accent),
            )
          : IconButton(
              padding: EdgeInsets.zero,
              icon: Icon(icon, size: 18, color: _textSec),
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
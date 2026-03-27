// lib/screens/home_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';

import '../models/song.dart';
import '../services/audio_service.dart';
import '../services/youtube_service.dart';
import '../db/hive_helper.dart';
import 'play_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final _audioService = AudioService.instance;
  final _youtubeService = YoutubeService.instance;
  final _db = HiveHelper.instance;

  late TabController _tabController;
  final _searchController = TextEditingController();
  Timer? _searchDebounce;

  List<Song> _searchResults = [];
  List<Song> _trendingTracks = [];
  List<Song> _savedSongs = [];
  List<Song> _favourites = [];
  List<Song> _recentlyPlayed = [];

  bool _isSearching = false;
  bool _loadingTrending = false;
  bool _loadingSaved = false;

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load trending: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingTrending = false);
    }

    _loadSavedData();
  }

  void _loadSavedData() {
    setState(() => _loadingSaved = true);
    try {
      _savedSongs = _db.getAllSavedSongs();
      _favourites = _db.getFavourites();
      _recentlyPlayed = _db.getRecentlyPlayed(limit: 20);
    } finally {
      setState(() => _loadingSaved = false);
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    try {
      final results = await _youtubeService.searchTracks(query, limit: 30);
      if (mounted) setState(() => _searchResults = results);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _playSong(Song song) async {
    // Show loading dialog during download
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => _DownloadProgressDialog(song: song),
      );
    }

    try {
      await _audioService.play(song);
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PlayScreen()),
        ).then((_) => _loadSavedData());
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Playback error: $e')),
        );
      }
    }
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
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Song removed')),
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),

            // Search bar
            _buildSearchBar(),

            // Tabs
            _buildTabBar(),

            // Content
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

            // Mini player
            _buildMiniPlayer(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00E5FF), Color(0xFF0080FF)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.music_note, color: Colors.white),
          ),
          const SizedBox(width: 12),
          const Text(
            'Giza',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFFECECFF),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF18182A),
          borderRadius: BorderRadius.circular(12),
        ),
        child: TextField(
          controller: _searchController,
          onSubmitted: _performSearch,
          onChanged: (value) {
            setState(() {});
            _searchDebounce?.cancel();
            _searchDebounce = Timer(const Duration(milliseconds: 500), () => _performSearch(value));
          },
          style: const TextStyle(color: Color(0xFFECECFF)),
          decoration: InputDecoration(
            hintText: 'Search for songs, artists...',
            hintStyle: TextStyle(color: const Color(0xFFECECFF).withOpacity(0.5)),
            prefixIcon: const Icon(Icons.search, color: Color(0xFF00E5FF)),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Color(0xFFECECFF)),
                    onPressed: () {
                      _searchController.clear();
                      _performSearch('');
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),

        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicatorColor: const Color(0xFF00E5FF),
        labelColor: const Color(0xFF00E5FF),
        unselectedLabelColor: const Color(0xFFECECFF).withOpacity(0.6),
        tabs: const [
          Tab(text: 'Discover'),
          Tab(text: 'Library'),
          Tab(text: 'Favourites'),
          Tab(text: 'Recent'),
        ],
      ),
    );
  }

  Widget _buildDiscoverTab() {
    if (_searchController.text.isNotEmpty) {
      return _buildSongList(
        songs: _searchResults,
        loading: _isSearching,
        emptyMessage: 'No results found',
      );
    }

    return _buildSongList(
      songs: _trendingTracks,
      loading: _loadingTrending,
      emptyMessage: 'No trending tracks available',
      title: 'Trending Now',
    );
  }

  Widget _buildLibraryTab() {
    return _buildSongList(
      songs: _savedSongs,
      loading: _loadingSaved,
      emptyMessage: 'No saved songs yet',
      showActions: true,
    );
  }

  Widget _buildFavouritesTab() {
    return _buildSongList(
      songs: _favourites,
      loading: false,
      emptyMessage: 'No favourites yet',
      showActions: true,
    );
  }

  Widget _buildRecentTab() {
    return _buildSongList(
      songs: _recentlyPlayed,
      loading: false,
      emptyMessage: 'No recently played songs',
    );
  }

  Widget _buildSongList({
    required List<Song> songs,
    required bool loading,
    required String emptyMessage,
    String? title,
    bool showActions = false,
  }) {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
      );
    }

    if (songs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.music_off,
              size: 64,
              color: const Color(0xFFECECFF).withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: TextStyle(
                color: const Color(0xFFECECFF).withOpacity(0.6),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: songs.length + (title != null ? 1 : 0),
      itemBuilder: (context, index) {
        if (title != null && index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12, top: 8),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFFECECFF),
              ),
            ),
          );
        }

        final song = songs[title != null ? index - 1 : index];
        return _buildSongTile(song, showActions: showActions);
      },
    );
  }

  Widget _buildSongTile(Song song, {bool showActions = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF18182A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: () => _playSong(song),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            song.artworkUrl,
            width: 56,
            height: 56,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: 56,
              height: 56,
              color: const Color(0xFF080810),
              child: const Icon(Icons.music_note, color: Color(0xFF00E5FF)),
            ),
          ),
        ),
        title: Text(
          song.title,
          style: const TextStyle(
            color: Color(0xFFECECFF),
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          song.artist,
          style: TextStyle(
            color: const Color(0xFFECECFF).withOpacity(0.7),
            fontSize: 13,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: showActions
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      song.isFavourite ? Icons.favorite : Icons.favorite_border,
                      color: song.isFavourite ? Colors.red : const Color(0xFFECECFF),
                    ),
                    onPressed: () => _toggleFavourite(song),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Color(0xFFECECFF)),
                    onPressed: () => _deleteSong(song),
                  ),
                ],
              )
            : Text(
                song.durationFormatted,
                style: TextStyle(
                  color: const Color(0xFFECECFF).withOpacity(0.6),
                  fontSize: 13,
                ),
              ),
      ),
    );
  }

  Widget _buildMiniPlayer() {
    return StreamBuilder<Song?>(
      stream: Stream.periodic(const Duration(milliseconds: 100), (_) => _audioService.currentSong),
      initialData: _audioService.currentSong,
      builder: (context, snapshot) {
        final song = snapshot.data;
        if (song == null) return const SizedBox.shrink();

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PlayScreen()),
            ).then((_) => _loadSavedData());
          },
          child: Container(
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFF18182A),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Artwork
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(0),
                  ),
                  child: Image.network(
                    song.artworkUrl,
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 72,
                      height: 72,
                      color: const Color(0xFF080810),
                      child: const Icon(Icons.music_note, color: Color(0xFF00E5FF)),
                    ),
                  ),
                ),

                // Song info
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.title,
                          style: const TextStyle(
                            color: Color(0xFFECECFF),
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          song.artist,
                          style: TextStyle(
                            color: const Color(0xFFECECFF).withOpacity(0.7),
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),

                // Play/Pause button
                StreamBuilder<bool>(
                  stream: _audioService.playingStream,
                  initialData: _audioService.isPlaying,
                  builder: (context, snapshot) {
                    final playing = snapshot.data ?? false;
                    return IconButton(
                      icon: Icon(
                        playing ? Icons.pause : Icons.play_arrow,
                        color: const Color(0xFF00E5FF),
                        size: 32,
                      ),
                      onPressed: _audioService.togglePlayPause,
                    );
                  },
                ),

                const SizedBox(width: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Download Progress Dialog ───────────────────────────────────────────────

class _DownloadProgressDialog extends StatelessWidget {
  final Song song;

  const _DownloadProgressDialog({required this.song});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF18182A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Album art
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                song.artworkUrl,
                width: 120,
                height: 120,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 120,
                  height: 120,
                  color: const Color(0xFF080810),
                  child: const Icon(Icons.music_note, size: 60, color: Color(0xFF00E5FF)),
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Song info
            Text(
              song.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFFECECFF),
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            
            const SizedBox(height: 4),
            
            Text(
              song.artist,
              style: TextStyle(
                fontSize: 14,
                color: const Color(0xFFECECFF).withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            
            const SizedBox(height: 24),
            
            // Progress indicator and status
            StreamBuilder<GizaPlayerState>(
              stream: AudioService.instance.playerStateStream,
              builder: (context, snapshot) {
                final state = snapshot.data;
                final progress = state?.downloadProgress ?? 0.0;
                final status = state?.status ?? GizaPlayerStatus.idle;
                
                String statusText;
                switch (status) {
                  case GizaPlayerStatus.downloading:
                    statusText = 'Downloading... ${(progress * 100).toInt()}%';
                    break;
                  case GizaPlayerStatus.loading:
                    statusText = 'Loading...';
                    break;
                  case GizaPlayerStatus.playing:
                    statusText = 'Ready to play';
                    break;
                  default:
                    statusText = 'Preparing...';
                }
                
                return Column(
                  children: [
                    if (status == GizaPlayerStatus.downloading)
                      LinearProgressIndicator(
                        value: progress,
                        backgroundColor: const Color(0xFF080810),
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00E5FF)),
                      )
                    else
                      const LinearProgressIndicator(
                        backgroundColor: Color(0xFF080810),
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00E5FF)),
                      ),
                    
                    const SizedBox(height: 12),
                    
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 13,
                        color: const Color(0xFFECECFF).withOpacity(0.7),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
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

  // Video IDs currently being downloaded in the background
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  // ── Tap → Stream via Python backend ───────────────────────────────────────

  Future<void> _streamSong(Song song) async {
    // Show a slim loading dialog while Kotlin/Python buffers the stream
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _StreamLoadingDialog(song: song),
      );
    }

    try {
      await _audioService.stream(song);
      if (mounted) {
        Navigator.of(context).pop(); // close loading dialog
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PlayScreen()),
        ).then((_) => _loadSavedData());
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Stream error: $e')),
        );
      }
    }
  }

  Future<void> _play(Song song) async {
    try {
      await _audioService.play(song);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Playback error: $e')),
        );
      }
    }
  }
  // ── Download button → background permanent save ────────────────────────────

  Future<void> _downloadSong(Song song) async {
    final id = song.youtubeVideoId;
    if (id == null) return;

    final existing = _db.getSongByVideoId(id);
    if (existing != null && existing.isDownloaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Already downloaded'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    setState(() => _downloading.add(id));

    _audioService.downloadOnly(
      song,
      onDone: (saved) {
        if (mounted) {
          setState(() => _downloading.remove(id));
          _loadSavedData();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('"${saved.title}" downloaded'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
      onError: (e) {
        if (mounted) {
          setState(() => _downloading.remove(id));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Download failed: $e')),
          );
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

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            _searchDebounce = Timer(
              const Duration(milliseconds: 500),
              () => _performSearch(value),
            );
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
        play: false,
      );
    }
    return _buildSongList(
      songs: _trendingTracks,
      loading: _loadingTrending,
      emptyMessage: 'No trending tracks available',
      title: 'Trending Now',
      play: false,
    );
  }

  Widget _buildLibraryTab() => _buildSongList(
        songs: _savedSongs,
        loading: _loadingSaved,
        emptyMessage: 'No saved songs yet',
        showActions: true,
        play: true,
      );

  Widget _buildFavouritesTab() => _buildSongList(
        songs: _favourites,
        loading: false,
        emptyMessage: 'No favourites yet',
        showActions: true,
        play: false,
      );

  Widget _buildRecentTab() => _buildSongList(
        songs: _recentlyPlayed,
        loading: false,
        emptyMessage: 'No recently played songs',
        play: false,
      );

  Widget _buildSongList({
    required List<Song> songs,
    required bool loading,
    required String emptyMessage,
    required bool play,
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
            Icon(Icons.music_off, size: 64,
                color: const Color(0xFFECECFF).withOpacity(0.3)),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: TextStyle(
                  color: const Color(0xFFECECFF).withOpacity(0.6), fontSize: 16),
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
            child: Text(title,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFECECFF))),
          );
        }
        final song = songs[title != null ? index - 1 : index];
        return _buildSongTile(song, showActions: showActions, play: play);
      },
    );
  }

  // ── Song tile ──────────────────────────────────────────────────────────────

  Widget _buildSongTile(Song song, {bool showActions = false, bool play = false}) {
    final videoId       = song.youtubeVideoId ?? '';
    final isDownloaded  = song.isDownloaded ||
        (_db.getSongByVideoId(videoId)?.isDownloaded ?? false);
    final isDownloading = _downloading.contains(videoId);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF18182A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: () => play? _play(song) :_streamSong(song),   // tap always streams
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            song.artworkUrl,
            width: 56, height: 56, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: 56, height: 56,
              color: const Color(0xFF080810),
              child: const Icon(Icons.music_note, color: Color(0xFF00E5FF)),
            ),
          ),
        ),
        title: Text(song.title,
            style: const TextStyle(
                color: Color(0xFFECECFF), fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        subtitle: Text(song.artist,
            style: TextStyle(
                color: const Color(0xFFECECFF).withOpacity(0.7), fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
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
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    song.durationFormatted,
                    style: TextStyle(
                        color: const Color(0xFFECECFF).withOpacity(0.6),
                        fontSize: 13),
                  ),
                  const SizedBox(width: 4),
                  _buildDownloadButton(
                    videoId: videoId,
                    song: song,
                    isDownloaded: isDownloaded,
                    isDownloading: isDownloading,
                  ),
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
        width: 24, height: 24,
        child: CircularProgressIndicator(
            strokeWidth: 2, color: Color(0xFF00E5FF)),
      );
    }

    return IconButton(
      tooltip: isDownloaded ? 'Downloaded' : 'Download for offline',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      icon: Icon(
        isDownloaded ? Icons.download_done : Icons.download_outlined,
        size: 22,
        color: isDownloaded
            ? const Color(0xFF00E5FF)
            : const Color(0xFFECECFF).withOpacity(0.6),
      ),
      onPressed: isDownloaded ? null : () => _downloadSong(song),
    );
  }

  // ── Mini player ────────────────────────────────────────────────────────────

  Widget _buildMiniPlayer() {
    return StreamBuilder<Song?>(
      stream: Stream.periodic(
          const Duration(milliseconds: 100), (_) => _audioService.currentSong),
      initialData: _audioService.currentSong,
      builder: (context, snapshot) {
        final song = snapshot.data;
        if (song == null) return const SizedBox.shrink();

        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PlayScreen()),
          ).then((_) => _loadSavedData()),
          child: Container(
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFF18182A),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, -2)),
              ],
            ),
            child: Row(
              children: [
                // Artwork
                ClipRRect(
                  child: Image.network(
                    song.artworkUrl,
                    width: 72, height: 72, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 72, height: 72,
                      color: const Color(0xFF080810),
                      child: const Icon(Icons.music_note, color: Color(0xFF00E5FF)),
                    ),
                  ),
                ),

                // Song info + streaming badge
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(song.title,
                            style: const TextStyle(
                                color: Color(0xFFECECFF),
                                fontWeight: FontWeight.w600,
                                fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 3),
                        if (_audioService.isStreaming)
                          Row(
                            children: [
                              Icon(Icons.wifi, size: 11,
                                  color: const Color(0xFF00E5FF).withOpacity(0.8)),
                              const SizedBox(width: 3),
                              Text('Streaming',
                                  style: TextStyle(
                                      color: const Color(0xFF00E5FF).withOpacity(0.8),
                                      fontSize: 11)),
                            ],
                          )
                        else
                          Text(song.artist,
                              style: TextStyle(
                                  color: const Color(0xFFECECFF).withOpacity(0.7),
                                  fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ),

                // Play / Pause
                StreamBuilder<bool>(
                  stream: _audioService.playingStream,
                  initialData: _audioService.isPlaying,
                  builder: (context, snap) {
                    final playing = snap.data ?? false;
                    return IconButton(
                      icon: Icon(
                          playing ? Icons.pause : Icons.play_arrow,
                          color: const Color(0xFF00E5FF), size: 32),
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

// ── Stream loading dialog ──────────────────────────────────────────────────────
// Shown while Kotlin/Python buffers the audio stream into a temp file.

class _StreamLoadingDialog extends StatelessWidget {
  final Song song;
  const _StreamLoadingDialog({required this.song});

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
            // Artwork
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                song.artworkUrl,
                width: 100, height: 100, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 100, height: 100,
                  color: const Color(0xFF080810),
                  child: const Icon(Icons.music_note, size: 48,
                      color: Color(0xFF00E5FF)),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Text(song.title,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFECECFF)),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(song.artist,
                style: TextStyle(
                    fontSize: 13,
                    color: const Color(0xFFECECFF).withOpacity(0.7)),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),

            // Indeterminate progress — Python is streaming + buffering
            const LinearProgressIndicator(
              backgroundColor: Color(0xFF080810),
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00E5FF)),
            ),
            const SizedBox(height: 10),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.wifi, size: 13,
                    color: const Color(0xFF00E5FF).withOpacity(0.7)),
                const SizedBox(width: 6),
                Text('Buffering stream…',
                    style: TextStyle(
                        fontSize: 13,
                        color: const Color(0xFFECECFF).withOpacity(0.6))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
// lib/screens/playlists_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/playlist.dart';
import '../models/song.dart';
import '../services/audio_service.dart';
import '../providers/audio_provider.dart';
import '../providers/playlist_provider.dart';
import 'play_screen.dart';

const _bg       = Color(0xFF0C0C14);
const _surface  = Color(0xFF141420);
const _surface2 = Color(0xFF1C1C2A);
const _accent   = Color(0xFFFF8C42);
const _accent2  = Color(0xFFFF5F6D);
const _textPri  = Color(0xFFF0EFFF);
const _textSec  = Color(0xFF6E6E8A);

class PlaylistsScreen extends StatefulWidget {
  const PlaylistsScreen({super.key});

  @override
  State<PlaylistsScreen> createState() => _PlaylistsScreenState();
}

class _PlaylistsScreenState extends State<PlaylistsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PlaylistProvider>().loadPlaylists();
    });
  }

  Future<void> _createPlaylist(PlaylistProvider provider) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _surface,
        title: const Text('New Playlist', style: TextStyle(color: _textPri)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: _textPri),
          decoration: const InputDecoration(
            hintText: 'Playlist name',
            hintStyle: TextStyle(color: _textSec),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: _accent),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: _accent),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: _textSec)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Create', style: TextStyle(color: _accent)),
          ),
        ],
      ),
    );
    if (result != null && result.trim().isNotEmpty) {
      await provider.createPlaylist(result.trim());
    }
  }

  Future<void> _deletePlaylist(PlaylistProvider provider, Playlist playlist) async {
    await provider.deletePlaylist(playlist.id);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlaylistProvider>(
      builder: (context, playlistProvider, _) {
        final playlists = playlistProvider.playlists;
        return Scaffold(
          backgroundColor: _bg,
          appBar: AppBar(
            backgroundColor: _bg,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: _textPri),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text('Playlists',
                style: TextStyle(color: _textPri, fontWeight: FontWeight.w700)),
            actions: [
              IconButton(
                icon: const Icon(Icons.add_rounded, color: _accent),
                onPressed: () => _createPlaylist(playlistProvider),
              ),
            ],
          ),
          body: playlists.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.playlist_play_rounded,
                          size: 64, color: _textSec.withOpacity(0.4)),
                      const SizedBox(height: 16),
                      const Text('No playlists yet',
                          style: TextStyle(color: _textSec, fontSize: 15)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: playlists.length,
                  itemBuilder: (context, index) {
                    final playlist = playlists[index];
                    final songCount = playlist.songVideoIds.length;
                    return GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PlaylistDetailScreen(playlistId: playlist.id),
                        ),
                      ),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF22223A)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [_accent, _accent2],
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.playlist_play_rounded,
                                  color: Colors.white, size: 28),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    playlist.name,
                                    style: const TextStyle(
                                      color: _textPri,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$songCount ${songCount == 1 ? 'song' : 'songs'}',
                                    style: const TextStyle(
                                        color: _textSec, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded,
                                  color: _textSec, size: 20),
                              onPressed: () => _deletePlaylist(playlistProvider, playlist),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}

class PlaylistDetailScreen extends StatefulWidget {
  final String playlistId;

  const PlaylistDetailScreen({super.key, required this.playlistId});

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  final _audioService = AudioService.instance;

  Future<void> _removeSong(PlaylistProvider provider, String videoId) async {
    await provider.removeSongFromPlaylist(widget.playlistId, videoId);
  }

  Future<void> _handlePlay(Song song, List<Song> songs) async {
    final audioProvider = context.read<AudioProvider>();
    _audioService.setPlaylist(songs);
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PlayScreen()),
      );
    }
    await audioProvider.play(song);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlaylistProvider>(
      builder: (context, playlistProvider, _) {
        final playlist = playlistProvider.getPlaylist(widget.playlistId);
        if (playlist == null) {
          return Scaffold(
            backgroundColor: _bg,
            appBar: AppBar(
              backgroundColor: _bg,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: _textPri),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            body: const Center(
              child: Text('Playlist not found',
                  style: TextStyle(color: _textSec)),
            ),
          );
        }

        final songs = playlistProvider.getPlaylistSongs(playlist);

        return Scaffold(
          backgroundColor: _bg,
          appBar: AppBar(
            backgroundColor: _bg,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: _textPri),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(playlist.name,
                style: const TextStyle(
                    color: _textPri, fontWeight: FontWeight.w700)),
          ),
          body: songs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.music_off_rounded,
                          size: 56, color: _textSec.withOpacity(0.4)),
                      const SizedBox(height: 14),
                      const Text('No songs in playlist',
                          style: TextStyle(color: _textSec, fontSize: 15)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: songs.length,
                  itemBuilder: (context, index) {
                    final song = songs[index];
                    return GestureDetector(
                      onTap: () => _handlePlay(song, songs),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: _surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF22223A)),
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
                                errorBuilder: (_, __, ___) => Container(
                                  width: 52,
                                  height: 52,
                                  color: _surface2,
                                  child: const Icon(Icons.music_note_rounded,
                                      color: _accent, size: 24),
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
                                    style: const TextStyle(
                                      color: _textPri,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    song.artist,
                                    style: const TextStyle(
                                        color: _textSec, fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                  Icons.remove_circle_outline_rounded,
                                  color: _textSec,
                                  size: 20),
                              onPressed: () => _removeSong(
                                  playlistProvider, song.youtubeVideoId ?? ''),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}

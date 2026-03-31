// lib/screens/playlists_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/playlist.dart';
import '../models/song.dart';
import '../services/audio_service.dart';
import '../providers/audio_provider.dart';
import '../providers/playlist_provider.dart';
import 'play_screen.dart';

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

  // ── Theme helpers ──────────────────────────────────────────────────────────

  ColorScheme _cs(BuildContext ctx) => Theme.of(ctx).colorScheme;
  Color _accent(BuildContext ctx)   => _cs(ctx).primary;
  Color _accent2(BuildContext ctx)  => _cs(ctx).secondary;
  Color _textPri(BuildContext ctx)  => _cs(ctx).onSurface;
  Color _textSec(BuildContext ctx)  => _cs(ctx).onSurface.withOpacity(0.55);
  Color _surf(BuildContext ctx)     => _cs(ctx).surface;
  Color _border(BuildContext ctx)   => _cs(ctx).outline;

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _createPlaylist(PlaylistProvider provider) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Playlist'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Playlist name',
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: _accent(ctx)),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: _accent(ctx)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TextStyle(color: _textSec(ctx))),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(ctx, controller.text),
            child: Text('Create',
                style: TextStyle(color: _accent(ctx),
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (result != null && result.trim().isNotEmpty) {
      await provider.createPlaylist(result.trim());
    }
  }

  Future<void> _deletePlaylist(
      PlaylistProvider provider, Playlist playlist) async {
    await provider.deletePlaylist(playlist.id);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Consumer<PlaylistProvider>(
      builder: (ctx, playlistProvider, _) {
        final playlists = playlistProvider.playlists;
        final accent    = _accent(ctx);
        final accent2   = _accent2(ctx);
        final textPri   = _textPri(ctx);
        final textSec   = _textSec(ctx);
        final surf      = _surf(ctx);
        final border    = _border(ctx);

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.pop(ctx),
            ),
            title: const Text('Playlists'),
            actions: [
              IconButton(
                icon: Icon(Icons.add_rounded, color: accent),
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
                          size: 64,
                          color: textSec.withOpacity(0.4)),
                      const SizedBox(height: 16),
                      Text('No playlists yet',
                          style: TextStyle(color: textSec, fontSize: 15)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: playlists.length,
                  itemBuilder: (ctx, index) {
                    final playlist = playlists[index];
                    final songCount = playlist.songVideoIds.length;
                    return GestureDetector(
                      onTap: () => Navigator.push(
                        ctx,
                        MaterialPageRoute(
                          builder: (_) => PlaylistDetailScreen(
                              playlistId: playlist.id),
                        ),
                      ),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: surf,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: border, width: 0.5),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 56, height: 56,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                    colors: [accent, accent2]),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                  Icons.playlist_play_rounded,
                                  color: Colors.white, size: 28),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    playlist.name,
                                    style: TextStyle(
                                      color: textPri,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$songCount ${songCount == 1 ? 'song' : 'songs'}',
                                    style: TextStyle(
                                        color: textSec, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                  Icons.delete_outline_rounded,
                                  color: textSec, size: 20),
                              onPressed: () => _deletePlaylist(
                                  playlistProvider, playlist),
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

// ── Playlist detail ────────────────────────────────────────────────────────

class PlaylistDetailScreen extends StatefulWidget {
  final String playlistId;

  const PlaylistDetailScreen({super.key, required this.playlistId});

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  final _audioService = AudioService.instance;

  ColorScheme _cs(BuildContext ctx) => Theme.of(ctx).colorScheme;
  Color _accent(BuildContext ctx)   => _cs(ctx).primary;
  Color _textPri(BuildContext ctx)  => _cs(ctx).onSurface;
  Color _textSec(BuildContext ctx)  => _cs(ctx).onSurface.withOpacity(0.55);
  Color _surf(BuildContext ctx)     => _cs(ctx).surface;
  Color _surf2(BuildContext ctx)    => _cs(ctx).surfaceContainerHighest;
  Color _border(BuildContext ctx)   => _cs(ctx).outline;

  Future<void> _removeSong(PlaylistProvider provider, String videoId) async {
    await provider.removeSongFromPlaylist(widget.playlistId, videoId);
  }

  Future<void> _handlePlay(Song song, List<Song> songs) async {
    final audioProvider = context.read<AudioProvider>();
    _audioService.setPlaylist(songs);
    if (mounted) {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const PlayScreen()));
    }
    await audioProvider.play(song);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlaylistProvider>(
      builder: (ctx, playlistProvider, _) {
        final playlist =
            playlistProvider.getPlaylist(widget.playlistId);

        if (playlist == null) {
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
            body: Center(
              child: Text('Playlist not found',
                  style: TextStyle(color: _textSec(ctx))),
            ),
          );
        }

        final songs   = playlistProvider.getPlaylistSongs(playlist);
        final accent  = _accent(ctx);
        final textPri = _textPri(ctx);
        final textSec = _textSec(ctx);
        final surf    = _surf(ctx);
        final surf2   = _surf2(ctx);
        final border  = _border(ctx);

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.pop(ctx),
            ),
            title: Text(playlist.name),
          ),
          body: songs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.music_off_rounded,
                          size: 56,
                          color: textSec.withOpacity(0.4)),
                      const SizedBox(height: 14),
                      Text('No songs in playlist',
                          style: TextStyle(
                              color: textSec, fontSize: 15)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: songs.length,
                  itemBuilder: (ctx, index) {
                    final song = songs[index];
                    return GestureDetector(
                      onTap: () => _handlePlay(song, songs),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: surf,
                          borderRadius: BorderRadius.circular(14),
                          border:
                              Border.all(color: border, width: 0.5),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                song.artworkUrl,
                                width: 52, height: 52,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 52, height: 52,
                                  color: surf2,
                                  child: Icon(
                                      Icons.music_note_rounded,
                                      color: accent, size: 24),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    song.title,
                                    style: TextStyle(
                                      color: textPri,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    song.artist,
                                    style: TextStyle(
                                        color: textSec, fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                  Icons.remove_circle_outline_rounded,
                                  color: textSec, size: 20),
                              onPressed: () => _removeSong(
                                  playlistProvider,
                                  song.youtubeVideoId ?? ''),
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
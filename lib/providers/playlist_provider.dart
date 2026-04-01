// lib/providers/playlist_provider.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/playlist.dart';
import '../models/song.dart';
import '../db/hive_helper.dart';

class PlaylistProvider extends ChangeNotifier {
  final _db = HiveHelper.instance;

  List<Playlist> _playlists = [];
  List<Playlist> get playlists => _playlists;

  Timer? _debounceTimer;
  bool _hasUpdate = false;

  PlaylistProvider() {
    loadPlaylists();
  }

  void loadPlaylists() {
    _playlists = _db.getAllPlaylists();
    _scheduleUpdate();
  }

  void _scheduleUpdate() {
    _hasUpdate = true;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 50), () {
      if (_hasUpdate) {
        _hasUpdate = false;
        notifyListeners();
      }
    });
  }

  Future<void> createPlaylist(String name) async {
    await _db.createPlaylist(name);
    loadPlaylists();
  }

  Future<void> deletePlaylist(String id) async {
    await _db.deletePlaylist(id);
    loadPlaylists();
  }

  Future<void> renamePlaylist(String id, String newName) async {
    await _db.renamePlaylist(id, newName);
    loadPlaylists();
  }

  Future<void> addSongToPlaylist(String playlistId, String videoId, Song song) async {
    await _db.saveSong(song);
    await _db.addSongToPlaylist(playlistId, videoId);
    loadPlaylists();
  }

  Future<void> removeSongFromPlaylist(String playlistId, String videoId) async {
    await _db.removeSongFromPlaylist(playlistId, videoId);
    loadPlaylists();
  }

  List<Song> getPlaylistSongs(Playlist playlist) =>
      _db.getPlaylistSongs(playlist);

  Playlist? getPlaylist(String id) => _db.getPlaylist(id);

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}

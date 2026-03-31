// lib/db/hive_helper.dart

import 'package:hive_flutter/hive_flutter.dart';
import '../models/song.dart';
import '../models/playlist.dart';
import '../models/custom_theme.dart';

class HiveHelper {
  HiveHelper._();
  static final HiveHelper instance = HiveHelper._();

  static const _boxSongs     = 'songs';
  static const _boxHistory   = 'play_history';
  static const _boxSettings  = 'settings';
  static const _boxPlaylists = 'playlists';
  static const _boxThemes    = 'custom_themes';

  late Box<Song>        _songs;
  late Box<Map>         _history;
  late Box<dynamic>     _settings;
  late Box<Playlist>    _playlists;
  late Box<CustomTheme> _themes;

  Future<void> init() async {
    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(SongAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(PlaylistAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(CustomThemeAdapter());
    _songs     = await Hive.openBox<Song>(_boxSongs);
    _history   = await Hive.openBox<Map>(_boxHistory);
    _settings  = await Hive.openBox<dynamic>(_boxSettings);
    _playlists = await Hive.openBox<Playlist>(_boxPlaylists);
    _themes    = await Hive.openBox<CustomTheme>(_boxThemes);
    
    // Initialize default themes if not exists
    if (_themes.isEmpty) {
      await _themes.put('dark', CustomTheme.darkTheme);
      await _themes.put('light', CustomTheme.lightTheme);
    }
  }

  // ── Songs ──────────────────────────────────────────────────────────────────

  List<Song> getAllSavedSongs() =>
      _songs.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<Song> getFavourites() =>
      _songs.values.where((s) => s.isFavourite).toList()
        ..sort((a, b) => a.title.compareTo(b.title));

  Song? getSongByVideoId(String videoId) {
    try {
      return _songs.values.firstWhere((s) => s.youtubeVideoId == videoId);
    } catch (_) {
      return null;
    }
  }

  Future<Song> saveSong(Song song) async {
    final key = song.youtubeVideoId ?? DateTime.now().millisecondsSinceEpoch.toString();
    final existing = _songs.get(key);
    if (existing != null) {
      existing
        ..isFavourite  = song.isFavourite
        ..playCount    = song.playCount
        ..lastPlayedAt = song.lastPlayedAt;
      await existing.save();
      return existing;
    }
    await _songs.put(key, song);
    return song;
  }

  Future<void> toggleFavourite(Song song, bool value) async {
    final key = song.youtubeVideoId ?? song.id.toString();
    final s = _songs.get(key);
    if (s != null) {
      s.isFavourite = value;
      await s.save();
    }
  }

  Future<void> deleteSong(Song song) async =>
      _songs.delete(song.youtubeVideoId ?? song.id.toString());

  // ── History ────────────────────────────────────────────────────────────────

  Future<void> logPlay(Song song) async {
    final key = song.youtubeVideoId ?? song.id.toString();
    final s = _songs.get(key);
    if (s != null) {
      s.playCount++;
      s.lastPlayedAt = DateTime.now();
      await s.save();
    }
    final histKey = DateTime.now().toIso8601String();
    await _history.put(histKey, {
      'video_id':  song.youtubeVideoId,
      'played_at': histKey,
    });
    if (_history.length > 50) {
      final keys = _history.keys.toList()..sort();
      await _history.deleteAll(keys.take(_history.length - 50));
    }
  }

  List<Song> getRecentlyPlayed({int limit = 20}) {
    final entries = _history.values.toList()
      ..sort((a, b) =>
          (b['played_at'] as String).compareTo(a['played_at'] as String));
    final seen   = <String>{};
    final result = <Song>[];
    for (final e in entries) {
      final id = e['video_id'] as String?;
      if (id == null || seen.contains(id)) continue;
      seen.add(id);
      final song = getSongByVideoId(id);
      if (song != null) result.add(song);
      if (result.length >= limit) break;
    }
    return result;
  }

  Future<void> clearHistory() => _history.clear();

  // ── Settings ───────────────────────────────────────────────────────────────

  T? getSetting<T>(String key) => _settings.get(key) as T?;
  Future<void> setSetting(String key, dynamic v) => _settings.put(key, v);

  Future<void> close() async {
    await _songs.close();
    await _history.close();
    await _settings.close();
    await _playlists.close();
    await _themes.close();
  }

  // ── Playlists ──────────────────────────────────────────────────────────────

  List<Playlist> getAllPlaylists() =>
      _playlists.values.toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  Playlist? getPlaylist(String id) => _playlists.get(id);

  Future<Playlist> createPlaylist(String name) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final playlist = Playlist(
      id: id,
      name: name,
      songVideoIds: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await _playlists.put(id, playlist);
    return playlist;
  }

  Future<void> addSongToPlaylist(String playlistId, String videoId) async {
    final playlist = _playlists.get(playlistId);
    if (playlist != null && !playlist.songVideoIds.contains(videoId)) {
      playlist.songVideoIds.add(videoId);
      playlist.updatedAt = DateTime.now();
      await playlist.save();
    }
  }

  Future<void> removeSongFromPlaylist(String playlistId, String videoId) async {
    final playlist = _playlists.get(playlistId);
    if (playlist != null) {
      playlist.songVideoIds.remove(videoId);
      playlist.updatedAt = DateTime.now();
      await playlist.save();
    }
  }

  Future<void> deletePlaylist(String id) => _playlists.delete(id);

  Future<void> renamePlaylist(String id, String newName) async {
    final playlist = _playlists.get(id);
    if (playlist != null) {
      playlist.name = newName;
      playlist.updatedAt = DateTime.now();
      await playlist.save();
    }
  }

  List<Song> getPlaylistSongs(Playlist playlist) =>
      playlist.songVideoIds
          .map((id) => getSongByVideoId(id))
          .whereType<Song>()
          .toList();

  // ── Custom Themes ──────────────────────────────────────────────────────────

  List<CustomTheme> getAllCustomThemes() => _themes.values.toList();

  CustomTheme? getCustomTheme(String id) => _themes.get(id);

  Future<void> saveCustomTheme(CustomTheme theme) async {
    await _themes.put(theme.id, theme);
  }

  Future<void> updateCustomTheme(CustomTheme theme) async {
    await _themes.put(theme.id, theme);
  }

  Future<void> deleteCustomTheme(String id) async {
    final theme = _themes.get(id);
    if (theme != null && !theme.isDefault) {
      await _themes.delete(id);
    }
  }
}

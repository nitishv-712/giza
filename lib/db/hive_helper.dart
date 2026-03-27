// lib/db/hive_helper.dart

import 'package:hive_flutter/hive_flutter.dart';
import '../models/song.dart';

class HiveHelper {
  HiveHelper._();
  static final HiveHelper instance = HiveHelper._();

  static const _boxSongs    = 'songs';
  static const _boxHistory  = 'play_history';
  static const _boxSettings = 'settings';

  late Box<Song>    _songs;
  late Box<Map>     _history;
  late Box<dynamic> _settings;

  // ── Init ───────────────────────────────────────────────────────────────────

  Future<void> init() async {
    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(SongAdapter());
    }
    _songs    = await Hive.openBox<Song>(_boxSongs);
    _history  = await Hive.openBox<Map>(_boxHistory);
    _settings = await Hive.openBox<dynamic>(_boxSettings);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SONGS
  // ══════════════════════════════════════════════════════════════════════════

  List<Song> getAllSavedSongs() {
    final list = _songs.values.toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  List<Song> getFavourites() {
    return _songs.values.where((s) => s.isFavourite).toList()
      ..sort((a, b) => a.title.compareTo(b.title));
  }

  List<Song> searchSavedSongs(String query) {
    final q = query.toLowerCase();
    return _songs.values
        .where((s) =>
            s.title.toLowerCase().contains(q) ||
            s.artist.toLowerCase().contains(q) ||
            s.album.toLowerCase().contains(q))
        .toList()
      ..sort((a, b) => a.title.compareTo(b.title));
  }

  Song? getSongByAudiusId(String trackId) {
    try {
      return _songs.values.firstWhere((s) => s.audiusTrackId == trackId);
    } catch (_) {
      return null;
    }
  }

  /// Upserts a song keyed on audiusTrackId.
  Future<Song> saveSong(Song song) async {
    if (song.audiusTrackId != null) {
      final existing = getSongByAudiusId(song.audiusTrackId!);
      if (existing != null) {
        existing
          ..isFavourite  = song.isFavourite
          ..playCount    = song.playCount
          ..lastPlayedAt = song.lastPlayedAt;
        await existing.save();
        return existing;
      }
    }
    final key = song.audiusTrackId ?? DateTime.now().millisecondsSinceEpoch.toString();
    await _songs.put(key, song);
    return song;
  }

  Future<void> toggleFavourite(Song song, bool value) async {
    final key = song.audiusTrackId ?? song.id.toString();
    final s = _songs.get(key);
    if (s != null) {
      s.isFavourite = value;
      await s.save();
    }
  }

  Future<void> deleteSong(Song song) async {
    await _songs.delete(song.audiusTrackId ?? song.id.toString());
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PLAY HISTORY
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> logPlay(Song song) async {
    final key = song.audiusTrackId ?? song.id.toString();
    final s = _songs.get(key);
    if (s != null) {
      s.playCount++;
      s.lastPlayedAt = DateTime.now();
      await s.save();
    }

    final histKey = DateTime.now().toIso8601String();
    await _history.put(histKey, {
      'audius_track_id': song.audiusTrackId,
      'played_at': histKey,
    });

    // Trim to 50 newest entries
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
      final id = e['audius_track_id'] as String?;
      if (id == null || seen.contains(id)) continue;
      seen.add(id);
      final song = getSongByAudiusId(id);
      if (song != null) result.add(song);
      if (result.length >= limit) break;
    }
    return result;
  }

  Future<void> clearHistory() => _history.clear();

  // ══════════════════════════════════════════════════════════════════════════
  // SETTINGS
  // ══════════════════════════════════════════════════════════════════════════

  T? getSetting<T>(String key) => _settings.get(key) as T?;
  Future<void> setSetting(String key, dynamic v) => _settings.put(key, v);

  Future<void> close() async {
    await _songs.close();
    await _history.close();
    await _settings.close();
  }
}

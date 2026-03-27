// lib/services/audius_service.dart
//
// Wraps the Audius REST API — completely free, no API key required.
// Used for track discovery, search, trending, and metadata.
// Audio playback is handled separately via YouTube IFrame.

import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

import '../models/song.dart';

class AudiusService {
  AudiusService._();
  static final AudiusService instance = AudiusService._();

  static const _hostRegistryUrl = 'https://api.audius.co';
  static const _appName         = 'GIZA';

  String? _host;

  // ── Host selection ─────────────────────────────────────────────────────────

  Future<String> get host async {
    if (_host != null) return _host!;
    try {
      final res  = await http.get(Uri.parse(_hostRegistryUrl));
      final data = (jsonDecode(res.body)['data'] as List).cast<String>();
      if (data.isEmpty) throw Exception('No Audius hosts returned');
      _host = data[Random().nextInt(data.length)];
      return _host!;
    } catch (e) {
      _host = 'https://discoveryprovider.audius.co';
      return _host!;
    }
  }

  Future<Uri> _uri(String path, [Map<String, String>? params]) async {
    final base = await host;
    final p    = {'app_name': _appName, ...?params};
    return Uri.parse('$base$path').replace(queryParameters: p);
  }

  // ── Trending tracks ────────────────────────────────────────────────────────

  Future<List<Song>> getTrendingTracks({int limit = 20, String time = 'week'}) async {
    try {
      final uri = await _uri('/v1/tracks/trending', {
        'limit': limit.toString(),
        'time':  time,
      });
      final res = await http.get(uri);
      _check(res, 'Trending tracks');
      final items = (jsonDecode(res.body)['data'] as List).cast<Map<String, dynamic>>();
      return await _tracksToSongs(items);
    } catch (e) {
      if (e is AudiusException) rethrow;
      throw AudiusException('Trending tracks failed: $e');
    }
  }

  Future<List<Song>> getUndergroundTrending({int limit = 20}) async {
    try {
      final uri = await _uri('/v1/tracks/trending/underground', {
        'limit': limit.toString(),
      });
      final res = await http.get(uri);
      _check(res, 'Underground trending');
      final items = (jsonDecode(res.body)['data'] as List).cast<Map<String, dynamic>>();
      return await _tracksToSongs(items);
    } catch (e) {
      if (e is AudiusException) rethrow;
      throw AudiusException('Underground trending failed: $e');
    }
  }

  // ── Search ────────────────────────────────────────────────────────────────

  Future<List<Song>> searchTracks(String query, {int limit = 30}) async {
    if (query.trim().isEmpty) return [];
    try {
      final uri = await _uri('/v1/tracks/search', {
        'query': query.trim(),
        'limit': limit.toString(),
      });
      final res = await http.get(uri);
      _check(res, 'Search tracks');
      final items = (jsonDecode(res.body)['data'] as List).cast<Map<String, dynamic>>();
      return await _tracksToSongs(items);
    } catch (e) {
      if (e is AudiusException) rethrow;
      throw AudiusException('Search failed: $e');
    }
  }

  // ── Trending playlists ────────────────────────────────────────────────────

  Future<List<AudiusPlaylist>> getTrendingPlaylists({int limit = 10}) async {
    try {
      final uri = await _uri('/v1/playlists/trending', {
        'limit': limit.toString(),
      });
      final res = await http.get(uri);
      _check(res, 'Trending playlists');
      final items = (jsonDecode(res.body)['data'] as List).cast<Map<String, dynamic>>();
      return items.map(_mapPlaylist).toList();
    } catch (e) {
      if (e is AudiusException) rethrow;
      throw AudiusException('Trending playlists failed: $e');
    }
  }

  // ── Playlist tracks ────────────────────────────────────────────────────────

  Future<List<Song>> getPlaylistTracks(String playlistId, {int limit = 30}) async {
    try {
      final uri = await _uri('/v1/playlists/$playlistId/tracks', {
        'limit': limit.toString(),
      });
      final res = await http.get(uri);
      _check(res, 'Playlist tracks');
      final items = (jsonDecode(res.body)['data'] as List).cast<Map<String, dynamic>>();
      return await _tracksToSongs(items);
    } catch (e) {
      if (e is AudiusException) rethrow;
      throw AudiusException('Playlist tracks failed: $e');
    }
  }

  // ── Single track ───────────────────────────────────────────────────────────

  Future<Song?> getTrack(String trackId) async {
    try {
      final uri = await _uri('/v1/tracks/$trackId');
      final res = await http.get(uri);
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body)['data'] as Map<String, dynamic>;
      return (await _tracksToSongs([data])).firstOrNull;
    } catch (_) {
      return null;
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Future<List<Song>> _tracksToSongs(List<Map<String, dynamic>> items) async {
    final h = await host;
    return items
        .where((t) => t['is_streamable'] == true || t['is_streamable'] == null)
        .map((t) => _mapTrack(t, h))
        .toList();
  }

  Song _mapTrack(Map<String, dynamic> t, String h) {
    final artwork = t['artwork'] as Map<String, dynamic>?;
    final artUrl  = (artwork?['480x480'] ?? artwork?['150x150'] ?? '') as String;
    final user    = t['user'] as Map<String, dynamic>?;
    final artist  = (user?['name'] ?? user?['handle'] ?? 'Unknown Artist') as String;
    final trackId = (t['id'] ?? '') as String;

    return Song(
      audiusTrackId:   trackId,
      title:           (t['title'] ?? 'Unknown') as String,
      artist:          artist,
      album:           '',
      genre:           (t['genre'] ?? '') as String,
      durationSeconds: (t['duration'] as num?)?.toInt() ?? 0,
      artworkUrl:      artUrl,
      streamUrl:       '$h/v1/tracks/$trackId/stream?app_name=$_appName',
      audiusPlayCount: (t['play_count'] as num?)?.toInt(),
      repostCount:     (t['repost_count'] as num?)?.toInt(),
      favouriteCount:  (t['favorite_count'] as num?)?.toInt(),
      tags:            t['tags'] as String?,
      mood:            t['mood'] as String?,
      isStreamable:    (t['is_streamable'] as bool?) ?? true,
      createdAt:       DateTime.now(),
    );
  }

  AudiusPlaylist _mapPlaylist(Map<String, dynamic> p) {
    final artwork = p['artwork'] as Map<String, dynamic>?;
    final artUrl  = (artwork?['480x480'] ?? artwork?['150x150'] ?? '') as String;
    final user    = p['user'] as Map<String, dynamic>?;
    return AudiusPlaylist(
      id:             (p['id'] ?? '') as String,
      name:           (p['playlist_name'] ?? 'Untitled') as String,
      description:    (p['description'] ?? '') as String,
      artworkUrl:     artUrl,
      trackCount:     (p['playlist_contents']?['track_ids'] as List?)?.length ?? 0,
      curator:        (user?['name'] ?? user?['handle'] ?? '') as String,
      repostCount:    (p['repost_count'] as num?)?.toInt() ?? 0,
      favouriteCount: (p['favorite_count'] as num?)?.toInt() ?? 0,
    );
  }

  void _check(http.Response res, String ctx) {
    if (res.statusCode != 200) {
      throw AudiusException('$ctx failed (HTTP ${res.statusCode})');
    }
  }

  void dispose() {}
}

// ── Data classes ──────────────────────────────────────────────────────────────

class AudiusPlaylist {
  final String id;
  final String name;
  final String description;
  final String artworkUrl;
  final int    trackCount;
  final String curator;
  final int    repostCount;
  final int    favouriteCount;

  const AudiusPlaylist({
    required this.id,
    required this.name,
    required this.description,
    required this.artworkUrl,
    required this.trackCount,
    required this.curator,
    required this.repostCount,
    required this.favouriteCount,
  });
}

class AudiusException implements Exception {
  final String message;
  const AudiusException(this.message);
  @override
  String toString() => 'AudiusException: $message';
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

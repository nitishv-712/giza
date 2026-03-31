// lib/services/youtube_service.dart
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/song.dart';

class YoutubeService {
  YoutubeService._();
  static final YoutubeService instance = YoutubeService._();

  final _yt = YoutubeExplode();
  static const _channel = MethodChannel('com.giza.app/youtube');

  // ── Search (youtube_explode_dart) ──────────────────────────────────────────
  Future<String?> getVideoIdFromQuery(String query) async {
    if (query.trim().isEmpty) return null;
    final results = await _yt.search.search(query.trim());
    return results.isNotEmpty ? results.first.id.value : null;
  }

  Future<List<Song>> searchTracks(String query, {int limit = 5}) async {
    if (query.trim().isEmpty) return [];
    final results = await _yt.search.searchContent(query.trim());
    return results
        .whereType<SearchVideo>()
        .where(_isSongVideo)
        .take(limit)
        .map(_videoToSong)
        .toList();
  }

  // Filter to target only music tracks (not shorts, podcasts, or extra long videos)
  bool _isSongVideo(SearchVideo video) {
    final duration = _parseDuration(video.duration);
    final title = video.title.toLowerCase();
    
    // Duration filter: 30 seconds to 10 minutes (typical song range)
    if (duration < 30 || duration > 600) return false;
    
    // Exclude shorts/reels (usually < 60 seconds)
    if (duration < 60 && (title.contains('short') || title.contains('#short'))) {
      return false;
    }
    
    // Exclude common non-music content
    final excludeKeywords = [
      'podcast',
      'interview',
      'tutorial',
      'review',
      'reaction',
      'vlog',
      'gameplay',
      'livestream',
      'live stream',
      'full album',
      'full concert',
      'documentary',
    ];
    
    for (final keyword in excludeKeywords) {
      if (title.contains(keyword)) return false;
    }
    
    return true;
  }

  Song _videoToSong(SearchVideo v) => Song(
        youtubeVideoId: v.id.value,
        title: v.title,
        artist: v.author,
        durationSeconds: _parseDuration(v.duration),
        artworkUrl: 'https://i.ytimg.com/vi/${v.id.value}/hqdefault.jpg',
        createdAt: DateTime.now(),
      );

  Future<List<Song>> getTrendingTracks({int limit = 25}) =>
      searchTracks('trending music 2026', limit: limit);

  Future<List<Song>> getUndergroundTracks({int limit = 20}) =>
      searchTracks('underground music mix', limit: limit);

  // ── Download Audio ─────────────────────────────────────────────────────────

  Future<String> downloadAudio(
    String videoId,
    String saveDirPath, {
    void Function(double)? onProgress,
    String? quality,
  }) async {
    final watchUrl = 'https://www.youtube.com/watch?v=$videoId';
    try {
      final path = await _channel.invokeMethod<String>(
        'downloadAudio',
        {
          'url':     watchUrl,
          'saveDir': saveDirPath,
          'videoId': videoId,
          'quality': quality ?? 'best', // Pass quality preference
        },
      );
      if (path == null || path.isEmpty) {
        throw Exception('Empty path from downloadAudio');
      }
      onProgress?.call(1.0);
      return path;
    } on PlatformException catch (e) {
      throw Exception('Download failed: ${e.message}');
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  int _parseDuration(dynamic d) {
    if (d == null) return 0;
    if (d is Duration) return d.inSeconds;
    if (d is String) {
      final parts =
          d.split(':').map((p) => int.tryParse(p) ?? 0).toList();
      if (parts.length == 2) return parts[0] * 60 + parts[1];
      if (parts.length == 3) return parts[0] * 3600 + parts[1] * 60 + parts[2];
    }
    return 0;
  }

  void dispose() => _yt.close();
}
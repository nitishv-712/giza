import 'dart:async';
import 'package:flutter/services.dart'; // Add this
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/song.dart';

class YoutubeService {
  YoutubeService._();
  static final YoutubeService instance = YoutubeService._();

  final _yt = YoutubeExplode();
  
  // Replace FlutterYtDlpClient with MethodChannel
  static const _channel = MethodChannel('com.example.giza/ytdlp');

  // ── Download ───────────────────────────────────────────────────────────────

  Future<String> downloadAudio(
    String videoId,
    String outputDir, {
    void Function(double)? onProgress,
  }) async {
    final url = 'https://www.youtube.com/watch?v=$videoId';

    try {
      // Direct call to Python via Native Bridge
      // Note: Direct yt-dlp through Chaquopy handles format selection internally better
      onProgress?.call(0.1); // Start indicator

      final String filePath = await _channel.invokeMethod('downloadAudio', {
        'url': url,
        'path': outputDir,
        'id': videoId,
      });

      onProgress?.call(1.0);
      return filePath;
    } on PlatformException catch (e) {
      throw Exception('yt-dlp download failed: ${e.message}');
    }
  }

  // ── Search & Helpers (Stay mostly the same) ───────────────────────────────
  
  Future<List<Song>> searchTracks(String query, {int limit = 30}) async {
    if (query.trim().isEmpty) return [];
    final results = await _yt.search.searchContent(query.trim());
    return results.whereType<SearchVideo>().take(limit).map(_videoToSong).toList();
  }

  Song _videoToSong(SearchVideo v) {
    return Song(
      youtubeVideoId: v.id.value,
      title: v.title,
      artist: v.author,
      durationSeconds: _parseDuration(v.duration),
      artworkUrl: 'https://i.ytimg.com/vi/${v.id.value}/hqdefault.jpg',
      createdAt: DateTime.now(),
    );
  }
  Future<List<Song>> getTrendingTracks({int limit = 25}) =>
      searchTracks('trending music 2026', limit: limit);

  Future<List<Song>> getUndergroundTracks({int limit = 20}) =>
      searchTracks('underground music mix', limit: limit);

  int _parseDuration(dynamic d) {
    if (d == null) return 0;
    if (d is Duration) return d.inSeconds;
    if (d is String) {
      final parts = d.split(':').map((p) => int.tryParse(p) ?? 0).toList();
      if (parts.length == 2) return parts[0] * 60 + parts[1];
      if (parts.length == 3) return parts[0] * 3600 + parts[1] * 60 + parts[2];
    }
    return 0;
  }
  void dispose() => _yt.close();
}
// lib/services/youtube_service.dart

import 'dart:async';
import 'package:flutter_yt_dlp/flutter_yt_dlp.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/song.dart';

class YoutubeService {
  YoutubeService._();
  static final YoutubeService instance = YoutubeService._();

  final _yt     = YoutubeExplode();
  final _client = FlutterYtDlpClient();

  // ── Download ───────────────────────────────────────────────────────────────

  /// Downloads best audio-only format to [outputDir]/[videoId].mp3.
  /// Returns the saved file path on completion.
  Future<String> downloadAudio(
    String videoId,
    String outputDir, {
    void Function(double)? onProgress,
  }) async {
    final url  = 'https://youtu.be/$videoId';
    final info = await _client.getVideoInfo(url);

    final audioFormats = info['rawAudioOnlyFormats'] as List?;
    if (audioFormats == null || audioFormats.isEmpty) {
      throw Exception('No audio-only formats found for $videoId');
    }

    // Pick highest bitrate
    final format = audioFormats.reduce((a, b) =>
        ((a['tbr'] ?? 0) as num) >= ((b['tbr'] ?? 0) as num) ? a : b);

    final taskId = await _client.startDownload(
      format: format,
      outputDir: outputDir,
      url: url,
      overwrite: true,
      overrideName: videoId,
    );

    final completer = Completer<String>();

    _client.getDownloadEvents().listen((event) {
      if (event['taskId'] != taskId) return;
      if (event['type'] == 'progress') {
        final total = (event['total'] as int?) ?? 0;
        if (total > 0) {
          onProgress?.call(((event['downloaded'] as int) / total).clamp(0.0, 1.0));
        }
      } else if (event['type'] == 'state') {
        final state = event['stateName'] as String?;
        if (state == 'completed' && !completer.isCompleted) {
          onProgress?.call(1.0);
          completer.complete(event['outputPath'] as String? ?? '$outputDir/$videoId.mp3');
        } else if (state == 'failed' && !completer.isCompleted) {
          completer.completeError(Exception('yt-dlp download failed'));
        }
      }
    });

    return completer.future;
  }

  // ── Search ─────────────────────────────────────────────────────────────────

  Future<List<Song>> searchTracks(String query, {int limit = 30}) async {
    if (query.trim().isEmpty) return [];
    print('[YT] searching: "$query"');
    final results = await _yt.search.searchContent(query.trim());
    print('[YT] raw results: ${results.length} items');
    final songs = results.whereType<SearchVideo>().take(limit).map(_videoToSong).toList();
    print('[YT] mapped songs: ${songs.length}');
    return songs;
  }

  Future<List<Song>> getTrendingTracks({int limit = 25}) =>
      searchTracks('trending music 2026', limit: limit);

  Future<List<Song>> getUndergroundTracks({int limit = 20}) =>
      searchTracks('underground music mix', limit: limit);

  // ── Mapper & Helpers ───────────────────────────────────────────────────────

  Song _videoToSong(SearchVideo v) {
    final parts  = v.title.split(' - ');
    final title  = parts.length >= 2 ? parts.sublist(1).join(' - ').trim() : v.title;
    final artist = parts.length >= 2 ? parts[0].trim() : v.author;
    return Song(
      youtubeVideoId:  v.id.value,
      title:           title,
      artist:          artist,
      durationSeconds: _parseDuration(v.duration),
      artworkUrl:      'https://i.ytimg.com/vi/${v.id.value}/hqdefault.jpg',
      createdAt:       DateTime.now(),
    );
  }

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

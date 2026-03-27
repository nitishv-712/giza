// lib/services/youtube_service.dart

import 'dart:io';
import 'package:dio/dio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/song.dart';

class YoutubeService {
  YoutubeService._();
  static final YoutubeService instance = YoutubeService._();

  final _yt = YoutubeExplode();
  final _dio = Dio(); // Used for downloading files

  // ── Streaming ──────────────────────────────────────────────────────────────

  /// Fetches the direct playable URL for an audio player.
  /// Use this URL in packages like just_audio or audioplayers.
  Future<String?> getBestAudioStreamLikeYtDlp(String videoId) async {
    try {
      // yt-dlp first gets the full manifest
      final manifest = await _yt.videos.streamsClient.getManifest(videoId);

      // yt-dlp logic: Prefer Opus (WebM) over AAC (M4A) for higher fidelity
      // and sort by bitrate descending.
      final streamInfo = manifest.audioOnly
          .where((s) => s.codec.mimeType == 'audio/webm') // Opus is usually in webm
          .toList();

      // If webm streams are found, get the highest bitrate one
      StreamInfo? finalStream;
      if (streamInfo.isNotEmpty) {
        finalStream = streamInfo.reduce((a, b) => 
          a.bitrate.bitsPerSecond > b.bitrate.bitsPerSecond ? a : b
        );
      } else {
        // Fall back to any highest bitrate audio
        finalStream = manifest.audioOnly.withHighestBitrate();
      }

      return finalStream.url.toString();
    } catch (e) {
      print('yt-dlp style fetch failed: $e');
      return null;
    }
  }

  // ── Downloading ────────────────────────────────────────────────────────────

  Future<void> downloadInFragments(
    String url,
    String savePath, {
    Function(double)? onProgress,
  }) async {
    // yt-dlp often downloads in 10MB chunks to prevent YouTube from throttling
    int chunkSize = 10 * 1024 * 1024;
    int start = 0;
    int totalDownloaded = 0;

    // First, get the total file size
    int? totalSize;
    try {
      final headResponse = await _dio.head(url);
      final contentLength = headResponse.headers.value('content-length');
      if (contentLength != null) {
        totalSize = int.parse(contentLength);
      }
    } catch (e) {
      print('Could not get file size: $e');
    }

    File file = File(savePath);
    if (file.existsSync()) {
      await file.delete();
    }
    var raf = await file.open(mode: FileMode.append);

    while (true) {
      try {
        final response = await _dio.get(
          url,
          options: Options(
            headers: {'Range': 'bytes=$start-${start + chunkSize - 1}'},
            responseType: ResponseType.bytes,
          ),
        );

        await raf.writeFrom(response.data);
        totalDownloaded += (response.data as List).length;

        // Report progress
        if (onProgress != null && totalSize != null) {
          final progress = totalDownloaded / totalSize;
          onProgress(progress.clamp(0.0, 1.0));
        }

        // If we received less than the chunk size, we are at the end of the file
        if ((response.data as List).length < chunkSize) {
          if (onProgress != null) {
            onProgress(1.0); // Ensure we report 100% at the end
          }
          break;
        }

        start += chunkSize;
        print("Downloaded: ${totalDownloaded / (1024 * 1024)} MB");
      } catch (e) {
        print('Download chunk error: $e');
        break;
      }
    }
    await raf.close();
    print('Download complete: $savePath (${totalDownloaded / (1024 * 1024)} MB)');
  }

  // ── Search ─────────────────────────────────────────────────────────────────

  Future<List<Song>> searchTracks(String query, {int limit = 30}) async {
    if (query.trim().isEmpty) return [];
    print('[YT] searching: "$query"');
    final results = await _yt.search.searchContent(query.trim());
    print('[YT] raw results: ${results.length} items');
    for (final r in results.take(5)) {
      print('[YT]   type=${r.runtimeType}  value=$r');
    }
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
    final parts = v.title.split(' - ');
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

  void dispose() {
    _yt.close();
    _dio.close();
  }
}
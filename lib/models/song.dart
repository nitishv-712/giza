// lib/models/song.dart
import 'package:hive/hive.dart';

part 'song.g.dart';

/// A track sourced from the Audius decentralized music network.
/// Audio is played via a YouTube IFrame (resolved by youtube_explode_dart).
@HiveType(typeId: 0)
class Song extends HiveObject {
  @HiveField(0)
  int? id;

  @HiveField(1)
  String? audiusTrackId;

  @HiveField(2)
  String title;

  @HiveField(3)
  String artist;

  @HiveField(4)
  String album;

  @HiveField(5)
  String genre;

  @HiveField(6)
  int durationSeconds;

  @HiveField(7)
  String artworkUrl;

  @HiveField(8)
  String streamUrl; // Audius stream URL (kept for metadata; audio via YouTube)

  @HiveField(9)
  String? localPath; // unused — no downloads

  @HiveField(10)
  bool isDownloaded; // always false — no downloads

  @HiveField(11)
  bool isFavourite;

  @HiveField(12)
  int playCount;

  @HiveField(13)
  DateTime? lastPlayedAt;

  @HiveField(14)
  DateTime createdAt;

  @HiveField(15)
  int? audiusPlayCount;

  @HiveField(16)
  int? repostCount;

  @HiveField(17)
  int? favouriteCount;

  @HiveField(18)
  String? tags;

  @HiveField(19)
  String? mood;

  @HiveField(20)
  bool isStreamable;

  Song({
    this.id,
    this.audiusTrackId,
    required this.title,
    required this.artist,
    this.album = '',
    this.genre = '',
    required this.durationSeconds,
    required this.artworkUrl,
    required this.streamUrl,
    this.localPath,
    this.isDownloaded = false,
    this.isFavourite = false,
    this.playCount = 0,
    this.lastPlayedAt,
    required this.createdAt,
    this.audiusPlayCount,
    this.repostCount,
    this.favouriteCount,
    this.tags,
    this.mood,
    this.isStreamable = true,
  });

  // ── Computed helpers ───────────────────────────────────────────────────────

  String get durationFormatted {
    final m = durationSeconds ~/ 60;
    final s = (durationSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  bool get canStream => isStreamable && streamUrl.isNotEmpty;

  String get formattedPlayCount {
    final c = audiusPlayCount ?? 0;
    if (c >= 1000000) return '${(c / 1000000).toStringAsFixed(1)}M';
    if (c >= 1000) return '${(c / 1000).toStringAsFixed(1)}K';
    return c.toString();
  }

  Song copyWith({
    int? id,
    String? audiusTrackId,
    String? title,
    String? artist,
    String? album,
    String? genre,
    int? durationSeconds,
    String? artworkUrl,
    String? streamUrl,
    String? localPath,
    bool? isDownloaded,
    bool? isFavourite,
    int? playCount,
    DateTime? lastPlayedAt,
    DateTime? createdAt,
    int? audiusPlayCount,
    int? repostCount,
    int? favouriteCount,
    String? tags,
    String? mood,
    bool? isStreamable,
  }) =>
      Song(
        id: id ?? this.id,
        audiusTrackId: audiusTrackId ?? this.audiusTrackId,
        title: title ?? this.title,
        artist: artist ?? this.artist,
        album: album ?? this.album,
        genre: genre ?? this.genre,
        durationSeconds: durationSeconds ?? this.durationSeconds,
        artworkUrl: artworkUrl ?? this.artworkUrl,
        streamUrl: streamUrl ?? this.streamUrl,
        localPath: localPath ?? this.localPath,
        isDownloaded: isDownloaded ?? this.isDownloaded,
        isFavourite: isFavourite ?? this.isFavourite,
        playCount: playCount ?? this.playCount,
        lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
        createdAt: createdAt ?? this.createdAt,
        audiusPlayCount: audiusPlayCount ?? this.audiusPlayCount,
        repostCount: repostCount ?? this.repostCount,
        favouriteCount: favouriteCount ?? this.favouriteCount,
        tags: tags ?? this.tags,
        mood: mood ?? this.mood,
        isStreamable: isStreamable ?? this.isStreamable,
      );

  @override
  String toString() =>
      'Song(audiusTrackId: $audiusTrackId, title: "$title", artist: "$artist")';
}

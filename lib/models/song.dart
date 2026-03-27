// lib/models/song.dart
import 'package:hive/hive.dart';

part 'song.g.dart';

@HiveType(typeId: 0)
class Song extends HiveObject {
  @HiveField(0)
  int? id;

  @HiveField(1)
  String? youtubeVideoId;

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
  bool isFavourite;

  @HiveField(12)
  bool isDownloaded;

  @HiveField(13)
  String? localPath;

  @HiveField(9)
  int playCount;

  @HiveField(10)
  DateTime? lastPlayedAt;

  @HiveField(11)
  DateTime createdAt;

  Song({
    this.id,
    this.youtubeVideoId,
    required this.title,
    required this.artist,
    this.album = '',
    this.genre = '',
    required this.durationSeconds,
    required this.artworkUrl,
    this.isFavourite = false,
    this.isDownloaded = false,
    this.localPath,
    this.playCount = 0,
    this.lastPlayedAt,
    required this.createdAt,
  });

  String get durationFormatted {
    final m = durationSeconds ~/ 60;
    final s = (durationSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Song copyWith({
    int? id,
    String? youtubeVideoId,
    String? title,
    String? artist,
    String? album,
    String? genre,
    int? durationSeconds,
    String? artworkUrl,
    bool? isFavourite,
    bool? isDownloaded,
    String? localPath,
    int? playCount,
    DateTime? lastPlayedAt,
    DateTime? createdAt,
  }) =>
      Song(
        id:              id              ?? this.id,
        youtubeVideoId:  youtubeVideoId  ?? this.youtubeVideoId,
        title:           title           ?? this.title,
        artist:          artist          ?? this.artist,
        album:           album           ?? this.album,
        genre:           genre           ?? this.genre,
        durationSeconds: durationSeconds ?? this.durationSeconds,
        artworkUrl:      artworkUrl      ?? this.artworkUrl,
        isFavourite:     isFavourite     ?? this.isFavourite,
        isDownloaded:    isDownloaded    ?? this.isDownloaded,
        localPath:       localPath       ?? this.localPath,
        playCount:       playCount       ?? this.playCount,
        lastPlayedAt:    lastPlayedAt    ?? this.lastPlayedAt,
        createdAt:       createdAt       ?? this.createdAt,
      );

  @override
  String toString() => 'Song(youtubeVideoId: $youtubeVideoId, title: "$title", artist: "$artist")';
}

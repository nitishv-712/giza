// lib/models/playlist.dart
import 'package:hive/hive.dart';

part 'playlist.g.dart';

@HiveType(typeId: 1)
class Playlist extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  List<String> songVideoIds;

  @HiveField(3)
  DateTime createdAt;

  @HiveField(4)
  DateTime updatedAt;

  Playlist({
    required this.id,
    required this.name,
    required this.songVideoIds,
    required this.createdAt,
    required this.updatedAt,
  });
}

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'song.dart';

class SongAdapter extends TypeAdapter<Song> {
  @override
  final int typeId = 0;

  @override
  Song read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };

    return Song(
      id:              fields[0] as int?,
      youtubeVideoId:  fields[1] as String?,
      title:           fields[2] as String,
      artist:          fields[3] as String,
      album:           fields[4] as String? ?? '',
      genre:           fields[5] as String? ?? '',
      durationSeconds: fields[6] as int,
      artworkUrl:      fields[7] as String,
      isFavourite:     fields[8] as bool? ?? false,
      playCount:       fields[9] as int? ?? 0,
      lastPlayedAt:    fields[10] as DateTime?,
      createdAt:       fields[11] as DateTime,
      isDownloaded:    fields[12] as bool? ?? false,
      localPath:       fields[13] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Song obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.youtubeVideoId)
      ..writeByte(2)
      ..write(obj.title)
      ..writeByte(3)
      ..write(obj.artist)
      ..writeByte(4)
      ..write(obj.album)
      ..writeByte(5)
      ..write(obj.genre)
      ..writeByte(6)
      ..write(obj.durationSeconds)
      ..writeByte(7)
      ..write(obj.artworkUrl)
      ..writeByte(8)
      ..write(obj.isFavourite)
      ..writeByte(9)
      ..write(obj.playCount)
      ..writeByte(10)
      ..write(obj.lastPlayedAt)
      ..writeByte(11)
      ..write(obj.createdAt)
      ..writeByte(12)
      ..write(obj.isDownloaded)
      ..writeByte(13)
      ..write(obj.localPath);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SongAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

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
      id: fields[0] as int?,
      audiusTrackId: fields[1] as String?,
      title: fields[2] as String,
      artist: fields[3] as String,
      album: fields[4] as String? ?? '',
      genre: fields[5] as String? ?? '',
      durationSeconds: fields[6] as int,
      artworkUrl: fields[7] as String,
      streamUrl: fields[8] as String,
      localPath: fields[9] as String?,
      isDownloaded: fields[10] as bool? ?? false,
      isFavourite: fields[11] as bool? ?? false,
      playCount: fields[12] as int? ?? 0,
      lastPlayedAt: fields[13] as DateTime?,
      createdAt: fields[14] as DateTime,
      audiusPlayCount: fields[15] as int?,
      repostCount: fields[16] as int?,
      favouriteCount: fields[17] as int?,
      tags: fields[18] as String?,
      mood: fields[19] as String?,
      isStreamable: fields[20] as bool? ?? true,
    );
  }

  @override
  void write(BinaryWriter writer, Song obj) {
    writer
      ..writeByte(21)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.audiusTrackId)
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
      ..write(obj.streamUrl)
      ..writeByte(9)
      ..write(obj.localPath)
      ..writeByte(10)
      ..write(obj.isDownloaded)
      ..writeByte(11)
      ..write(obj.isFavourite)
      ..writeByte(12)
      ..write(obj.playCount)
      ..writeByte(13)
      ..write(obj.lastPlayedAt)
      ..writeByte(14)
      ..write(obj.createdAt)
      ..writeByte(15)
      ..write(obj.audiusPlayCount)
      ..writeByte(16)
      ..write(obj.repostCount)
      ..writeByte(17)
      ..write(obj.favouriteCount)
      ..writeByte(18)
      ..write(obj.tags)
      ..writeByte(19)
      ..write(obj.mood)
      ..writeByte(20)
      ..write(obj.isStreamable);
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

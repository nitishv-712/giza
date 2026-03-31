// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'custom_theme.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CustomThemeAdapter extends TypeAdapter<CustomTheme> {
  @override
  final int typeId = 2;

  @override
  CustomTheme read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CustomTheme(
      id: fields[0] as String,
      name: fields[1] as String,
      backgroundColor: fields[2] as int,
      surfaceColor: fields[3] as int,
      surface2Color: fields[4] as int,
      accentColor: fields[5] as int,
      accent2Color: fields[6] as int,
      textPrimaryColor: fields[7] as int,
      textSecondaryColor: fields[8] as int,
      createdAt: fields[9] as DateTime,
      isDefault: fields[10] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, CustomTheme obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.backgroundColor)
      ..writeByte(3)
      ..write(obj.surfaceColor)
      ..writeByte(4)
      ..write(obj.surface2Color)
      ..writeByte(5)
      ..write(obj.accentColor)
      ..writeByte(6)
      ..write(obj.accent2Color)
      ..writeByte(7)
      ..write(obj.textPrimaryColor)
      ..writeByte(8)
      ..write(obj.textSecondaryColor)
      ..writeByte(9)
      ..write(obj.createdAt)
      ..writeByte(10)
      ..write(obj.isDefault);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomThemeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

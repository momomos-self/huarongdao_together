// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class GameRecordAdapter extends TypeAdapter<GameRecord> {
  @override
  final int typeId = 0;

  @override
  GameRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return GameRecord(
      difficulty: fields[0] as int,
      timeInDeciseconds: fields[1] as int,
      steps: fields[2] as int,
      date: fields[3] as DateTime,
      isMultiplayer: fields[4] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, GameRecord obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.difficulty)
      ..writeByte(1)
      ..write(obj.timeInDeciseconds)
      ..writeByte(2)
      ..write(obj.steps)
      ..writeByte(3)
      ..write(obj.date)
      ..writeByte(4)
      ..write(obj.isMultiplayer);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GameRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

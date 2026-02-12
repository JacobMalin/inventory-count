// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'export_entry.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ExportItemAdapter extends TypeAdapter<ExportItem> {
  @override
  final int typeId = 7;

  @override
  ExportItem read(BinaryReader reader) {
    final int numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ExportItem(fields[0] as String, isHidden: fields[1] as bool?);
  }

  @override
  void write(BinaryWriter writer, ExportItem obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.isHidden);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExportItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ExportTitleAdapter extends TypeAdapter<ExportTitle> {
  @override
  final int typeId = 9;

  @override
  ExportTitle read(BinaryReader reader) {
    final int numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ExportTitle(fields[0] as String, isHidden: fields[1] as bool?);
  }

  @override
  void write(BinaryWriter writer, ExportTitle obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.isHidden);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExportTitleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

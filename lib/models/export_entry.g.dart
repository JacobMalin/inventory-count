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
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ExportItem(
      fields[0] as String,
      paths: (fields[1] as List?)?.cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, ExportItem obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.paths);
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

class ExportPlaceholderAdapter extends TypeAdapter<ExportPlaceholder> {
  @override
  final int typeId = 8;

  @override
  ExportPlaceholder read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ExportPlaceholder(
      fields[0] as String,
    );
  }

  @override
  void write(BinaryWriter writer, ExportPlaceholder obj) {
    writer
      ..writeByte(1)
      ..writeByte(0)
      ..write(obj.name);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExportPlaceholderAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ExportTitleAdapter extends TypeAdapter<ExportTitle> {
  @override
  final int typeId = 9;

  @override
  ExportTitle read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ExportTitle(
      fields[0] as String,
    );
  }

  @override
  void write(BinaryWriter writer, ExportTitle obj) {
    writer
      ..writeByte(1)
      ..writeByte(0)
      ..write(obj.name);
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

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'area.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AreaAdapter extends TypeAdapter<Area> {
  @override
  final int typeId = 0;

  @override
  Area read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Area(
      fields[0] as String,
    );
  }

  @override
  void write(BinaryWriter writer, Area obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.colorInt)
      ..writeByte(2)
      ..write(obj.shelvesAndItems);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AreaAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ShelfAdapter extends TypeAdapter<Shelf> {
  @override
  final int typeId = 1;

  @override
  Shelf read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Shelf(
      fields[0] as String,
    );
  }

  @override
  void write(BinaryWriter writer, Shelf obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.shelvesAndItems);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShelfAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ItemAdapter extends TypeAdapter<Item> {
  @override
  final int typeId = 2;

  @override
  Item read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Item(
      fields[0] as String,
    )..count = fields[1] as int?;
  }

  @override
  void write(BinaryWriter writer, Item obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.count);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

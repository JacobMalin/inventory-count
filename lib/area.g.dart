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
      shelvesAndItems: (fields[2] as List?)?.cast<dynamic>(),
    );
  }

  @override
  void write(BinaryWriter writer, Area obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.shelvesAndItems)
      ..writeByte(1)
      ..write(obj.colorInt);
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
      items: (fields[1] as List?)?.cast<dynamic>(),
    );
  }

  @override
  void write(BinaryWriter writer, Shelf obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.items);
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
      count: fields[1] as int?,
      strategy: fields[2] as CountStrategy,
      strategyInt: fields[3] as int?,
      countName: fields[4] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Item obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.count)
      ..writeByte(2)
      ..write(obj.strategy)
      ..writeByte(3)
      ..write(obj.strategyInt)
      ..writeByte(4)
      ..write(obj.countName);
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

class CountStrategyAdapter extends TypeAdapter<CountStrategy> {
  @override
  final int typeId = 3;

  @override
  CountStrategy read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return CountStrategy.singular;
      case 1:
        return CountStrategy.boxes;
      case 2:
        return CountStrategy.singularAndBoxes;
      case 3:
        return CountStrategy.negative;
      default:
        return CountStrategy.singular;
    }
  }

  @override
  void write(BinaryWriter writer, CountStrategy obj) {
    switch (obj) {
      case CountStrategy.singular:
        writer.writeByte(0);
        break;
      case CountStrategy.boxes:
        writer.writeByte(1);
        break;
      case CountStrategy.singularAndBoxes:
        writer.writeByte(2);
        break;
      case CountStrategy.negative:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CountStrategyAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

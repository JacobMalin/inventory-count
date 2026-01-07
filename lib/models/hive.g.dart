// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hive.dart';

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
      strategy: fields[1] as CountStrategy?,
      strategyInt: fields[2] as int?,
      strategyInt2: fields[8] as int?,
      countName: fields[3] as String?,
      defaultCount: fields[4] as ItemCount?,
      countPhase: fields[5] as CountPhase?,
      personalCountPhase: fields[6] as CountPhase?,
      id: fields[7] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, Item obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.strategy)
      ..writeByte(2)
      ..write(obj.strategyInt)
      ..writeByte(8)
      ..write(obj.strategyInt2)
      ..writeByte(3)
      ..write(obj.countName)
      ..writeByte(4)
      ..write(obj.defaultCount)
      ..writeByte(5)
      ..write(obj.countPhase)
      ..writeByte(6)
      ..write(obj.personalCountPhase)
      ..writeByte(7)
      ..write(obj.id);
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

class CountEntryAdapter extends TypeAdapter<CountEntry> {
  @override
  final int typeId = 6;

  @override
  CountEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CountEntry(
      fields[0] as String,
      fields[1] as CountPhase,
      fields[2] as ItemCountType,
    );
  }

  @override
  void write(BinaryWriter writer, CountEntry obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.phase)
      ..writeByte(2)
      ..write(obj.countType);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CountEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CountAdapter extends TypeAdapter<Count> {
  @override
  final int typeId = 5;

  @override
  Count read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Count(
      itemCounts: (fields[0] as Map?)?.cast<int, CountEntry>(),
      countPhase: fields[1] as CountPhase?,
    );
  }

  @override
  void write(BinaryWriter writer, Count obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.itemCounts)
      ..writeByte(1)
      ..write(obj.countPhase);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CountAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

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
    return ExportPlaceholder(fields[0] as String);
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
    return ExportTitle(fields[0] as String);
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

class ItemCountAdapter extends TypeAdapter<ItemCount> {
  @override
  final int typeId = 10;

  @override
  ItemCount read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ItemCount(
      fields[5] as CountStrategy,
      fields[3] as int?,
      fields[4] as int?,
      field1: fields[0] as int?,
      field2: fields[1] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, ItemCount obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.field1)
      ..writeByte(1)
      ..write(obj.field2)
      ..writeByte(3)
      ..write(obj.modifier1)
      ..writeByte(4)
      ..write(obj.modifier2)
      ..writeByte(5)
      ..write(obj.strategy);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ItemCountAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ItemNotCountedAdapter extends TypeAdapter<ItemNotCounted> {
  @override
  final int typeId = 11;

  @override
  ItemNotCounted read(BinaryReader reader) {
    return ItemNotCounted();
  }

  @override
  void write(BinaryWriter writer, ItemNotCounted obj) {
    writer
      ..writeByte(1)
      ..writeByte(0)
      ..write(obj.notCounted);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ItemNotCountedAdapter &&
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
        return CountStrategy.stacks;
      case 2:
        return CountStrategy.boxesAndStacks;
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
      case CountStrategy.stacks:
        writer.writeByte(1);
        break;
      case CountStrategy.boxesAndStacks:
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

class CountPhaseAdapter extends TypeAdapter<CountPhase> {
  @override
  final int typeId = 4;

  @override
  CountPhase read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return CountPhase.back;
      case 1:
        return CountPhase.cabinet;
      case 2:
        return CountPhase.out;
      default:
        return CountPhase.back;
    }
  }

  @override
  void write(BinaryWriter writer, CountPhase obj) {
    switch (obj) {
      case CountPhase.back:
        writer.writeByte(0);
        break;
      case CountPhase.cabinet:
        writer.writeByte(1);
        break;
      case CountPhase.out:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CountPhaseAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

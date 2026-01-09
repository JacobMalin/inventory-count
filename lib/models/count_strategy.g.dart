// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'count_strategy.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SingularCountStrategyAdapter extends TypeAdapter<SingularCountStrategy> {
  @override
  final int typeId = 12;

  @override
  SingularCountStrategy read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SingularCountStrategy(
      placeholder: fields[0] as bool?,
    );
  }

  @override
  void write(BinaryWriter writer, SingularCountStrategy obj) {
    writer
      ..writeByte(1)
      ..writeByte(0)
      ..write(obj.placeholder);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SingularCountStrategyAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class NegativeCountStrategyAdapter extends TypeAdapter<NegativeCountStrategy> {
  @override
  final int typeId = 13;

  @override
  NegativeCountStrategy read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return NegativeCountStrategy(
      fields[0] as int,
    );
  }

  @override
  void write(BinaryWriter writer, NegativeCountStrategy obj) {
    writer
      ..writeByte(1)
      ..writeByte(0)
      ..write(obj.from);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NegativeCountStrategyAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class StacksCountStrategyAdapter extends TypeAdapter<StacksCountStrategy> {
  @override
  final int typeId = 14;

  @override
  StacksCountStrategy read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return StacksCountStrategy(
      fields[0] as int,
    );
  }

  @override
  void write(BinaryWriter writer, StacksCountStrategy obj) {
    writer
      ..writeByte(1)
      ..writeByte(0)
      ..write(obj.perStack);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StacksCountStrategyAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class BoxesAndStacksCountStrategyAdapter
    extends TypeAdapter<BoxesAndStacksCountStrategy> {
  @override
  final int typeId = 15;

  @override
  BoxesAndStacksCountStrategy read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BoxesAndStacksCountStrategy(
      fields[0] as int,
      fields[1] as int,
    );
  }

  @override
  void write(BinaryWriter writer, BoxesAndStacksCountStrategy obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.perBox)
      ..writeByte(1)
      ..write(obj.perStack);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BoxesAndStacksCountStrategyAdapter &&
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
      fields[2] as CountStrategy,
      field1: fields[0] as int?,
      field2: fields[1] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, ItemCount obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.field1)
      ..writeByte(1)
      ..write(obj.field2)
      ..writeByte(2)
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
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ItemNotCounted(
      placeholder: fields[0] as bool?,
    );
  }

  @override
  void write(BinaryWriter writer, ItemNotCounted obj) {
    writer
      ..writeByte(1)
      ..writeByte(0)
      ..write(obj.placeholder);
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

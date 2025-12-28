import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

part 'area.g.dart';

@HiveType(typeId: 0)
class Area extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  int get colorInt =>
      Colors.primaries[name.hashCode % Colors.primaries.length].toARGB32();

  @HiveField(2)
  List shelvesAndItems;

  Color get color => Color(colorInt);

  Area(this.name, {List? shelvesAndItems})
    : shelvesAndItems = shelvesAndItems ?? [];
}

@HiveType(typeId: 1)
class Shelf extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  List items;

  Shelf(this.name, {List? items}) : items = items ?? [];
}

@HiveType(typeId: 2)
class Item extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  int? count;

  @HiveField(2)
  CountStrategy strategy;

  @HiveField(3)
  int? strategyInt;

  @HiveField(4)
  String? countName;

  Item(
    this.name, {
    this.count,
    this.strategy = CountStrategy.singular,
    this.strategyInt,
    this.countName,
  });
}

@HiveType(typeId: 3)
enum CountStrategy {
  @HiveField(0)
  singular,

  @HiveField(1)
  boxes,

  @HiveField(2)
  singularAndBoxes,

  @HiveField(3)
  negative,
}

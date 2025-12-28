import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

part 'area.g.dart';

@HiveType(typeId: 0)
class Area extends HiveObject {
  @HiveField(0)
  final String name;

  @HiveField(1)
  final int colorInt;

  @HiveField(2)
  final List shelvesAndItems = [];

  Color get color => Color(colorInt);

  Area(this.name)
    : colorInt = Colors.primaries[name.hashCode % Colors.primaries.length]
          .toARGB32();
}

@HiveType(typeId: 1)
class Shelf extends HiveObject {
  @HiveField(0)
  final String name;

  @HiveField(1)
  final List shelvesAndItems = [];

  Shelf(this.name);
}

@HiveType(typeId: 2)
class Item extends HiveObject {
  @HiveField(0)
  final String name;

  @HiveField(1)
  int? count;

  Item(this.name);
}

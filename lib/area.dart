import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

part 'area.g.dart';

@HiveType(typeId: 0)
class Area extends HiveObject {
  @HiveField(0)
  final String name;

  @HiveField(1)
  final int colorInt;

  Color get color => Color(colorInt);

  Area(this.name)
    : colorInt = Colors.primaries[name.hashCode % Colors.primaries.length]
          .toARGB32();
}

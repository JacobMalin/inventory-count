import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

part 'hive.g.dart';

Future<void> hiveSetup() async {
  await Hive.initFlutter('inventory_count');

  Hive.registerAdapter<Area>(AreaAdapter());
  Hive.registerAdapter<Shelf>(ShelfAdapter());
  Hive.registerAdapter<Item>(ItemAdapter());
  Hive.registerAdapter<CountStrategy>(CountStrategyAdapter());
  Hive.registerAdapter<CountPhase>(CountPhaseAdapter());
  Hive.registerAdapter<Count>(CountAdapter());
  Hive.registerAdapter<ExportItem>(ExportItemAdapter());
  Hive.registerAdapter<ExportPlaceholder>(ExportPlaceholderAdapter());
  Hive.registerAdapter<ExportTitle>(ExportTitleAdapter());
  Hive.registerAdapter<ItemCount>(ItemCountAdapter());
  Hive.registerAdapter<ItemNotCounted>(ItemNotCountedAdapter());
  Hive.registerAdapter<CountEntry>(CountEntryAdapter());

  await Hive.openBox('areas');
  await Hive.openBox('counts');
  await Hive.openBox('settings');
}

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

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'shelvesAndItems': shelvesAndItems.map((item) {
        if (item is Shelf) {
          return {'type': 'shelf', 'data': item.toJson()};
        } else if (item is Item) {
          return {'type': 'item', 'data': item.toJson()};
        }
        return null;
      }).toList(),
    };
  }

  static Area fromJson(Map<String, dynamic> json) {
    final shelvesAndItems = (json['shelvesAndItems'] as List? ?? [])
        .map((item) {
          if (item['type'] == 'shelf') {
            return Shelf.fromJson(item['data']);
          } else if (item['type'] == 'item') {
            return Item.fromJson(item['data']);
          }
          return null;
        })
        .where((item) => item != null)
        .toList();
    return Area(json['name'], shelvesAndItems: shelvesAndItems);
  }
}

@HiveType(typeId: 1)
class Shelf extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  List items;

  Shelf(this.name, {List? items}) : items = items ?? [];

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'items': items.map((item) => (item as Item).toJson()).toList(),
    };
  }

  static Shelf fromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List? ?? [])
        .map((item) => Item.fromJson(item))
        .toList();
    return Shelf(json['name'], items: items);
  }
}

@HiveType(typeId: 2)
class Item extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  CountStrategy strategy;

  @HiveField(2)
  int? strategyInt;

  @HiveField(8)
  int? strategyInt2;

  @HiveField(3)
  String? countName;

  @HiveField(4)
  int? defaultCount;

  @HiveField(5)
  CountPhase countPhase;

  @HiveField(6)
  CountPhase? personalCountPhase;

  @HiveField(7)
  int id;

  Item(
    this.name, {
    CountStrategy? strategy,
    this.strategyInt,
    this.strategyInt2,
    this.countName,
    this.defaultCount,
    CountPhase? countPhase,
    this.personalCountPhase,
    int? id,
  }) : strategy = strategy ?? CountStrategy.singular,
       countPhase = countPhase ?? CountPhase.back,
       id = id ?? _generateId();

  static int _generateId() {
    var newId = Hive.box('areas').get('itemIdCounter', defaultValue: 0);
    Hive.box('areas').put('itemIdCounter', newId + 1);
    return newId;
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'strategy': strategy.index,
      'strategyInt': strategyInt,
      'strategyInt2': strategyInt2,
      'countName': countName,
      'defaultCount': defaultCount,
      'countPhase': countPhase.index,
      'personalCountPhase': personalCountPhase?.index,
      'id': id,
    };
  }

  static Item fromJson(Map<String, dynamic> json) {
    return Item(
      json['name'],
      strategy: CountStrategy.values[json['strategy'] ?? 0],
      strategyInt: json['strategyInt'],
      strategyInt2: json['strategyInt2'],
      countName: json['countName'],
      defaultCount: json['defaultCount'],
      countPhase: CountPhase.values[json['countPhase'] ?? 0],
      personalCountPhase: json['personalCountPhase'] != null
          ? CountPhase.values[json['personalCountPhase']]
          : null,
      id: json['id'],
    );
  }
}

@HiveType(typeId: 3)
enum CountStrategy {
  @HiveField(0)
  singular,

  @HiveField(1)
  stacks,

  @HiveField(2)
  boxesAndStacks,

  @HiveField(3)
  negative,
}

@HiveType(typeId: 4)
enum CountPhase {
  @HiveField(0)
  back,

  @HiveField(1)
  cabinet,

  @HiveField(2)
  out,
}

@HiveType(typeId: 6)
class CountEntry extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  CountPhase phase;

  @HiveField(2)
  ItemCountType countType;

  CountEntry(this.name, this.phase, this.countType);
}

@HiveType(typeId: 5)
class Count extends HiveObject {
  @HiveField(0)
  final Map<int, CountEntry> itemCounts;

  @HiveField(1)
  CountPhase countPhase = CountPhase.back;

  Count({Map<int, CountEntry>? itemCounts, CountPhase? countPhase})
    : itemCounts = itemCounts ?? {},
      countPhase = countPhase ?? CountPhase.back;

  ItemCountType? getCount(Item data) {
    return itemCounts[data.id]?.countType;
  }

  void setCount(Item data, ItemCountType? count) {
    if (count == null || (count is ItemCount && count.isEmpty())) {
      itemCounts.remove(data.id);
      return;
    }

    itemCounts[data.id] = CountEntry(
      data.countName ?? data.name,
      data.countPhase,
      count,
    );
  }

  void setNotCounted(Item data) {
    itemCounts[data.id] = CountEntry(
      data.countName ?? data.name,
      data.countPhase,
      ItemNotCounted(),
    );
  }

  int? getCountValueByName(String name, CountPhase phase) {
    int total = 0;
    bool isValue = false;

    for (final MapEntry<int, CountEntry> entry in itemCounts.entries) {
      if (entry.value.countType is ItemNotCounted) return -1;

      final ItemCount itemCount = entry.value.countType as ItemCount;
      if (entry.value.name == name && entry.value.phase == phase) {
        isValue = true;
        total += itemCount.count ?? 0;
      }
    }
    return isValue ? total : null;
  }

  void updateCountForItem(Item data) {
    if (!itemCounts.containsKey(data.id)) {
      return;
    }

    final existingEntry = itemCounts[data.id]!;
    ItemCountType existingCountType = existingEntry.countType;

    if (existingCountType is ItemCount) {
      existingCountType = ItemCount(
        data.strategy,
        data.strategyInt,
        data.strategyInt2,
        field1: existingCountType.field1,
        field2: existingCountType.field2,
      );
    }

    itemCounts[data.id] = CountEntry(
      data.countName ?? data.name,
      data.countPhase,
      existingCountType,
    );
  }
}

@HiveType(typeId: 7)
class ExportItem extends HiveObject implements ExportEntry {
  @override
  @HiveField(0)
  String name;

  @HiveField(1)
  List<String> paths;

  ExportItem(this.name, {List<String>? paths}) : paths = paths ?? [];

  @override
  Map<String, dynamic> toJson() {
    return {'type': 'ExportItem', 'name': name, 'paths': paths};
  }

  static ExportItem fromJson(Map<String, dynamic> json) {
    return ExportItem(
      json['name'],
      paths: List<String>.from(json['paths'] ?? []),
    );
  }
}

@HiveType(typeId: 8)
class ExportPlaceholder extends HiveObject implements ExportEntry {
  @override
  @HiveField(0)
  String name;

  ExportPlaceholder(this.name);

  @override
  Map<String, dynamic> toJson() {
    return {'type': 'ExportPlaceholder', 'name': name};
  }

  static ExportPlaceholder fromJson(Map<String, dynamic> json) {
    return ExportPlaceholder(json['name']);
  }
}

@HiveType(typeId: 9)
class ExportTitle extends HiveObject implements ExportEntry {
  @override
  @HiveField(0)
  String name;

  ExportTitle(this.name);

  @override
  Map<String, dynamic> toJson() {
    return {'type': 'ExportTitle', 'name': name};
  }

  static ExportTitle fromJson(Map<String, dynamic> json) {
    return ExportTitle(json['name']);
  }
}

// Base class for type checking (not stored in Hive)
abstract class ExportEntry {
  String get name;
  set name(String value);

  Map<String, dynamic> toJson();
}

@HiveType(typeId: 10)
class ItemCount extends HiveObject implements ItemCountType {
  @HiveField(0)
  int? field1;

  @HiveField(1)
  int? field2;

  @HiveField(3)
  int? modifier1;

  @HiveField(4)
  int? modifier2;

  @HiveField(5)
  CountStrategy strategy;

  int? get count {
    if (isEmpty()) {
      return null;
    }

    switch (strategy) {
      case CountStrategy.singular:
        return field1!;
      case CountStrategy.negative:
        return (modifier1 ?? 0) - field1!;
      case CountStrategy.stacks:
        return field1! * (modifier1 ?? 1);
      case CountStrategy.boxesAndStacks:
        return ((field1 ?? 0) * (modifier1 ?? 1) + (field2 ?? 0)) *
            (modifier2 ?? 1);
    }
  }

  bool isCounted() {
    return count != null;
  }

  bool isEmpty() {
    switch (strategy) {
      case CountStrategy.singular:
      case CountStrategy.negative:
      case CountStrategy.stacks:
        return field1 == null;
      case CountStrategy.boxesAndStacks:
        return field1 == null && field2 == null;
    }
  }

  ItemCount(
    this.strategy,
    this.modifier1,
    this.modifier2, {
    this.field1,
    this.field2,
  });
}

@HiveType(typeId: 11)
class ItemNotCounted extends HiveObject implements ItemCountType {}

abstract class ItemCountType extends HiveObject {}

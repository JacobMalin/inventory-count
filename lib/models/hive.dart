import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:inventory_count/models/count_strategy.dart';
import 'package:inventory_count/models/export_entry.dart';

part 'hive.g.dart';

Future<void> hiveSetup() async {
  await Hive.initFlutter('inventory_count');

  Hive.registerAdapter<Area>(AreaAdapter());
  Hive.registerAdapter<Shelf>(ShelfAdapter());
  Hive.registerAdapter<Item>(ItemAdapter());
  Hive.registerAdapter<CountPhase>(CountPhaseAdapter());
  Hive.registerAdapter<Count>(CountAdapter());
  Hive.registerAdapter<CountEntry>(CountEntryAdapter());

  registerCountStrategyAdapters();
  registerExportEntryAdapters();

  await Hive.openBox('areas');
  await Hive.openBox<Count>('counts');
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
          if (item == null || item is! Map<String, dynamic>) return null;
          try {
            if (item['type'] == 'shelf') {
              return Shelf.fromJson(item['data'] as Map<String, dynamic>);
            } else if (item['type'] == 'item') {
              return Item.fromJson(item['data'] as Map<String, dynamic>);
            }
          } catch (e) {
            return null;
          }
          return null;
        })
        .where((item) => item != null)
        .toList();
    return Area(
      json['name'] as String? ?? '',
      shelvesAndItems: shelvesAndItems,
    );
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
        .where((item) => item != null && item is Map<String, dynamic>)
        .map((item) {
          try {
            return Item.fromJson(item as Map<String, dynamic>);
          } catch (e) {
            return null;
          }
        })
        .where((item) => item != null)
        .cast<Item>()
        .toList();
    return Shelf(json['name'] as String? ?? '', items: items);
  }
}

@HiveType(typeId: 2)
class Item extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  CountStrategy strategy;

  @HiveField(3)
  String? countName;

  @HiveField(4)
  ItemCount? defaultCount;

  @HiveField(5)
  CountPhase countPhase;

  @HiveField(6)
  CountPhase? personalCountPhase;

  @HiveField(7)
  int id;

  Item(
    this.name, {
    CountStrategy? strategy,
    this.countName,
    this.defaultCount,
    CountPhase? countPhase,
    this.personalCountPhase,
    int? id,
  }) : strategy = strategy ?? SingularCountStrategy(),
       countPhase = countPhase ?? CountPhase.back,
       id = id ?? _generateId();

  static int _generateId() {
    try {
      if (!Hive.isBoxOpen('areas')) {
        return 0;
      }
      final box = Hive.box('areas');
      final newId = box.get('itemIdCounter', defaultValue: 0) as int;
      box.put('itemIdCounter', newId + 1);
      return newId;
    } catch (e) {
      return 0;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'strategy': strategy.toJson(),
      'countName': countName,
      'defaultCount': defaultCount?.toJson(),
      'countPhase': countPhase.index,
      'personalCountPhase': personalCountPhase?.index,
      'id': id,
    };
  }

  static Item fromJson(Map<String, dynamic> json) {
    try {
      final countPhaseIndex = json['countPhase'] ?? 0;
      final personalCountPhaseIndex = json['personalCountPhase'];

      CountStrategy? strategy;
      if (json['strategy'] != null) {
        try {
          if (json['strategy'] is Map<String, dynamic>) {
            strategy = CountStrategy.fromJson(
              json['strategy'] as Map<String, dynamic>,
            );
          }
        } catch (e) {
          // If strategy parsing fails, use default
          strategy = null;
        }
      }

      ItemCount? defaultCount;
      if (json['defaultCount'] != null) {
        try {
          if (json['defaultCount'] is Map<String, dynamic>) {
            defaultCount = ItemCount.fromJson(
              json['defaultCount'] as Map<String, dynamic>,
            );
          }
        } catch (e) {
          // If defaultCount parsing fails, use null
          defaultCount = null;
        }
      }

      return Item(
        json['name'] as String? ?? '',
        strategy: strategy,
        countName: json['countName'] as String?,
        defaultCount: defaultCount,
        countPhase:
            countPhaseIndex >= 0 && countPhaseIndex < CountPhase.values.length
            ? CountPhase.values[countPhaseIndex]
            : CountPhase.back,
        personalCountPhase:
            personalCountPhaseIndex != null &&
                personalCountPhaseIndex >= 0 &&
                personalCountPhaseIndex < CountPhase.values.length
            ? CountPhase.values[personalCountPhaseIndex]
            : null,
        id: json['id'] as int?,
      );
    } catch (e) {
      // If anything fails, return a basic item with the name
      return Item(json['name'] as String? ?? 'Unknown Item');
    }
  }
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
      final ItemCountType itemCountType = entry.value.countType;
      if (entry.value.name == name && entry.value.phase == phase) {
        if (itemCountType is ItemNotCounted) return -1;

        isValue = true;
        total += (itemCountType as ItemCount).count ?? 0;
      }
    }
    return isValue ? total : null;
  }

  String? getCountSumNotationByName(String name, CountPhase phase) {
    List<String> notations = [];

    for (final MapEntry<int, CountEntry> entry in itemCounts.entries) {
      final ItemCountType itemCountType = entry.value.countType;
      if (entry.value.name == name && entry.value.phase == phase) {
        if (itemCountType is ItemNotCounted) {
          notations.add('-');
        } else if (itemCountType is ItemCount) {
          notations.add(itemCountType.count.toString());
        }
      }
    }

    if (notations.isEmpty) {
      return null;
    }

    return notations.join(' + ');
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

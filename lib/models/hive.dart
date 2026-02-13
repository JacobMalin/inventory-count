import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'count_strategy.dart';
import 'export_entry.dart';
import 'export_model.dart';
import 'material_default_icons.dart';

part 'hive.g.dart';

Future<void> hiveSetup() async {
  await Hive.initFlutter('inventory_count');

  Hive
    ..registerAdapter<Area>(AreaAdapter())
    ..registerAdapter<Shelf>(ShelfAdapter())
    ..registerAdapter<Item>(ItemAdapter())
    ..registerAdapter<CountPhase>(CountPhaseAdapter())
    ..registerAdapter<Count>(CountAdapter())
    ..registerAdapter<CountEntry>(CountEntryAdapter())
    ..registerAdapter<Profile>(ProfileAdapter());

  registerCountStrategyAdapters();
  registerExportEntryAdapters();

  await Hive.openBox('areas');
  await Hive.openBox<Count>('counts');
  await Hive.openBox('settings');
}

abstract class StorageObject extends HiveObject {
  String get name;
  set name(String value);

  Map<String, dynamic> toJson();
}

@HiveType(typeId: 0)
class Area extends StorageObject {
  Area(this.name, {List<StorageObject>? shelvesAndItems})
    : shelvesAndItems = shelvesAndItems ?? [];

  factory Area.fromJson(Map<String, dynamic> json) {
    return Area(
      json['name'] as String? ?? '',
      shelvesAndItems: (json['shelvesAndItems'] as List? ?? [])
          .map((item) {
            if (item == null || item is! Map<String, dynamic>) return null;
            try {
              if (item['type'] == 'shelf') {
                return Shelf.fromJson(item['data'] as Map<String, dynamic>);
              } else if (item['type'] == 'item') {
                return Item.fromJson(item['data'] as Map<String, dynamic>);
              }
            } on Exception catch (_) {
              return null;
            }
            return null;
          })
          .where((item) => item != null)
          .cast<StorageObject>()
          .toList(),
    );
  }

  @override
  @HiveField(0)
  String name;

  @HiveField(1)
  // @Deprecated('Used to be colorInt, but was not used')
  bool get _deprecated => false;

  @HiveField(2)
  List<StorageObject> shelvesAndItems;

  Color get color => Color(
    Colors.primaries[name.hashCode % Colors.primaries.length].toARGB32(),
  );

  @override
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
}

@HiveType(typeId: 1)
class Shelf extends StorageObject {
  Shelf(this.name, {List<Item>? items}) : items = items ?? [];

  factory Shelf.fromJson(Map<String, dynamic> json) {
    return Shelf(
      json['name'] as String? ?? '',
      items: (json['items'] as List? ?? [])
          .where((item) => item != null && item is Map<String, dynamic>)
          .map((item) {
            try {
              return Item.fromJson(item as Map<String, dynamic>);
            } on Exception catch (_) {
              return null;
            }
          })
          .where((item) => item != null)
          .cast<Item>()
          .toList(),
    );
  }

  @override
  @HiveField(0)
  String name;

  @HiveField(1)
  List<Item> items;

  @override
  Map<String, dynamic> toJson() {
    return {'name': name, 'items': items.map((item) => item.toJson()).toList()};
  }
}

@HiveType(typeId: 2)
class Item extends StorageObject {
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

  factory Item.fromJson(Map<String, dynamic> json) {
    try {
      final int countPhaseIndex = json['countPhase'] ?? 0;
      final int? personalCountPhaseIndex = json['personalCountPhase'];

      CountStrategy? strategy;
      if (json['strategy'] != null) {
        try {
          if (json['strategy'] is Map<String, dynamic>) {
            strategy = CountStrategy.fromJson(
              json['strategy'] as Map<String, dynamic>,
            );
          }
        } on Exception catch (_) {
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
        } on Exception catch (_) {
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
    } on Exception catch (_) {
      // If anything fails, return a basic item with the name
      return Item(json['name'] as String? ?? 'Unknown Item');
    }
  }

  @override
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

  @HiveField(2)
  int id;

  bool getIsValid(ExportModel exportModel) =>
      exportModel.contains(countName ?? name);

  static int _generateId() {
    try {
      if (!Hive.isBoxOpen('areas')) {
        return 0;
      }
      final Box box = Hive.box('areas');
      final newId = box.get('itemIdCounter', defaultValue: 0) as int;
      unawaited(box.put('itemIdCounter', newId + 1));
      return newId;
    } on Exception catch (_) {
      return 0;
    }
  }

  @override
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

  String get defaultButtonText {
    if (strategy is NegativeCountStrategy) {
      return ': ${(strategy as NegativeCountStrategy).from}';
    }

    if (defaultCount != null) {
      return ': ${defaultCount!.count}';
    }

    return '';
  }
}

@HiveType(typeId: 4)
enum CountPhase {
  @HiveField(0)
  back,

  @HiveField(1)
  cabinet,

  @HiveField(2)
  out;

  String get name {
    switch (this) {
      case CountPhase.back:
        return 'Back';
      case CountPhase.cabinet:
        return 'Cabinet';
      case CountPhase.out:
        return 'Out';
    }
  }
}

@HiveType(typeId: 6)
class CountEntry extends HiveObject {
  CountEntry(this.name, this.phase, this.countType);

  factory CountEntry.fromJson(Map<String, dynamic> json) {
    final String name = json['name'] as String? ?? '';
    final int phaseIndex = json['phase'] as int? ?? 0;
    final CountPhase phase =
        (phaseIndex >= 0 && phaseIndex < CountPhase.values.length)
        ? CountPhase.values[phaseIndex]
        : CountPhase.back;

    final countType = ItemCountType.fromJson(json['countType']);

    return CountEntry(name, phase, countType);
  }

  @HiveField(0)
  String name;

  @HiveField(1)
  CountPhase phase;

  @HiveField(2)
  ItemCountType countType;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phase': phase.index,
      'countType': countType.toJson(),
    };
  }
}

@HiveType(typeId: 5)
class Count extends HiveObject {
  Count({
    Map<int, CountEntry>? itemCounts,
    CountPhase? countPhase,
    Map<String, bool>? itemsToFix,
    this.profile,
  }) : itemCounts = itemCounts ?? <int, CountEntry>{},
       countPhase = countPhase ?? CountPhase.back,
       itemsToFix = itemsToFix ?? <String, bool>{};

  factory Count.fromJson(Map<String, dynamic> json) {
    final int phaseIndex = json['countPhase'] as int? ?? 0;
    final CountPhase phase =
        (phaseIndex >= 0 && phaseIndex < CountPhase.values.length)
        ? CountPhase.values[phaseIndex]
        : CountPhase.back;

    final itemsToFixRaw = json['itemsToFix'] as Map<String, dynamic>?;
    final Map<String, bool> itemsToFix = itemsToFixRaw != null
        ? itemsToFixRaw.map((k, v) => MapEntry(k, v as bool))
        : <String, bool>{};

    final List<dynamic> itemCountsList =
        (json['itemCounts'] as List<dynamic>?) ?? [];
    final Map<int, CountEntry> itemCountsMap = {};
    for (final element in itemCountsList) {
      if (element is Map<String, dynamic>) {
        final itemId = element['itemId'] as int?;
        final entryJson = element['entry'] as Map<String, dynamic>?;
        if (itemId != null && entryJson != null) {
          try {
            final entry = CountEntry.fromJson(entryJson);
            itemCountsMap[itemId] = entry;
          } on Exception catch (_) {
            // skip malformed entries
          }
        }
      }
    }

    return Count(
      itemCounts: itemCountsMap,
      countPhase: phase,
      itemsToFix: itemsToFix,
    );
  }

  @HiveField(0)
  final Map<int, CountEntry> itemCounts;

  @HiveField(1)
  CountPhase countPhase = CountPhase.back;

  @HiveField(2)
  Map<String, bool> itemsToFix = {};

  @HiveField(3)
  Profile? profile;

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
    var total = 0;
    var isValue = false;

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
    final List<String> notations = [];

    for (final MapEntry<int, CountEntry> entry in itemCounts.entries) {
      final ItemCountType itemCountType = entry.value.countType;
      if (entry.value.name == name && entry.value.phase == phase) {
        if (itemCountType is ItemNotCounted) {
          notations.add('-');
        } else if (itemCountType is ItemCount) {
          notations.add(
            itemCountType.doubleChecked
                ? '${itemCountType.count} ✓'
                : '${itemCountType.count}',
          );
        }
      }
    }

    if (notations.isEmpty) {
      return null;
    }

    return notations.join(' + ');
  }

  Map<String, dynamic> getItemExportJson(String countName) {
    final Map<String, dynamic> exportData = {};

    for (final CountPhase phase in CountPhase.values) {
      exportData[phase.name] = getCountSumNotationByName(countName, phase);
    }

    int? backCount = getCountValueByName(countName, CountPhase.back);
    int? cabinetCount = getCountValueByName(countName, CountPhase.cabinet);
    int? outCount = getCountValueByName(countName, CountPhase.out);

    final backIsNotCounted = backCount == -1;
    final cabinetIsNotCounted = cabinetCount == -1;
    final outIsNotCounted = outCount == -1;

    if (backIsNotCounted) {
      backCount = null;
    }
    if (cabinetIsNotCounted) {
      cabinetCount = null;
    }
    if (outIsNotCounted) {
      outCount = null;
    }

    // Calculate total
    final bool anyNotCounted =
        backIsNotCounted || cabinetIsNotCounted || outIsNotCounted;
    final bool hasAnyValue =
        (!backIsNotCounted && backCount != null) ||
        (!cabinetIsNotCounted && cabinetCount != null) ||
        (!outIsNotCounted && outCount != null);

    final String totalStr;
    if (hasAnyValue) {
      final int total =
          (backCount ?? 0) + (cabinetCount ?? 0) + (outCount ?? 0);
      totalStr = total.toString();
    } else if (anyNotCounted) {
      totalStr = '-';
    } else {
      totalStr = '';
    }

    exportData['Total'] = totalStr;

    return exportData;
  }

  void updateCountForItem(Item data) {
    if (!itemCounts.containsKey(data.id)) {
      return;
    }

    final CountEntry existingEntry = itemCounts[data.id]!;
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

  Map<String, dynamic> toJson() {
    return {
      'countPhase': countPhase.index,
      'itemsToFix': itemsToFix,
      'itemCounts': itemCounts.entries.map((e) {
        return {'itemId': e.key, 'entry': e.value.toJson()};
      }).toList(),
    };
  }
}

@HiveType(typeId: 16)
class Profile extends HiveObject {
  Profile(this.name);

  @HiveField(0)
  final String name;

  Color get color => Color(
    Colors.primaries[name.hashCode % Colors.primaries.length].toARGB32(),
  );

  IconData get icon {
    return defaultIcons.values
        .elementAt(name.hashCode % defaultIcons.length)
        .data;
  }

  @override
  // Cannot be made immutable because of Hive
  // ignore: avoid_equals_and_hash_code_on_mutable_classes
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Profile && other.name == name;
  }

  @override
  // Cannot be made immutable because of Hive
  // ignore: avoid_equals_and_hash_code_on_mutable_classes
  int get hashCode => name.hashCode;
}

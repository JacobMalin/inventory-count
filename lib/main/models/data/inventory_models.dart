import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/types/json.dart';
import '../export_model.dart';
import 'count_strategy.dart';
import 'export_entry.dart';
import 'material_default_icons.dart';

part 'inventory_models.g.dart';

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

  String get path;
  List<TextSpan> get richPath;

  Json toJson();
}

String _nameWithDuplicateSuffix(String name, int duplicateOrder) {
  return duplicateOrder <= 1 ? name : '$name$duplicateOrder';
}

@HiveType(typeId: 0)
class Area extends StorageObject {
  Area(
    this.name, {
    int duplicateOrder = 1,
    List<StorageObject>? shelvesAndItems,
  }) : _duplicateOrder = duplicateOrder,
       _shelvesAndItems = shelvesAndItems ?? [];

  factory Area.fromJson(Json json) {
    final area = Area(
      json['name'] as String? ?? '',
      duplicateOrder: json['duplicateOrder'] as int? ?? 1,
    );

    for (final Json item in json['shelvesAndItems'] as List? ?? []) {
      try {
        if (item['type'] == 'shelf') {
          area._shelvesAndItems.add(
            Shelf._fromJson(item['data'] as Json, area),
          );
        } else if (item['type'] == 'item') {
          area._shelvesAndItems.add(Item._fromJson(item['data'] as Json, area));
        }
      } on Exception catch (e) {
        if (kDebugMode) {
          print('Failed to parse StorageObject from JSON: $e');
        }
        continue;
      }
    }

    return area;
  }

  @override
  @HiveField(0)
  String name;

  @HiveField(1)
  // @Deprecated('Used to be colorInt, but was not used')
  bool get _deprecated => false;

  @HiveField(2)
  List<StorageObject> _shelvesAndItems;

  @HiveField(3)
  int? _duplicateOrder;

  int get duplicateOrder => _duplicateOrder ?? 1;
  set duplicateOrder(int value) => _duplicateOrder = value;

  Color get color => Color(
    Colors.primaries[name.hashCode % Colors.primaries.length].toARGB32(),
  );

  @override
  String get path => _nameWithDuplicateSuffix(name, duplicateOrder);

  @override
  List<TextSpan> get richPath => [
    TextSpan(
      text: name,
      style: TextStyle(color: color),
    ),
  ];

  @override
  Json toJson() {
    return {
      'name': name,
      'duplicateOrder': duplicateOrder,
      'shelvesAndItems': _shelvesAndItems.map((item) {
        if (item is Shelf) {
          return {'type': 'shelf', 'data': item.toJson()};
        } else if (item is Item) {
          return {'type': 'item', 'data': item.toJson()};
        }
        return null;
      }).toList(),
    };
  }

  void addShelf(String shelfName) {
    _shelvesAndItems.add(Shelf(shelfName)..parent = this);
    _reindexDirectChildDuplicateOrders();
  }

  void addItem(String itemName) {
    _shelvesAndItems.add(Item(itemName)..parent = this);
    _reindexDirectChildDuplicateOrders();
  }

  int get numItemsAndShelves => _shelvesAndItems.length;
  StorageObject operator [](int index) {
    final StorageObject object = _shelvesAndItems[index];
    if (object is Shelf) {
      object
        ..parent = this
        .._relinkParentReferences();
    } else if (object is Item) {
      object.parent = this;
    }
    return object;
  }

  StorageObject removeAt(int index) {
    final StorageObject removed = _shelvesAndItems.removeAt(index);
    _reindexDirectChildDuplicateOrders();
    return removed;
  }

  void insert(int index, StorageObject object) {
    if (object is Shelf) {
      object
        ..parent = this
        .._relinkParentReferences();
    } else if (object is Item) {
      object.parent = this;
    }

    _shelvesAndItems.insert(index, object);
    _reindexDirectChildDuplicateOrders();
  }

  void relinkParentReferences() {
    _reindexDirectChildDuplicateOrders();
    for (final StorageObject element in _shelvesAndItems) {
      if (element is Shelf) {
        element
          ..parent = this
          .._relinkParentReferences();
      } else if (element is Item) {
        element.parent = this;
      }
    }
  }

  void forEachItem(void Function(Item element) action) {
    for (final StorageObject element in _shelvesAndItems) {
      if (element is Item) {
        element.parent = this;
        action(element);
      } else if (element is Shelf) {
        element
          ..parent = this
          .._relinkParentReferences()
          ..forEach(action);
      }
    }
  }

  int get numShelves => _shelvesAndItems.whereType<Shelf>().length;
  int get numItems => _shelvesAndItems.whereType<Item>().length;

  bool hasAnyItems() {
    for (var i = 0; i < numItemsAndShelves; i++) {
      final StorageObject shelfOrItem = _shelvesAndItems[i];
      if (shelfOrItem is Shelf) {
        shelfOrItem
          ..parent = this
          .._relinkParentReferences();
        if (shelfOrItem.isNotEmpty) {
          return true;
        }
      } else if (shelfOrItem is Item) {
        shelfOrItem.parent = this;
        return true;
      }
    }
    return false;
  }

  List<String> getPathsForItem(String itemName) => [
    for (final StorageObject shelfOrItem in _shelvesAndItems)
      if (shelfOrItem is Shelf)
        ...(() {
          shelfOrItem
            ..parent = this
            .._relinkParentReferences();
          return shelfOrItem.getPathsForItem(itemName);
        }())
      else if (shelfOrItem is Item &&
          (shelfOrItem.countName ?? shelfOrItem.name) == itemName)
        () {
          shelfOrItem.parent = this;
          return shelfOrItem.path;
        }(),
  ];

  void _reindexDirectChildDuplicateOrders() {
    final shelfNameCount = <String, int>{};
    final itemNameCount = <String, int>{};

    for (final StorageObject element in _shelvesAndItems) {
      if (element is Shelf) {
        final int nextOrder = (shelfNameCount[element.name] ?? 0) + 1;
        shelfNameCount[element.name] = nextOrder;
        element
          ..duplicateOrder = nextOrder
          ..parent = this
          .._relinkParentReferences();
      } else if (element is Item) {
        final int nextOrder = (itemNameCount[element.name] ?? 0) + 1;
        itemNameCount[element.name] = nextOrder;
        element
          ..duplicateOrder = nextOrder
          ..parent = this;
      }
    }
  }
}

@HiveType(typeId: 1)
class Shelf extends StorageObject {
  Shelf(this.name, {int duplicateOrder = 1, List<Item>? items})
    : _duplicateOrder = duplicateOrder,
      _items = items ?? [];

  factory Shelf._fromJson(Json json, Area parent) {
    final shelf = Shelf(
      json['name'] as String? ?? '',
      duplicateOrder: json['duplicateOrder'] as int? ?? 1,
    )..parent = parent;

    for (final Json item in (json['items'] as List? ?? [])) {
      try {
        shelf._items.add(Item._fromJson(item, shelf));
      } on Exception catch (e) {
        if (kDebugMode) {
          print('Failed to parse Item from JSON: $e');
        }
        continue;
      }
    }

    return shelf;
  }

  @override
  @HiveField(0)
  String name;

  @HiveField(1)
  List<Item> _items;

  @HiveField(2)
  int? _duplicateOrder;

  int get duplicateOrder => _duplicateOrder ?? 1;
  set duplicateOrder(int value) => _duplicateOrder = value;

  late Area parent;

  @override
  String get path =>
      '${parent.path} > '
      '${_nameWithDuplicateSuffix(name, duplicateOrder)}';

  @override
  List<TextSpan> get richPath => [
    ...parent.richPath,
    const TextSpan(text: ' > '),
    TextSpan(text: name),
  ];

  @override
  Json toJson() {
    return {
      'name': name,
      'duplicateOrder': duplicateOrder,
      'items': _items.map((item) => item.toJson()).toList(),
    };
  }

  void addItem(String itemName) {
    _items.add(Item(itemName)..parent = this);
    _reindexItemDuplicateOrders();
  }

  int get numItems => _items.length;
  Item operator [](int index) {
    final Item item = _items[index]..parent = this;
    return item;
  }

  Item removeAt(int index) {
    final Item removed = _items.removeAt(index);
    _reindexItemDuplicateOrders();
    return removed;
  }

  void insert(int index, Item item) {
    item.parent = this;
    _items.insert(index, item);
    _reindexItemDuplicateOrders();
  }

  bool get isNotEmpty => _items.isNotEmpty;

  void _relinkParentReferences() {
    _reindexItemDuplicateOrders();
  }

  void _reindexItemDuplicateOrders() {
    final itemNameCount = <String, int>{};
    for (final Item item in _items) {
      final int nextOrder = (itemNameCount[item.name] ?? 0) + 1;
      itemNameCount[item.name] = nextOrder;
      item
        ..duplicateOrder = nextOrder
        ..parent = this;
    }
  }

  void forEach(void Function(Item element) action) {
    for (final Item item in _items) {
      item.parent = this;
      action(item);
    }
  }

  List<String> getPathsForItem(String itemName) => [
    for (final Item item in _items)
      if ((item.countName ?? item.name) == itemName) item.path,
  ];
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
    int duplicateOrder = 1,
  }) : _duplicateOrder = duplicateOrder,
       strategy = strategy ?? SingularCountStrategy(),
       countPhase = countPhase ?? CountPhase.back;

  factory Item._fromJson(Json json, StorageObject parent) {
    try {
      final int countPhaseIndex = json['countPhase'] ?? 0;
      final int? personalCountPhaseIndex = json['personalCountPhase'];

      CountStrategy? strategy;
      if (json['strategy'] != null) {
        try {
          if (json['strategy'] is Json) {
            strategy = CountStrategy.fromJson(json['strategy'] as Json);
          }
        } on Exception catch (e) {
          if (kDebugMode) {
            print('Failed to parse strategy from JSON: $e');
          }
          // If strategy parsing fails, use default
          strategy = null;
        }
      }

      ItemCount? defaultCount;
      if (json['defaultCount'] != null) {
        try {
          if (json['defaultCount'] is Json) {
            defaultCount = ItemCount.fromJson(json['defaultCount'] as Json);
          }
        } on Exception catch (e) {
          if (kDebugMode) {
            print('Failed to parse defaultCount from JSON: $e');
          }
          // If defaultCount parsing fails, use null
          defaultCount = null;
        }
      }

      final item = Item(
        json['name'] as String? ?? '',
        strategy: strategy,
        countName: json['countName'] as String?,
        defaultCount: defaultCount,
        duplicateOrder: json['duplicateOrder'] as int? ?? 1,
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
      )..parent = parent;
      return item;
    } on Exception catch (e) {
      if (kDebugMode) {
        print('Failed to parse Item from JSON: $e');
      }
      // If anything fails, return a basic item with the name
      final item = Item(json['name'] as String? ?? 'Unknown Item')
        ..parent = parent;
      return item;
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

  @HiveField(7)
  int? _duplicateOrder;

  int get duplicateOrder => _duplicateOrder ?? 1;
  set duplicateOrder(int value) => _duplicateOrder = value;

  @HiveField(2)
  // @Deprecated('Used to be itemId, but is no longer used')
  bool get _deprecated => false;

  late StorageObject parent;

  @override
  String get path =>
      '${parent.path} > '
      '${_nameWithDuplicateSuffix(name, duplicateOrder)}';

  @override
  List<TextSpan> get richPath => [
    ...parent.richPath,
    const TextSpan(text: ' > '),
    TextSpan(text: name),
  ];

  bool getIsValid(ExportModel exportModel) =>
      exportModel.contains(countName ?? name);

  @override
  Json toJson() {
    return {
      'name': name,
      'duplicateOrder': duplicateOrder,
      'strategy': strategy.toJson(),
      'countName': countName,
      'defaultCount': defaultCount?.toJson(),
      'countPhase': countPhase.index,
      'personalCountPhase': personalCountPhase?.index,
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

  Color get color {
    switch (this) {
      case CountPhase.back:
        return const Color.fromRGBO(244, 67, 54, 0.6);
      case CountPhase.cabinet:
        return const Color.fromRGBO(255, 235, 59, 0.6);
      case CountPhase.out:
        return const Color.fromRGBO(76, 175, 80, 0.6);
    }
  }
}

@HiveType(typeId: 6)
class CountEntry extends HiveObject {
  CountEntry(this.name, this.phase, this.countType);

  factory CountEntry.fromJson(Json json) {
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

  Json toJson() {
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
    Map<dynamic, CountEntry>? itemCounts,
    CountPhase? countPhase,
    Map<String, bool>? itemsToFix,
    this.profile,
  }) : itemCounts = {
         for (final MapEntry<dynamic, CountEntry> entry
             in (itemCounts ?? <dynamic, CountEntry>{}).entries)
           entry.key.toString(): entry.value,
       },
       countPhase = countPhase ?? CountPhase.back,
       itemsToFix = itemsToFix ?? <String, bool>{};

  factory Count.fromJson(Json json) {
    final int phaseIndex = json['countPhase'] as int? ?? 0;
    final CountPhase phase =
        (phaseIndex >= 0 && phaseIndex < CountPhase.values.length)
        ? CountPhase.values[phaseIndex]
        : CountPhase.back;

    final itemsToFixRaw = json['itemsToFix'] as Json?;
    final Map<String, bool> itemsToFix = itemsToFixRaw != null
        ? itemsToFixRaw.map((k, v) => MapEntry(k, v as bool))
        : <String, bool>{};

    final List<dynamic> itemCountsList =
        (json['itemCounts'] as List<dynamic>?) ?? [];
    final Map<String, CountEntry> itemCountsMap = {};
    for (final element in itemCountsList) {
      if (element is Json) {
        final itemId = element['path'] as String?;
        final entryJson = element['entry'] as Json?;
        if (itemId != null && entryJson != null) {
          try {
            final entry = CountEntry.fromJson(entryJson);
            itemCountsMap[itemId] = entry;
          } on Exception catch (e) {
            if (kDebugMode) {
              print('Failed to parse CountEntry from JSON: $e');
            }
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
  final Map<dynamic, CountEntry> itemCounts;

  @HiveField(1)
  CountPhase countPhase = CountPhase.back;

  @HiveField(2)
  Map<String, bool> itemsToFix = {};

  @HiveField(3)
  Profile? profile;

  ItemCountType? getCount(Item data) {
    return itemCounts[data.path]?.countType;
  }

  void setCount(Item data, ItemCountType? count) {
    if (count == null || (count is ItemCount && count.isEmpty())) {
      itemCounts.remove(data.path);
      return;
    }

    itemCounts[data.path] = CountEntry(
      data.countName ?? data.name,
      data.countPhase,
      count,
    );
  }

  void setNotCounted(Item data) {
    itemCounts[data.path] = CountEntry(
      data.countName ?? data.name,
      data.countPhase,
      ItemNotCounted(),
    );
  }

  int? getCountValueByName(String name, CountPhase phase) {
    var total = 0;
    var isValue = false;

    for (final CountEntry entry in itemCounts.values) {
      final ItemCountType itemCountType = entry.countType;
      if (entry.name == name && entry.phase == phase) {
        if (itemCountType is ItemNotCounted) return -1;

        isValue = true;
        total += (itemCountType as ItemCount).count ?? 0;
      }
    }
    return isValue ? total : null;
  }

  String? getCountSumNotationByName(String name, CountPhase phase) {
    final List<String> notations = [];

    for (final CountEntry entry in itemCounts.values) {
      final ItemCountType itemCountType = entry.countType;
      if (entry.name == name && entry.phase == phase) {
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

  static Json getItemNotCountedJson(String? omniName) {
    final Json exportData = {};

    for (final CountPhase phase in CountPhase.values) {
      exportData[phase.name] = '-';
    }

    exportData['Total'] = '-';
    exportData['omniName'] = omniName;

    return exportData;
  }

  Json getItemExportJson(String countName, String? omniName) {
    final Json exportData = {};

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
    exportData['omniName'] = omniName;

    return exportData;
  }

  void updateCountForItem(Item data) {
    if (!itemCounts.containsKey(data.path)) {
      return;
    }

    final CountEntry existingEntry = itemCounts[data.path]!;
    ItemCountType existingCountType = existingEntry.countType;

    if (existingCountType is ItemCount) {
      existingCountType = ItemCount(
        data.strategy,
        field1: existingCountType.field1,
        field2: existingCountType.field2,
      );
    }

    itemCounts[data.path] = CountEntry(
      data.countName ?? data.name,
      data.countPhase,
      existingCountType,
    );
  }

  Json toJson() {
    return {
      'countPhase': countPhase.index,
      'itemsToFix': itemsToFix,
      'itemCounts': itemCounts.entries.map((e) {
        return {'path': e.key, 'entry': e.value.toJson()};
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
    return defaultIcons.values.elementAt(name.hashCode % defaultIcons.length);
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

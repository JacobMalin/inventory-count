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
  Hive.registerAdapter<CountKey>(CountKeyAdapter());
  Hive.registerAdapter<ExportEntry>(ExportEntryAdapter());
  Hive.registerAdapter<ExportItem>(ExportItemAdapter());
  Hive.registerAdapter<ExportPlaceholder>(ExportPlaceholderAdapter());
  Hive.registerAdapter<ExportTitle>(ExportTitleAdapter());

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
  CountStrategy strategy;

  @HiveField(2)
  int? strategyInt;

  @HiveField(3)
  String? countName;

  @HiveField(4)
  int? defaultCount;

  @HiveField(5)
  CountPhase countPhase;

  @HiveField(6)
  CountPhase? personalCountPhase;

  Item(
    this.name, {
    CountStrategy? strategy,
    this.strategyInt,
    this.countName,
    this.defaultCount,
    CountPhase? countPhase,
    this.personalCountPhase,
  }) : strategy = strategy ?? CountStrategy.singular,
       countPhase = countPhase ?? CountPhase.back;
}

@HiveType(typeId: 3)
enum CountStrategy {
  @HiveField(0)
  singular,

  @HiveField(1)
  stacks,

  @HiveField(2)
  singularAndStacks,

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

@HiveType(typeId: 5)
class Count extends HiveObject {
  @HiveField(0)
  final Map<CountKey, int> itemCounts;

  @HiveField(2)
  final Map<CountKey, int> secondaryItemCounts;

  @HiveField(1)
  CountPhase countPhase = CountPhase.back;

  Count({
    Map<CountKey, int>? itemCounts,
    Map<CountKey, int>? secondaryItemCounts,
    CountPhase? countPhase,
  }) : itemCounts = itemCounts ?? {},
       secondaryItemCounts = secondaryItemCounts ?? {},
       countPhase = countPhase ?? CountPhase.back;

  int? getCount(Item data) {
    return itemCounts[CountKey(data.countName ?? data.name, data.countPhase)];
  }

  void setCount(Item data, int? count) {
    if (count == null) {
      itemCounts.remove(CountKey(data.countName ?? data.name, data.countPhase));
      return;
    }

    itemCounts[CountKey(data.countName ?? data.name, data.countPhase)] = count;
  }

  int? getSecondaryCount(Item data) {
    return secondaryItemCounts[CountKey(
      data.countName ?? data.name,
      data.countPhase,
    )];
  }

  void setSecondaryCount(Item data, int count) {
    secondaryItemCounts[CountKey(
          data.countName ?? data.name,
          data.countPhase,
        )] =
        count;
  }

  int? getCountTrue(Item data) {
    int? base = getCount(data);
    int? secondary = getSecondaryCount(data);

    if (base == null) {
      return null;
    }

    switch (data.strategy) {
      case CountStrategy.singular:
        return base;
      case CountStrategy.stacks:
        return base * (data.strategyInt ?? 1);
      case CountStrategy.singularAndStacks:
        return (secondary ?? 0) + ((data.strategyInt ?? 1) * base);
      case CountStrategy.negative:
        return (data.strategyInt ?? 0) - base;
    }
  }
}

@HiveType(typeId: 6)
class CountKey extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  CountPhase phase;

  CountKey(this.name, this.phase);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is CountKey && other.name == name && other.phase == phase;
  }

  @override
  int get hashCode => name.hashCode ^ phase.hashCode;
}

@HiveType(typeId: 10)
class ExportEntry extends HiveObject {
  @HiveField(0)
  String name;

  ExportEntry(this.name);
}

@HiveType(typeId: 7)
class ExportItem extends ExportEntry {
  List<String> paths;

  ExportItem(super.name, {List<String>? paths}) : paths = paths ?? [];
}

@HiveType(typeId: 8)
class ExportPlaceholder extends ExportEntry {
  ExportPlaceholder(super.name);
}

@HiveType(typeId: 9)
class ExportTitle extends ExportEntry {
  ExportTitle(super.name);
}

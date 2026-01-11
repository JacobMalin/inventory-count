import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:inventory_count/count_page.dart';
import 'package:inventory_count/models/area_model.dart';
import 'package:inventory_count/models/count_strategy.dart';
import 'package:inventory_count/models/hive.dart';

class CountModel with ChangeNotifier {
  final DateFormat _dateFormat = DateFormat('EEEE, MMMM d, yyyy');
  static const int _lastCountLookbackDays = 14;

  String get date => _dateFormat.format(_selectedDate);

  DateTime _selectedDate = Hive.box(
    'settings',
  ).get('selectedDate', defaultValue: DateTime.now());

  DateTime get selectedDate => _selectedDate;

  void setSelectedDate(DateTime date) {
    _selectedDate = date;
    notifyListeners();
  }

  void incrementDate() {
    _selectedDate = _selectedDate.add(const Duration(days: 1));
    notifyListeners();
  }

  void decrementDate() {
    _selectedDate = _selectedDate.subtract(const Duration(days: 1));
    notifyListeners();
  }

  bool get isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  void goToToday() {
    _selectedDate = DateTime.now();
    notifyListeners();
  }

  Count get _thisCount => Hive.box<Count>('counts').get(date) ?? Count();

  CountPhase get countPhase => _thisCount.countPhase;

  Map<String, bool> get itemsToFix => _thisCount.itemsToFix;

  void setItemsToFix(Map<String, bool> items) {
    final Box<Count> countBox = Hive.box<Count>('counts');
    final Count currentCount = countBox.get(date) ?? Count();
    currentCount.itemsToFix = items;
    countBox.put(date, currentCount);
    notifyListeners();
  }

  void setCountPhase(CountPhase phase) {
    final Box<Count> countBox = Hive.box<Count>('counts');
    final Count currentCount = countBox.get(date) ?? Count();
    currentCount.countPhase = phase;
    countBox.put(date, currentCount);
    notifyListeners();
  }

  ItemCountType? getCount(Item data) {
    return _thisCount.getCount(data);
  }

  void setField1(Item data, int? count) {
    final Box<Count> countBox = Hive.box<Count>('counts');
    final Count currentCount = countBox.get(date) ?? Count();
    ItemCountType? existingCount = currentCount.getCount(data);

    ItemCount itemCount = (existingCount is ItemCount)
        ? existingCount
        : ItemCount(data.strategy);
    itemCount.field1 = count;
    currentCount.setCount(data, itemCount);
    countBox.put(date, currentCount);
    notifyListeners();
  }

  void setField2(Item data, int? count) {
    final Box<Count> countBox = Hive.box<Count>('counts');
    final Count currentCount = countBox.get(date) ?? Count();
    ItemCountType? existingCount = currentCount.getCount(data);

    ItemCount itemCount = (existingCount is ItemCount)
        ? existingCount
        : ItemCount(data.strategy);
    itemCount.field2 = count;
    currentCount.setCount(data, itemCount);
    countBox.put(date, currentCount);
    notifyListeners();
  }

  void setNotCounted(Item data) {
    final Box<Count> countBox = Hive.box<Count>('counts');
    final Count currentCount = countBox.get(date) ?? Count();
    currentCount.setNotCounted(data);
    countBox.put(date, currentCount);
    notifyListeners();
  }

  void setDoubleChecked(Item data, bool value) {
    final Box<Count> countBox = Hive.box<Count>('counts');
    final Count currentCount = countBox.get(date) ?? Count();
    ItemCountType? existingCount = currentCount.getCount(data);

    if (existingCount != null) {
      existingCount.doubleChecked = value;
      currentCount.setCount(data, existingCount);
      countBox.put(date, currentCount);
      notifyListeners();
    }
  }

  void setDefaultCount(Item data) {
    final Box<Count> countBox = Hive.box<Count>('counts');
    final Count currentCount = countBox.get(date) ?? Count();

    ItemCount defaultWithCurrentModifiers;

    if (data.strategy is NegativeCountStrategy) {
      // For negative strategy, always use 0
      defaultWithCurrentModifiers = ItemCount(data.strategy, field1: 0);
    } else {
      if (data.defaultCount == null) return;

      // Create a new ItemCount with current modifiers
      defaultWithCurrentModifiers = ItemCount(
        data.strategy,
        field1: data.defaultCount!.field1,
        field2: data.defaultCount!.field2,
      );
    }

    currentCount.setCount(data, defaultWithCurrentModifiers);
    countBox.put(date, currentCount);
    notifyListeners();
  }

  ItemCountType? getLastCount(Item item) {
    final Box<Count> countBox = Hive.box<Count>('counts');

    // Look back through the last 'days' days to find a count
    for (int i = 1; i <= _lastCountLookbackDays; i++) {
      final pastDate = _selectedDate.subtract(Duration(days: i));
      final dateKey = _dateFormat.format(pastDate);

      final Count? pastCount = countBox.get(dateKey);
      if (pastCount == null) continue;

      final ItemCountType? itemCount = pastCount.getCount(item);
      if (itemCount != null) {
        if (itemCount is ItemCount) {
          return ItemCount(
            item.strategy,
            field1: itemCount.field1,
            field2: itemCount.field2,
          );
        } else if (itemCount is ItemNotCounted) {
          return ItemNotCounted();
        }
      }
    }

    return null;
  }

  void setLastCount(Item item) {
    final ItemCountType? lastCount = getLastCount(item);
    if (lastCount == null) return;

    final Box<Count> countBox = Hive.box<Count>('counts');
    final Count currentCount = countBox.get(date) ?? Count();
    currentCount.setCount(item, lastCount);
    countBox.put(date, currentCount);
    notifyListeners();
  }

  int? getCountValueByName(String name, CountPhase phase) {
    final Box<Count> countBox = Hive.box<Count>('counts');
    final Count currentCount = countBox.get(date) ?? Count();

    return currentCount.getCountValueByName(name, phase);
  }

  String? getCountSumNotationByName(String name, CountPhase phase) {
    final Box<Count> countBox = Hive.box<Count>('counts');
    final Count currentCount = countBox.get(date) ?? Count();

    return currentCount.getCountSumNotationByName(name, phase);
  }

  List<ItemTreeData> findItemsByName(
    String name,
    CountPhase phase,
    AreaModel areaModel,
  ) {
    final Box<Count> countBox = Hive.box<Count>('counts');
    final Count currentCount = countBox.get(date) ?? Count();

    List<int> itemIds = [];
    List<ItemTreeData> items = [];

    for (final MapEntry<int, CountEntry> entry
        in currentCount.itemCounts.entries) {
      if (entry.value.name == name && entry.value.phase == phase) {
        itemIds.add(entry.key);
      }
    }

    for (int i = 0; i < areaModel.numAreas; i++) {
      final area = areaModel.getArea(i);
      for (var shelfOrItem in area.shelvesAndItems) {
        if (shelfOrItem is Item) {
          if (itemIds.contains(shelfOrItem.id)) {
            items.add(ItemTreeData(shelfOrItem, area: area));
          }
        } else if (shelfOrItem is Shelf) {
          for (var item in shelfOrItem.items) {
            if (itemIds.contains(item.id)) {
              items.add(ItemTreeData(item, area: area, shelf: shelfOrItem));
            }
          }
        }
      }
    }

    return items;
  }

  void removeFromCountList(Item data) {
    final Box<Count> countBox = Hive.box<Count>('counts');
    final Count currentCount = countBox.get(date) ?? Count();

    currentCount.itemCounts.remove(data.id);
    notifyListeners();
  }

  void maintainCountList(Item data) {
    final Box<Count> countBox = Hive.box<Count>('counts');
    final Count currentCount = countBox.get(date) ?? Count();
    currentCount.updateCountForItem(data);
    countBox.put(date, currentCount);
    notifyListeners();
  }
}

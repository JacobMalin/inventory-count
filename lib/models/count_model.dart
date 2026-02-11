import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:inventory_count/models/count_strategy.dart';
import 'package:inventory_count/models/hive.dart';

class CountModel with ChangeNotifier {
  final Box _settingsBox = Hive.box('settings');
  final Box<Count> _countBox = Hive.box<Count>('counts');

  final DateFormat _dateFormat = DateFormat('EEEE, MMMM d, yyyy');
  static const int _lastCountLookbackDays = 14;

  String get date => _dateFormat.format(_selectedDate);

  DateTime _selectedDate = DateTime.now();

  bool get hideCountedItems =>
      _settingsBox.get('hideCountedItems', defaultValue: false);
  void setHideCountedItems(bool value) {
    _settingsBox.put('hideCountedItems', value);
  }

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

  Count get _thisCount => _countBox.get(date) ?? Count();
  set _thisCount(Count count) {
    _countBox.put(date, count);
    notifyListeners();
  }

  // TODO: Add profile lock
  Profile? get selectedProfile => _thisCount.profile;
  set selectedProfile(Profile? profile) {
    final Count currentCount = _thisCount;
    currentCount.profile = profile;
    _thisCount = currentCount;
  }

  CountPhase get countPhase => _thisCount.countPhase;

  Map<String, bool> get itemsToFix => _thisCount.itemsToFix;

  void setItemsToFix(Map<String, bool> items) {
    final Count currentCount = _thisCount;
    currentCount.itemsToFix = items;
    _thisCount = currentCount;
  }

  void setCountPhase(CountPhase phase) {
    final Count currentCount = _thisCount;
    currentCount.countPhase = phase;
    _thisCount = currentCount;
  }

  ItemCountType? getCount(Item data) {
    return _thisCount.getCount(data);
  }

  void setField1(Item data, int? count) {
    final Count currentCount = _thisCount;
    ItemCountType? existingCount = currentCount.getCount(data);

    ItemCount itemCount = (existingCount is ItemCount)
        ? existingCount
        : ItemCount(data.strategy);
    itemCount.field1 = count;
    currentCount.setCount(data, itemCount);
    _thisCount = currentCount;
  }

  void setField2(Item data, int? count) {
    final Count currentCount = _thisCount;
    ItemCountType? existingCount = currentCount.getCount(data);

    ItemCount itemCount = (existingCount is ItemCount)
        ? existingCount
        : ItemCount(data.strategy);
    itemCount.field2 = count;
    currentCount.setCount(data, itemCount);
    _thisCount = currentCount;
  }

  void setNotCounted(Item data) {
    final Count currentCount = _thisCount;
    currentCount.setNotCounted(data);
    _thisCount = currentCount;
  }

  void setDoubleChecked(Item data, bool value) {
    final Count currentCount = _thisCount;
    ItemCountType? existingCount = currentCount.getCount(data);

    if (existingCount != null) {
      existingCount.doubleChecked = value;
      currentCount.setCount(data, existingCount);
      _thisCount = currentCount;
    }
  }

  void setDefaultCount(Item data) {
    final Count currentCount = _thisCount;

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
    _thisCount = currentCount;
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

    final Count currentCount = _thisCount;
    currentCount.setCount(item, lastCount);
    _thisCount = currentCount;
  }

  int? getCountValueByName(String name, CountPhase phase) {
    return _thisCount.getCountValueByName(name, phase);
  }

  String? getCountSumNotationByName(String name, CountPhase phase) {
    return _thisCount.getCountSumNotationByName(name, phase);
  }

  Map<String, dynamic> getItemExportJson(String name) {
    return _thisCount.getItemExportJson(name);
  }

  void removeFromCountList(Item data) {
    final Count currentCount = _thisCount;
    currentCount.itemCounts.remove(data.id);
    _thisCount = currentCount;
  }

  void maintainCountList(Item data) {
    final Count currentCount = _thisCount;
    currentCount.updateCountForItem(data);
    _thisCount = currentCount;
  }

  Map<int, CountEntry> get itemCounts => _thisCount.itemCounts;
}

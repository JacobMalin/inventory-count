import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:inventory_count/models/hive.dart';

class CountModel with ChangeNotifier {
  final DateFormat _dateFormat = DateFormat('EEEE, MMMM d, yyyy');

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

  Count get _thisCount => Hive.box('counts').get(date) ?? Count();

  CountPhase get countPhase => _thisCount.countPhase;

  void setCountPhase(CountPhase phase) {
    final Box countBox = Hive.box('counts');
    final Count currentCount = countBox.get(date) ?? Count();
    currentCount.countPhase = phase;
    countBox.put(date, currentCount);
    notifyListeners();
  }

  ItemCountType? getCount(Item data) {
    return _thisCount.getCount(data);
  }

  void setField1(Item data, int? count) {
    final Box countBox = Hive.box('counts');
    final Count currentCount = countBox.get(date) ?? Count();
    ItemCountType? existingCount = currentCount.getCount(data);
    if (count == null && existingCount is ItemNotCounted) {
      return;
    }

    ItemCount itemCount = (existingCount is ItemCount)
        ? existingCount
        : ItemCount(data.strategy, data.strategyInt, data.strategyInt2);
    itemCount.field1 = count;
    currentCount.setCount(data, itemCount);
    countBox.put(date, currentCount);
    notifyListeners();
  }

  void setField2(Item data, int? count) {
    final Box countBox = Hive.box('counts');
    final Count currentCount = countBox.get(date) ?? Count();
    ItemCountType? existingCount = currentCount.getCount(data);
    if (count == null && existingCount is ItemNotCounted) {
      return;
    }

    ItemCount itemCount = (existingCount is ItemCount)
        ? existingCount
        : ItemCount(data.strategy, data.strategyInt, data.strategyInt2);
    itemCount.field2 = count;
    currentCount.setCount(data, itemCount);
    countBox.put(date, currentCount);
    notifyListeners();
  }

  void setNotCounted(Item data) {
    final Box countBox = Hive.box('counts');
    final Count currentCount = countBox.get(date) ?? Count();
    currentCount.setNotCounted(data);
    countBox.put(date, currentCount);
    notifyListeners();
  }

  int? getCountValueByName(String name, CountPhase phase) {
    final Box countBox = Hive.box('counts');
    final Count currentCount = countBox.get(date) ?? Count();

    return currentCount.getCountValueByName(name, phase);
  }

  void removeFromCountList(Item data) {
    final Box countBox = Hive.box('counts');
    final Count currentCount = countBox.get(date) ?? Count();

    currentCount.itemCounts.remove(data.id);
    notifyListeners();
  }

  void maintainCountList(Item data) {
    final Box countBox = Hive.box('counts');
    final Count currentCount = countBox.get(date) ?? Count();
    currentCount.updateCountForItem(data);
    countBox.put(date, currentCount);
    notifyListeners();
  }
}

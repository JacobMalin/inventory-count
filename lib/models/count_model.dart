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

  Count get thisCount => Hive.box('counts').get(date) ?? Count();

  CountPhase get countPhase => thisCount.countPhase;

  void setCountPhase(CountPhase phase) {
    final countBox = Hive.box('counts');
    final currentCount = countBox.get(date) ?? Count();
    currentCount.countPhase = phase;
    countBox.put(date, currentCount);
    notifyListeners();
  }

  int? getCount(Item data) {
    return thisCount.getCount(data);
  }

  void setCount(Item data, int count) {
    final countBox = Hive.box('counts');
    final currentCount = countBox.get(date) ?? Count();
    currentCount.setCount(data, count);
    countBox.put(date, currentCount);
    notifyListeners();
  }
}

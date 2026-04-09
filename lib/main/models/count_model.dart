import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/types/json.dart';
import '../repositories/count_local_repository.dart';
import '../repositories/count_sync_repository.dart';
import '../repositories/export_local_repository.dart';
import 'data/count_strategy.dart';
import 'data/export_entry.dart';
import 'data/inventory_models.dart';
import 'export_model.dart';

class CountModel extends ChangeNotifier {
  CountModel({
    required ExportLocalRepository exportLocalRepository,
    this.exportModel,
    bool disableSync = false,
  }) : selectedDate = DateTime.now().subtract(const Duration(hours: 3)),
       _localRepository = HiveCountLocalRepository(),
       _syncRepository = SupabaseCountSyncRepository(
         selectedDate: DateTime.now().subtract(const Duration(hours: 3)),
         disableSync: disableSync,
       ),
       _exportLocalRepository = exportLocalRepository;

  final CountLocalRepository _localRepository;
  final CountSyncRepository _syncRepository;
  final ExportLocalRepository _exportLocalRepository;

  DateTime selectedDate;

  static String _normalizeKey(String key) => key
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll('&', '');

  int? getExpectedValue(String itemName, String? omniName) {
    final Map<String, int> expectedByName = _localRepository
        .readExpectedByNameForDate(_syncRepository.rowName(selectedDate));
    if (expectedByName.isEmpty) return null;
    return expectedByName[_normalizeKey(omniName ?? itemName)] ??
        expectedByName[_normalizeKey(itemName)];
  }

  ExportModel? exportModel;

  final DateFormat _dateFormat = DateFormat('EEEE, MMMM d, yyyy');
  static const int _lastCountLookbackDays = 14;

  String get date => _dateFormat.format(selectedDate);

  bool get hideCountedItems => _localRepository.readHideCountedItems();
  set hideCountedItems(bool value) {
    unawaited(_localRepository.writeHideCountedItems(value));
  }

  void setSelectedDate(DateTime date) {
    selectedDate = date;
    unawaited(_syncRepository.reconnect(selectedDate));
    notifyListeners();
  }

  void incrementDate() {
    selectedDate = selectedDate.add(const Duration(days: 1));
    unawaited(_reconnectCountSubscription());
    notifyListeners();
  }

  void decrementDate() {
    selectedDate = selectedDate.subtract(const Duration(days: 1));
    unawaited(_reconnectCountSubscription());
    notifyListeners();
  }

  bool get isToday {
    final now = DateTime.now();
    return selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day;
  }

  void goToToday() {
    selectedDate = DateTime.now();
    unawaited(_reconnectCountSubscription());
    notifyListeners();
  }

  Count get _thisCount =>
      _localRepository.readCount(date) ??
      Count(profile: isProfileRemembered ? rememberedProfile : null);
  set _thisCount(Count count) {
    unawaited(_localRepository.writeCount(date, count));
    unawaited(_syncPendingToRemote());
    WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());
  }

  Profile? get selectedProfile => _thisCount.profile;
  set selectedProfile(Profile? profile) {
    final Count currentCount = _thisCount..profile = profile;
    _thisCount = currentCount;

    if (profile == null) {
      clearRememberedProfile();
      return;
    }

    if (isProfileRemembered) {
      unawaited(_localRepository.writeRememberedProfile(profile));
    } else {
      clearRememberedProfile();
    }
  }

  bool get isProfileRemembered => _localRepository.readIsProfileRemembered();
  set isProfileRemembered(bool value) {
    unawaited(_localRepository.writeIsProfileRemembered(value));
    notifyListeners();
  }

  Profile? get rememberedProfile => _localRepository.readRememberedProfile();

  void clearRememberedProfile() {
    unawaited(_localRepository.clearRememberedProfile());
  }

  String exportInExportOrder() {
    final List<ExportEntry> currentExportList =
        exportModel?.exportList ?? _exportLocalRepository.readExportList();

    final Json data = {};

    var currentTitle = '';
    var titleHidden = false;
    var titleNotCounted = false;
    for (final entry in currentExportList) {
      if (entry is ExportItem && !entry.isHidden && !titleHidden) {
        final bool useNotCountedJson = entry.isNotCounted || titleNotCounted;

        final currentBucket = data[currentTitle] as Map<dynamic, dynamic>;
        currentBucket[entry.name] = useNotCountedJson
            ? getItemNotCountedJson(entry.omniName)
            : getItemExportJson(entry.name, entry.omniName);
      } else if (entry is ExportTitle) {
        currentTitle = entry.name;
        titleHidden = entry.isHidden;
        titleNotCounted = entry.isNotCounted;
        if (!data.containsKey(currentTitle)) {
          data[currentTitle] = {};
        }
      }
    }
    return jsonEncode(data);
  }

  CountPhase get countPhase => _thisCount.countPhase;

  Map<String, bool> get itemsToFix => _thisCount.itemsToFix;

  void setItemsToFix(Map<String, bool> items) {
    final Count currentCount = _thisCount..itemsToFix = items;
    _thisCount = currentCount;
  }

  void setCountPhase(CountPhase phase) {
    final Count currentCount = _thisCount..countPhase = phase;
    _thisCount = currentCount;
  }

  ItemCountType? getCount(Item data) {
    return _thisCount.getCount(data);
  }

  CountEntry? getCountEntry(String path) {
    return _thisCount.getCountEntry(path);
  }

  void removeCountByPath(String path) {
    final Count currentCount = _thisCount..removeByPath(path);
    _thisCount = currentCount;
  }

  void setField1(Item data, int? count) {
    final Count currentCount = _thisCount;
    final ItemCountType? existingCount = currentCount.getCount(data);

    final ItemCount itemCount =
        (existingCount is ItemCount) ? existingCount : ItemCount(data.strategy)
          ..field1 = count;
    currentCount.setCount(data, itemCount);
    _thisCount = currentCount;
  }

  void setField1ByPath(String path, int? count) {
    final Count currentCount = _thisCount..setField1ByPath(path, count);
    _thisCount = currentCount;
  }

  void setField2(Item data, int? count) {
    final Count currentCount = _thisCount;
    final ItemCountType? existingCount = currentCount.getCount(data);

    final ItemCount itemCount =
        (existingCount is ItemCount) ? existingCount : ItemCount(data.strategy)
          ..field2 = count;
    currentCount.setCount(data, itemCount);
    _thisCount = currentCount;
  }

  void setField2ByPath(String path, int? count) {
    final Count currentCount = _thisCount..setField2ByPath(path, count);
    _thisCount = currentCount;
  }

  void setNotCounted(Item data) {
    final Count currentCount = _thisCount..setNotCounted(data);
    _thisCount = currentCount;
  }

  void setNotCountedByPath(String path) {
    final Count currentCount = _thisCount..setNotCountedByPath(path);
    _thisCount = currentCount;
  }

  void setDoubleChecked(Item data, {required bool doubleChecked}) {
    final Count currentCount = _thisCount;
    final ItemCountType? existingCount = currentCount.getCount(data);

    if (existingCount != null) {
      existingCount.doubleChecked = doubleChecked;
      currentCount.setCount(data, existingCount);
      _thisCount = currentCount;
    }
  }

  void setDoubleCheckedByPath(String path, {required bool doubleChecked}) {
    final Count currentCount = _thisCount;

    if (currentCount.getCountEntry(path) == null) {
      return;
    }

    currentCount.setDoubleCheckedByPath(path, doubleChecked: doubleChecked);
    _thisCount = currentCount;
  }

  void setDefaultCount(Item data) {
    final Count currentCount = _thisCount;

    ItemCount defaultWithCurrentModifiers;

    if (data.strategy is NegativeCountStrategy) {
      defaultWithCurrentModifiers = ItemCount(data.strategy, field1: 0);
    } else {
      if (data.defaultCount == null) return;

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
    for (var i = 1; i <= _lastCountLookbackDays; i++) {
      final DateTime pastDate = selectedDate.subtract(Duration(days: i));
      final String dateKey = _dateFormat.format(pastDate);

      final Count? pastCount = _localRepository.readCount(dateKey);
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

    final Count currentCount = _thisCount..setCount(item, lastCount);
    _thisCount = currentCount;
  }

  int? getCountValueByName(String name, CountPhase phase) {
    return _thisCount.getCountValueByName(name, phase);
  }

  bool hasCountsForItem(String name) {
    return _thisCount.hasCountsForItem(name);
  }

  String? getCountSumNotationByName(String name, CountPhase phase) {
    return _thisCount.getCountSumNotationByName(name, phase);
  }

  Json getItemExportJson(String name, String? omniName) {
    return _thisCount.getItemExportJson(name, omniName);
  }

  Json getItemNotCountedJson(String? omniName) {
    return Count.getItemNotCountedJson(omniName);
  }

  void removeFromCountList(Item data) {
    final Count currentCount = _thisCount;
    currentCount.itemCounts.remove(data.path);
    _thisCount = currentCount;
  }

  void maintainCountList(Item data) {
    final Count currentCount = _thisCount..updateCountForItem(data);
    _thisCount = currentCount;
  }

  void moveCountPath(String oldPath, Item item) {
    final Count currentCount = _thisCount;
    final CountEntry? existingEntry = currentCount.getCountEntry(oldPath);
    if (existingEntry == null) {
      return;
    }

    currentCount.removeByPath(oldPath);
    currentCount.itemCounts[item.path] = CountEntry(
      item.countName ?? item.name,
      item.countPhase,
      existingEntry.countType,
    );
    _thisCount = currentCount;
  }

  Map<String, CountEntry> get itemCounts => _thisCount.itemCounts.map(
    (key, value) => MapEntry(key.toString(), value),
  );

  Future<void> _syncPendingToRemote() async {
    final String json = exportInExportOrder();
    final String actual = jsonEncode(_thisCount.toJson());

    try {
      final String exportName = DateFormat('yyyy-MM-dd').format(selectedDate);
      await _syncRepository.upsertCount(
        CountSyncRecord(
          name: exportName,
          updatedAt: DateTime.now().toUtc(),
          profile: selectedProfile?.name ?? 'Default',
          json: json,
          actual: actual,
        ),
      );

      _lastTimestamp = DateTime.now().toUtc();
    } on Exception {
      // Keep pending flag for retry on next timer tick.
    }
  }

  @override
  Future<void> dispose() async {
    await unregisterReconnectCallbacks();
    await _countSubscription?.cancel();
    super.dispose();
  }
}

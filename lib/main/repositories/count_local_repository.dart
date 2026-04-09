import 'dart:async';

import 'package:hive_flutter/hive_flutter.dart';

import '../models/data/inventory_models.dart';
import 'repository.dart';

abstract class CountLocalRepository extends LocalRepository {
  bool readHideCountedItems();
  Future<void> writeHideCountedItems(bool value);

  bool readIsProfileRemembered();
  Future<void> writeIsProfileRemembered(bool value);

  Profile? readRememberedProfile();
  Future<void> writeRememberedProfile(Profile profile);
  Future<void> clearRememberedProfile();

  Count? readCount(String dateKey);
  Future<void> writeCount(String dateKey, Count count);

  Map<String, int> readExpectedByNameForDate(String dateKey);
  Future<void> writeExpectedByNameForDate(
    String dateKey,
    Map<String, int> value,
  );
}

class HiveCountLocalRepository implements CountLocalRepository {
  HiveCountLocalRepository({
    Box<dynamic>? settingsBox,
    Box<Count>? countBox,
    Box<Map<String, int>>? expectedBox,
  }) : _settingsBox = settingsBox ?? Hive.box('settings'),
       _countBox = countBox ?? Hive.box<Count>('counts'),
       _expectedBox = expectedBox ?? Hive.box<Map<String, int>>('expected') {
    unawaited(_ensureInitialized());
  }

  final Box<dynamic> _settingsBox;
  final Box<Count> _countBox;
  final Box<Map<String, int>> _expectedBox;

  Future<void> _ensureInitialized() async {
    if (_settingsBox.get('hideCountedItems') == null) {
      await _settingsBox.put('hideCountedItems', false);
    }

    if (_settingsBox.get('isProfileRemembered') == null) {
      await _settingsBox.put('isProfileRemembered', false);
    }

    if (_settingsBox.get('rememberedProfile') == null) {
      await _settingsBox.put('rememberedProfile', null);
    }
  }

  @override
  bool readHideCountedItems() {
    return _settingsBox.get('hideCountedItems', defaultValue: false) as bool;
  }

  @override
  Future<void> writeHideCountedItems(bool value) {
    return _settingsBox.put('hideCountedItems', value);
  }

  @override
  bool readIsProfileRemembered() {
    return _settingsBox.get('isProfileRemembered', defaultValue: false) as bool;
  }

  @override
  Future<void> writeIsProfileRemembered(bool value) {
    return _settingsBox.put('isProfileRemembered', value);
  }

  @override
  Profile? readRememberedProfile() {
    final dynamic value = _settingsBox.get('rememberedProfile');
    if (value is Profile) {
      return value;
    }

    return null;
  }

  @override
  Future<void> writeRememberedProfile(Profile profile) {
    return _settingsBox.put('rememberedProfile', profile);
  }

  @override
  Future<void> clearRememberedProfile() {
    return _settingsBox.delete('rememberedProfile');
  }

  @override
  Count? readCount(String dateKey) {
    return _countBox.get(dateKey);
  }

  @override
  Future<void> writeCount(String dateKey, Count count) {
    return _countBox.put(dateKey, count);
  }

  @override
  Map<String, int> readExpectedByNameForDate(String dateKey) {
    final dynamic value = _expectedBox.get('expectedByName:$dateKey');
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v as int));
    }
    return {};
  }

  @override
  Future<void> writeExpectedByNameForDate(
    String dateKey,
    Map<String, int> value,
  ) {
    return _expectedBox.put('expectedByName:$dateKey', value);
  }
}

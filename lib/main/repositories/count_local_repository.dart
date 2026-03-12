import 'package:hive_flutter/hive_flutter.dart';

import '../models/data/inventory_models.dart';

abstract class CountLocalRepository {
  Future<void> ensureInitialized();

  bool readHideCountedItems();
  Future<void> writeHideCountedItems(bool value);

  bool readIsProfileRemembered();
  Future<void> writeIsProfileRemembered(bool value);

  Profile? readRememberedProfile();
  Future<void> writeRememberedProfile(Profile profile);
  Future<void> clearRememberedProfile();

  Count? readCount(String dateKey);
  Future<void> writeCount(String dateKey, Count count);
}

class HiveCountLocalRepository implements CountLocalRepository {
  HiveCountLocalRepository({Box<dynamic>? settingsBox, Box<Count>? countBox})
    : _settingsBox = settingsBox ?? Hive.box('settings'),
      _countBox = countBox ?? Hive.box<Count>('counts');

  final Box<dynamic> _settingsBox;
  final Box<Count> _countBox;

  @override
  Future<void> ensureInitialized() async {
    if (_settingsBox.get('hideCountedItems') == null) {
      await _settingsBox.put('hideCountedItems', false);
    }

    if (_settingsBox.get('isProfileRemembered') == null) {
      await _settingsBox.put('isProfileRemembered', false);
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
}

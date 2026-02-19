import 'package:hive_flutter/hive_flutter.dart';

import '../models/data/inventory_models.dart';

abstract class AreaLocalRepository {
  Future<void> ensureInitialized();

  Map<Profile, List<Area>> readProfiles();
  Future<void> writeProfiles(Map<Profile, List<Area>> profiles);

  int readItemIdCounter();
  Future<void> writeItemIdCounter(int value);
}

class HiveAreaLocalRepository implements AreaLocalRepository {
  HiveAreaLocalRepository({Box<dynamic>? areasBox})
    : _areasBox = areasBox ?? Hive.box('areas');

  final Box<dynamic> _areasBox;

  @override
  Future<void> ensureInitialized() async {
    if (_areasBox.get('profiles') == null) {
      await _areasBox.put('profiles', <Profile, List<Area>>{});
    }

    if (_areasBox.get('itemIdCounter') == null) {
      await _areasBox.put('itemIdCounter', 0);
    }
  }

  @override
  Map<Profile, List<Area>> readProfiles() {
    final Map<dynamic, dynamic> data = _areasBox.get(
      'profiles',
      defaultValue: <Profile, List<Area>>{},
    );

    return data.map<Profile, List<Area>>(
      (k, v) => MapEntry(k as Profile, (v as List<dynamic>).cast<Area>()),
    );
  }

  @override
  Future<void> writeProfiles(Map<Profile, List<Area>> profiles) {
    return _areasBox.put('profiles', profiles);
  }

  @override
  int readItemIdCounter() => _areasBox.get('itemIdCounter', defaultValue: 0);

  @override
  Future<void> writeItemIdCounter(int value) {
    return _areasBox.put('itemIdCounter', value);
  }
}

import 'dart:async';

import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import '../models/data/inventory_models.dart';
import 'repository.dart';

abstract class AreaLocalRepository extends LocalRepository {
  Map<Profile, List<Area>> readProfiles();
  Future<void> writeProfiles(Map<Profile, List<Area>> profiles);
}

class HiveAreaLocalRepository implements AreaLocalRepository {
  HiveAreaLocalRepository({Box<dynamic>? areasBox})
    : _areasBox = areasBox ?? Hive.box('areas') {
    unawaited(_ensureInitialized());
  }

  final Box<dynamic> _areasBox;

  Future<void> _ensureInitialized() async {
    if (_areasBox.get('profiles') == null) {
      await _areasBox.put('profiles', <Profile, List<Area>>{});
    }
  }

  @override
  Map<Profile, List<Area>> readProfiles() {
    final Map<dynamic, dynamic> data = _areasBox.get(
      'profiles',
      defaultValue: <Profile, List<Area>>{},
    );

    final Map<Profile, List<Area>> profiles = data.map<Profile, List<Area>>(
      (k, v) => MapEntry(k as Profile, (v as List<dynamic>).cast<Area>()),
    );

    for (final List<Area> areas in profiles.values) {
      final areaNameCount = <String, int>{};
      for (final area in areas) {
        final int nextOrder = (areaNameCount[area.name] ?? 0) + 1;
        areaNameCount[area.name] = nextOrder;
        area
          ..duplicateOrder = nextOrder
          ..relinkParentReferences();
      }
    }

    return profiles;
  }

  @override
  Future<void> writeProfiles(Map<Profile, List<Area>> profiles) {
    return _areasBox.put('profiles', profiles);
  }
}

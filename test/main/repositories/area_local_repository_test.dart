import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:inventory_count/main/models/data/inventory_models.dart';
import 'package:inventory_count/main/repositories/area_local_repository.dart';

import '../../test_hive_setup.dart';

void main() {
  setUpAll(initializeTestHive);
  tearDownAll(disposeTestHive);
  setUp(resetTestHiveData);

  group('HiveAreaLocalRepository', () {
    test('ensureInitialized seeds missing keys', () async {
      final repository = HiveAreaLocalRepository();

      await Hive.box('areas').delete('profiles');
      await Hive.box('areas').delete('itemIdCounter');
      await repository.ensureInitialized();

      expect(repository.readProfiles(), isEmpty);
      expect(repository.readItemIdCounter(), 0);
    });

    test('reads and writes profiles', () async {
      final repository = HiveAreaLocalRepository();
      final profile = Profile('ER');
      final profiles = <Profile, List<Area>>{
        profile: <Area>[Area('Cabinet')],
      };

      await repository.writeProfiles(profiles);
      final Map<Profile, List<Area>> result = repository.readProfiles();

      expect(result.length, 1);
      expect(result.keys.single.name, 'ER');
      expect(result.values.single.single.name, 'Cabinet');
    });

    test('reads and writes item id counter', () async {
      final repository = HiveAreaLocalRepository();

      await repository.writeItemIdCounter(41);

      expect(repository.readItemIdCounter(), 41);
    });
  });
}

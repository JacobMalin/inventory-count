import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:inventory_count/main/models/data/export_entry.dart';
import 'package:inventory_count/main/repositories/export_local_repository.dart';

import '../../test_hive_setup.dart';

void main() {
  setUpAll(initializeTestHive);
  tearDownAll(disposeTestHive);
  setUp(resetTestHiveData);

  group('HiveExportLocalRepository', () {
    test('ensureInitialized creates empty export list when missing', () async {
      final repository = HiveExportLocalRepository();
      await Hive.box('settings').delete('exportList');

      await repository.ensureInitialized();

      expect(repository.readExportList(), isEmpty);
    });

    test('reads and writes export list', () async {
      final repository = HiveExportLocalRepository();
      final entries = <ExportEntry>[
        ExportTitle('Setup A'),
        ExportItem('Setup B'),
      ];

      await repository.writeExportList(entries);
      final List<ExportEntry> result = repository.readExportList();

      expect(result.length, 2);
      expect(result.first.name, 'Setup A');
      expect(result.last.name, 'Setup B');
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:inventory_count/core/types/json.dart';
import 'package:inventory_count/main/models/data/export_entry.dart';

import '../../../test_hive_setup.dart';

void main() {
  setUpAll(initializeTestHive);
  tearDownAll(disposeTestHive);
  setUp(resetTestHiveData);

  group('ExportEntry JSON', () {
    test('ExportItem.toJson includes omniName', () {
      final item = ExportItem('Popcorn', omniName: 'POPCORN_OMNI');

      final Json json = item.toJson();

      expect(json['type'], 'ExportItem');
      expect(json['name'], 'Popcorn');
      expect(json['omniName'], 'POPCORN_OMNI');
    });

    test('ExportEntry.fromJson restores ExportItem omniName', () {
      final json = <String, dynamic>{
        'type': 'ExportItem',
        'name': 'Nachos',
        'isHidden': false,
        'isNotCounted': false,
        'omniName': 'NACHOS_OMNI',
      };

      final entry = ExportEntry.fromJson(json);

      expect(entry, isA<ExportItem>());
      final item = entry as ExportItem;
      expect(item.name, 'Nachos');
      expect(item.omniName, 'NACHOS_OMNI');
    });
  });

  group('ExportEntry Hive', () {
    test('persists ExportItem omniName through Hive round-trip', () async {
      final entries = <ExportEntry>[
        ExportTitle('Concessions'),
        ExportItem('Popcorn', omniName: 'POPCORN_OMNI'),
      ];

      await Hive.box('settings').put('exportList', entries);

      final List<ExportEntry> result =
          (Hive.box('settings').get('exportList') as List<dynamic>)
              .cast<ExportEntry>()
              .toList();

      expect(result.length, 2);
      expect(result[1], isA<ExportItem>());

      final item = result[1] as ExportItem;
      expect(item.name, 'Popcorn');
      expect(item.omniName, 'POPCORN_OMNI');
    });
  });
}

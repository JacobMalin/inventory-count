import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:inventory_count/main/models/data/inventory_models.dart';

import '../../../test_hive_setup.dart';

void main() {
  setUpAll(initializeTestHive);
  tearDownAll(disposeTestHive);
  setUp(resetTestHiveData);

  group('Item hidden state', () {
    test(
      'round trips through area JSON and defaults missing values to false',
      () {
        final area = Area('Pantry')..addItem('Tea');
        (area[0] as Item).isHidden = true;

        final restored = Area.fromJson(area.toJson());
        expect((restored[0] as Item).isHidden, isTrue);

        final legacyArea = Area.fromJson({
          'name': 'Pantry',
          'shelvesAndItems': [
            {
              'type': 'item',
              'data': {'name': 'Tea'},
            },
          ],
        });
        expect((legacyArea[0] as Item).isHidden, isFalse);
      },
    );

    test('persists through Hive', () async {
      await Hive.box('settings').put('hiddenItem', Item('Tea', isHidden: true));

      final restored = Hive.box('settings').get('hiddenItem') as Item;
      expect(restored.isHidden, isTrue);
    });
  });
}

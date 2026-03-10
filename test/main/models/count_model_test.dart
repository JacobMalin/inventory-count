import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:inventory_count/main/models/count_model.dart';
import 'package:inventory_count/main/models/data/count_strategy.dart';
import 'package:inventory_count/main/models/data/inventory_models.dart';

import '../../test_hive_setup.dart';

void main() {
  setUpAll(initializeTestHive);
  tearDownAll(disposeTestHive);
  setUp(resetTestHiveData);

  Future<Item> buildItemFromAreaJson(
    String name, {
    required int id,
    required CountStrategy strategy,
    String? countName,
    CountPhase countPhase = CountPhase.back,
  }) async {
    final area = Area.fromJson({
      'name': 'Test Area',
      'shelvesAndItems': [
        {
          'type': 'item',
          'data': {
            'name': name,
            'strategy': strategy.toJson(),
            'countName': countName,
            'countPhase': countPhase.index,
          },
        },
      ],
    });

    final item = area[0] as Item;
    await Hive.box('areas').put(id, item);
    return item;
  }

  group('CountModel', () {
    test('updates item count fields and computed value', () async {
      final model = CountModel();
      final Item item = await buildItemFromAreaJson(
        'Gloves',
        id: 101,
        strategy: BoxesAndStacksCountStrategy(4, 2),
        countName: 'Gloves',
        countPhase: CountPhase.cabinet,
      );

      model
        ..setField1(item, 3)
        ..setField2(item, 1);

      final ItemCountType? count = model.getCount(item);
      expect(count, isA<ItemCount>());

      final typedCount = count! as ItemCount;
      expect(typedCount.field1, 3);
      expect(typedCount.field2, 1);
      expect(typedCount.count, 26);
      expect(model.getCountValueByName('Gloves', CountPhase.cabinet), 26);
    });

    test('copies last available count from previous date', () async {
      final model = CountModel();
      final Item item = await buildItemFromAreaJson(
        'Syringe',
        id: 7,
        strategy: SingularCountStrategy(),
      );

      model
        ..setField1(item, 9)
        ..incrementDate();

      expect(model.getCount(item), isNull);

      model.setLastCount(item);

      final ItemCountType? restored = model.getCount(item);
      expect(restored, isA<ItemCount>());
      expect((restored! as ItemCount).field1, 9);
    });

    test('remembers and clears selected profile correctly', () {
      final model = CountModel();
      final profile = Profile('Demo');

      model
        ..isProfileRemembered = true
        ..selectedProfile = profile;

      expect(model.selectedProfile, profile);
      expect(model.rememberedProfile, profile);

      model.selectedProfile = null;

      expect(model.selectedProfile, isNull);
      expect(model.rememberedProfile, isNull);
    });
  });
}

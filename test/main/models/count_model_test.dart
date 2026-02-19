import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_count/main/models/count_model.dart';
import 'package:inventory_count/main/models/data/count_strategy.dart';
import 'package:inventory_count/main/models/data/inventory_models.dart';

import '../../test_hive_setup.dart';

void main() {
  setUpAll(initializeTestHive);
  tearDownAll(disposeTestHive);
  setUp(resetTestHiveData);

  group('CountModel', () {
    test('updates item count fields and computed value', () {
      final model = CountModel();
      final item = Item(
        'Gloves',
        strategy: BoxesAndStacksCountStrategy(4, 2),
        countName: 'Gloves',
        countPhase: CountPhase.cabinet,
        id: 101,
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

    test('copies last available count from previous date', () {
      final model = CountModel();
      final item = Item('Syringe', strategy: SingularCountStrategy(), id: 7);

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

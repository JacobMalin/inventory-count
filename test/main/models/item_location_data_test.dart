import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_count/main/models/data/inventory_models.dart';
import 'package:inventory_count/main/models/item_location_data.dart';

void main() {
  group('ItemLocationData', () {
    test('stores required item and defaults optional fields to null', () {
      final item = Item('Gloves', id: 1);

      final data = ItemLocationData(item);

      expect(identical(data.item, item), isTrue);
      expect(data.area, isNull);
      expect(data.shelf, isNull);
    });

    test('stores provided item, area, and shelf', () {
      final item = Item('Mask', id: 2);
      final area = Area('Main');
      final shelf = Shelf('Top');

      final data = ItemLocationData(item, area: area, shelf: shelf);

      expect(identical(data.item, item), isTrue);
      expect(identical(data.area, area), isTrue);
      expect(identical(data.shelf, shelf), isTrue);
    });
  });
}

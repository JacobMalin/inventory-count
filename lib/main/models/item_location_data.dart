import 'data/inventory_models.dart';

class ItemLocationData {
  ItemLocationData(this.item, {this.area, this.shelf});

  final Item item;
  final Area? area;
  final Shelf? shelf;
}

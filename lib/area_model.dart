import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:inventory_count/area.dart';

class AreaModel with ChangeNotifier {
  var areasBox = Hive.box('areas');

  int get numAreas {
    var currentAreas = areasBox.get('areas');
    return currentAreas?.length ?? 0;
  }

  void addArea(Area area) {
    var currentAreas = areasBox.get('areas', defaultValue: []);
    currentAreas.add(area);
    areasBox.put('areas', currentAreas);
    notifyListeners();
  }

  void removeArea(int index) {
    var currentAreas = areasBox.get('areas');
    currentAreas.removeAt(index);
    areasBox.put('areas', currentAreas);
    notifyListeners();
  }

  Area getArea(int index) {
    return areasBox.get('areas')[index];
  }

  void moveArea(int oldIndex, int newIndex) {
    var currentAreas = areasBox.get('areas');
    currentAreas.insert(newIndex, currentAreas.removeAt(oldIndex));
    areasBox.put('areas', currentAreas);
    notifyListeners();
  }

  void renameArea(int index, String newName) {
    var currentAreas = areasBox.get('areas');
    currentAreas[index].name = newName;
    areasBox.put('areas', currentAreas);
    notifyListeners();
  }

  void addShelfToArea(int areaIndex, Shelf shelf) {
    var currentAreas = areasBox.get('areas');
    currentAreas[areaIndex].shelvesAndItems.add(shelf);
    areasBox.put('areas', currentAreas);
    notifyListeners();
  }

  void addItemToArea(int areaIndex, Item item) {
    var currentAreas = areasBox.get('areas');
    currentAreas[areaIndex].shelvesAndItems.add(item);
    areasBox.put('areas', currentAreas);
    notifyListeners();
  }

  void removeShelfOrItemFromArea(int areaIndex, int index) {
    var currentAreas = areasBox.get('areas');
    currentAreas[areaIndex].shelvesAndItems.removeAt(index);
    areasBox.put('areas', currentAreas);
    notifyListeners();
  }

  void moveShelfOrItemInArea(int areaIndex, int oldIndex, int newIndex) {
    var currentAreas = areasBox.get('areas');
    var shelvesAndItems = currentAreas[areaIndex].shelvesAndItems;
    shelvesAndItems.insert(newIndex, shelvesAndItems.removeAt(oldIndex));
    areasBox.put('areas', currentAreas);
    notifyListeners();
  }

  void renameShelfInArea(int areaIndex, int index, String newName) {
    var currentAreas = areasBox.get('areas');
    currentAreas[areaIndex].shelvesAndItems[index].name = newName;
    areasBox.put('areas', currentAreas);
    notifyListeners();
  }

  void addItemToShelf(int areaIndex, int shelfIndex, Item item) {
    var currentAreas = areasBox.get('areas');
    var shelf = currentAreas[areaIndex].shelvesAndItems[shelfIndex] as Shelf;
    shelf.items.add(item);
    areasBox.put('areas', currentAreas);
    notifyListeners();
  }

  void removeItem(List<int> selectedOrder) {
    var currentAreas = areasBox.get('areas');

    if (selectedOrder.length == 2) {
      // Item is directly in area
      int areaIndex = selectedOrder[0];
      int itemIndex = selectedOrder[1];
      currentAreas[areaIndex].shelvesAndItems.removeAt(itemIndex);
    } else {
      // Item is in shelf
      int areaIndex = selectedOrder[0];
      int shelfIndex = selectedOrder[1];
      int itemIndex = selectedOrder[2];
      var shelf = currentAreas[areaIndex].shelvesAndItems[shelfIndex] as Shelf;
      shelf.items.removeAt(itemIndex);
    }

    areasBox.put('areas', currentAreas);
    notifyListeners();
  }

  void moveItemInShelf(
    int areaIndex,
    int shelfIndex,
    int oldIndex,
    int newIndex,
  ) {
    var currentAreas = areasBox.get('areas');
    var shelf = currentAreas[areaIndex].shelvesAndItems[shelfIndex] as Shelf;
    shelf.items.insert(newIndex, shelf.items.removeAt(oldIndex));
    areasBox.put('areas', currentAreas);
    notifyListeners();
  }

  dynamic getShelfOrItem(List<int> selectedOrder) {
    int areaIndex = selectedOrder[0];
    int index = selectedOrder[1];
    int? index2 = selectedOrder.elementAtOrNull(2);

    var currentAreas = areasBox.get('areas');

    if (index2 != null) {
      var shelf = currentAreas[areaIndex].shelvesAndItems[index] as Shelf;
      return shelf.items[index2];
    }
    return currentAreas[areaIndex].shelvesAndItems[index];
  }

  void editItem(
    List<int> selectedOrder, {
    String? newName,
    int? newCount,
    CountStrategy? newStrategy,
    int? newStrategyInt,
    String? newCountName,
  }) {
    var currentAreas = areasBox.get('areas');
    Item item;

    if (selectedOrder.length == 2) {
      // Item is directly in area
      int areaIndex = selectedOrder[0];
      int itemIndex = selectedOrder[1];
      item = currentAreas[areaIndex].shelvesAndItems[itemIndex] as Item;
    } else {
      // Item is in shelf
      int areaIndex = selectedOrder[0];
      int shelfIndex = selectedOrder[1];
      int itemIndex = selectedOrder[2];
      var shelf = currentAreas[areaIndex].shelvesAndItems[shelfIndex] as Shelf;
      item = shelf.items[itemIndex] as Item;
    }

    if (newName != null) {
      item.name = newName;
    }
    if (newCount != null) {
      item.count = newCount;
    }
    if (newStrategy != null) {
      item.strategy = newStrategy;
    }
    if (newStrategyInt != null) {
      item.strategyInt = newStrategyInt;
    }
    if (newCountName != null) {
      item.countName = newCountName.isEmpty ? null : newCountName;
    }

    areasBox.put('areas', currentAreas);
    notifyListeners();
  }
}

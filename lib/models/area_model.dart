import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:inventory_count/models/count_model.dart';
import 'package:inventory_count/models/count_strategy.dart';
import 'package:inventory_count/models/hive.dart';

class AreaModel with ChangeNotifier {
  final _areasBox = Hive.box('areas');

  int get numAreas {
    var currentAreas = _areasBox.get('areas');
    return currentAreas?.length ?? 0;
  }

  void addArea(Area area) {
    var currentAreas = _areasBox.get('areas', defaultValue: []);
    currentAreas.add(area);
    _areasBox.put('areas', currentAreas);
    notifyListeners();
  }

  void removeArea(int index, CountModel countModel) {
    var currentAreas = _areasBox.get('areas');
    var area = currentAreas[index];

    // Remove all items in the area from count list
    for (var shelfOrItem in area.shelvesAndItems) {
      if (shelfOrItem is Item) {
        countModel.removeFromCountList(shelfOrItem);
      } else if (shelfOrItem is Shelf) {
        // Remove all items in the shelf from count list
        for (var item in shelfOrItem.items) {
          if (item is Item) {
            countModel.removeFromCountList(item);
          }
        }
      }
    }

    currentAreas.removeAt(index);
    _areasBox.put('areas', currentAreas);
    notifyListeners();
  }

  Area getArea(int index) {
    return _areasBox.get('areas')[index];
  }

  void moveArea(int oldIndex, int newIndex) {
    var currentAreas = _areasBox.get('areas');
    currentAreas.insert(newIndex, currentAreas.removeAt(oldIndex));
    _areasBox.put('areas', currentAreas);
    notifyListeners();
  }

  void renameArea(int index, String newName) {
    var currentAreas = _areasBox.get('areas');
    currentAreas[index].name = newName;
    _areasBox.put('areas', currentAreas);
    notifyListeners();
  }

  void addShelfToArea(int areaIndex, Shelf shelf) {
    var currentAreas = _areasBox.get('areas');
    currentAreas[areaIndex].shelvesAndItems.add(shelf);
    _areasBox.put('areas', currentAreas);
    notifyListeners();
  }

  void addItemToArea(int areaIndex, Item item) {
    var currentAreas = _areasBox.get('areas');
    currentAreas[areaIndex].shelvesAndItems.add(item);
    _areasBox.put('areas', currentAreas);
    notifyListeners();
  }

  void removeShelfOrItemFromArea(
    int areaIndex,
    int index,
    CountModel countModel,
  ) {
    var currentAreas = _areasBox.get('areas');
    var shelfOrItem = currentAreas[areaIndex].shelvesAndItems[index];

    // Remove from count list if it's an Item
    if (shelfOrItem is Item) {
      countModel.removeFromCountList(shelfOrItem);
    } else if (shelfOrItem is Shelf) {
      // Remove all items in the shelf from count list
      for (var item in shelfOrItem.items) {
        if (item is Item) {
          countModel.removeFromCountList(item);
        }
      }
    }

    currentAreas[areaIndex].shelvesAndItems.removeAt(index);
    _areasBox.put('areas', currentAreas);
    notifyListeners();
  }

  void moveShelfOrItemInArea(int areaIndex, int oldIndex, int newIndex) {
    var currentAreas = _areasBox.get('areas');
    var shelvesAndItems = currentAreas[areaIndex].shelvesAndItems;
    shelvesAndItems.insert(newIndex, shelvesAndItems.removeAt(oldIndex));
    _areasBox.put('areas', currentAreas);
    notifyListeners();
  }

  void renameShelfInArea(int areaIndex, int index, String newName) {
    var currentAreas = _areasBox.get('areas');
    currentAreas[areaIndex].shelvesAndItems[index].name = newName;
    _areasBox.put('areas', currentAreas);
    notifyListeners();
  }

  void addItemToShelf(int areaIndex, int shelfIndex, Item item) {
    var currentAreas = _areasBox.get('areas');
    var shelf = currentAreas[areaIndex].shelvesAndItems[shelfIndex] as Shelf;
    shelf.items.add(item);
    _areasBox.put('areas', currentAreas);
    notifyListeners();
  }

  void removeItem(List<int> selectedOrder, CountModel countModel) {
    var currentAreas = _areasBox.get('areas');

    Item? itemToRemove;

    if (selectedOrder.length == 2) {
      // Item is directly in area
      int areaIndex = selectedOrder[0];
      int itemIndex = selectedOrder[1];
      itemToRemove = currentAreas[areaIndex].shelvesAndItems[itemIndex] as Item;
      currentAreas[areaIndex].shelvesAndItems.removeAt(itemIndex);
    } else {
      // Item is in shelf
      int areaIndex = selectedOrder[0];
      int shelfIndex = selectedOrder[1];
      int itemIndex = selectedOrder[2];
      var shelf = currentAreas[areaIndex].shelvesAndItems[shelfIndex] as Shelf;
      itemToRemove = shelf.items[itemIndex] as Item;
      shelf.items.removeAt(itemIndex);
    }

    // Remove from count list
    countModel.removeFromCountList(itemToRemove);

    _areasBox.put('areas', currentAreas);
    notifyListeners();
  }

  void moveItemInShelf(
    int areaIndex,
    int shelfIndex,
    int oldIndex,
    int newIndex,
  ) {
    var currentAreas = _areasBox.get('areas');
    var shelf = currentAreas[areaIndex].shelvesAndItems[shelfIndex] as Shelf;
    shelf.items.insert(newIndex, shelf.items.removeAt(oldIndex));
    _areasBox.put('areas', currentAreas);
    notifyListeners();
  }

  dynamic getShelfOrItem(List<int> selectedOrder) {
    int areaIndex = selectedOrder[0];
    int index = selectedOrder[1];
    int? index2 = selectedOrder.elementAtOrNull(2);

    var currentAreas = _areasBox.get('areas');

    if (index2 != null) {
      var shelf = currentAreas[areaIndex].shelvesAndItems[index] as Shelf;
      return shelf.items[index2];
    }
    return currentAreas[areaIndex].shelvesAndItems[index];
  }

  void editItem(
    List<int> selectedOrder, {
    String? newName,
    CountStrategy? newStrategy,
    String? newCountName,
    ItemCount? newDefaultCount,
    CountPhase? newCountPhase,
    CountPhase? newPersonalCountPhase,
    bool? newDoubleChecked,
    CountModel? countModel,
    bool clearDefaultCount = false,
    bool clearPersonalCountPhase = false,
  }) {
    var currentAreas = _areasBox.get('areas');
    Item? item;

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

    var countListNeedsUpdate = false;

    if (newName != null) {
      item.name = newName;

      countListNeedsUpdate = true;
    }
    if (newStrategy != null) {
      item.strategy = newStrategy;
      countListNeedsUpdate = true;
    }
    if (newCountName != null) {
      item.countName = newCountName.isEmpty ? null : newCountName;

      countListNeedsUpdate = true;
    }
    if (newDefaultCount != null) {
      item.defaultCount = newDefaultCount;
    }
    if (clearDefaultCount) {
      item.defaultCount = null;
    }

    if (newCountPhase != null) {
      item.countPhase = newCountPhase;
      countListNeedsUpdate = true;
    }
    if (newPersonalCountPhase != null) {
      item.personalCountPhase = newPersonalCountPhase;
    }
    if (clearPersonalCountPhase) {
      item.personalCountPhase = null;
    }

    _areasBox.put('areas', currentAreas);
    if (countListNeedsUpdate) {
      countModel!.maintainCountList(item);
    }

    notifyListeners();
  }

  String exportAreasToJson() {
    final data = {
      'areas': _areasBox.get('areas').map((item) => item.toJson()).toList(),
      'itemIdCounter': _areasBox.get('itemIdCounter', defaultValue: 0),
    };

    return jsonEncode(data);
  }

  void importAreasFromJson(String jsonString) {
    final data = jsonDecode(jsonString) as Map<String, dynamic>;

    // Import areas
    if (data['areas'] != null) {
      final areasList = (data['areas'] as List)
          .map((json) => Area.fromJson(json as Map<String, dynamic>))
          .toList();
      _areasBox.put('areas', areasList);
    }

    // Import itemIdCounter
    if (data['itemIdCounter'] != null) {
      _areasBox.put('itemIdCounter', data['itemIdCounter']);
    }

    notifyListeners();
  }

  String exportAllToJson() {
    final data = {
      'areas': _areasBox.get('areas'),
      'itemIdCounter': _areasBox.get('itemIdCounter', defaultValue: 0),
    };

    return jsonEncode(
      data.map((key, value) {
        if (value is List && key == 'areas') {
          return MapEntry(key, value.map((item) => item.toJson()).toList());
        }
        return MapEntry(key, value);
      }),
    );
  }

  void importAllFromJson(String jsonString) {
    final data = jsonDecode(jsonString) as Map<String, dynamic>;

    // Import areas
    if (data['areas'] != null) {
      final areasList = (data['areas'] as List)
          .map((json) => Area.fromJson(json as Map<String, dynamic>))
          .toList();

      // Clear existing areas first
      _areasBox.delete('areas');

      // Save the new areas list
      _areasBox.put('areas', areasList);
    }

    // Import itemIdCounter
    if (data['itemIdCounter'] != null) {
      _areasBox.put('itemIdCounter', data['itemIdCounter']);
    }

    notifyListeners();
  }

  bool hasAnyItems() {
    for (int i = 0; i < numAreas; i++) {
      final area = getArea(i);
      for (var shelfOrItem in area.shelvesAndItems) {
        if (shelfOrItem is Shelf) {
          if (shelfOrItem.items.isNotEmpty) {
            return true;
          }
        } else if (shelfOrItem is Item) {
          return true;
        }
      }
    }
    return false;
  }

  List<String> getPathsForItem(String itemName) {
    List<String> paths = [];
    for (int i = 0; i < numAreas; i++) {
      final area = getArea(i);
      String areaName = area.name;
      for (var shelfOrItem in area.shelvesAndItems) {
        if (shelfOrItem is Shelf) {
          String shelfName = shelfOrItem.name;
          for (var item in shelfOrItem.items) {
            if (item is Item && (item.countName ?? item.name) == itemName) {
              paths.add('$areaName > $shelfName > ${item.name}');
            }
          }
        } else if (shelfOrItem is Item &&
            (shelfOrItem.countName ?? shelfOrItem.name) == itemName) {
          paths.add('$areaName > ${shelfOrItem.name}');
        }
      }
    }
    return paths;
  }
}

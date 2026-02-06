import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:inventory_count/models/count_model.dart';
import 'package:inventory_count/models/count_strategy.dart';
import 'package:inventory_count/models/hive.dart';

class AreaModel with ChangeNotifier {
  final _areasBox = Hive.box('areas');

  List<Area> get _areas =>
      _areasBox.get('areas', defaultValue: <Area>[]).cast<Area>();
  set _areas(List<Area> areas) {
    _areasBox.put('areas', areas);
    notifyListeners();
  }

  int get _itemIdCounter => _areasBox.get('itemIdCounter', defaultValue: 0);
  set _itemIdCounter(int value) => _areasBox.put('itemIdCounter', value);

  int get numAreas => _areas.length;

  void addArea(Area area) {
    var currentAreas = _areas;
    currentAreas.add(area);
    _areas = currentAreas;
  }

  void removeArea(int index, CountModel countModel) {
    var currentAreas = _areas;
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
    _areas = currentAreas;
  }

  Area getArea(int index) => _areas[index];

  void moveArea(int oldIndex, int newIndex) {
    var currentAreas = _areas;
    currentAreas.insert(newIndex, currentAreas.removeAt(oldIndex));
    _areas = currentAreas;
  }

  void renameArea(int index, String newName) {
    var currentAreas = _areas;
    currentAreas[index].name = newName;
    _areas = currentAreas;
  }

  void addShelfToArea(int areaIndex, Shelf shelf) {
    var currentAreas = _areas;
    currentAreas[areaIndex].shelvesAndItems.add(shelf);
    _areas = currentAreas;
  }

  void addItemToArea(int areaIndex, Item item) {
    var currentAreas = _areas;
    currentAreas[areaIndex].shelvesAndItems.add(item);
    _areas = currentAreas;
  }

  void removeShelfOrItemFromArea(
    int areaIndex,
    int index,
    CountModel countModel,
  ) {
    var currentAreas = _areas;
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
    _areas = currentAreas;
  }

  void moveShelfOrItemInArea(int areaIndex, int oldIndex, int newIndex) {
    var currentAreas = _areas;
    var shelvesAndItems = currentAreas[areaIndex].shelvesAndItems;
    shelvesAndItems.insert(newIndex, shelvesAndItems.removeAt(oldIndex));
    _areas = currentAreas;
  }

  void renameShelfInArea(int areaIndex, int index, String newName) {
    var currentAreas = _areas;
    currentAreas[areaIndex].shelvesAndItems[index].name = newName;
    _areas = currentAreas;
  }

  void addItemToShelf(int areaIndex, int shelfIndex, Item item) {
    var currentAreas = _areas;
    var shelf = currentAreas[areaIndex].shelvesAndItems[shelfIndex] as Shelf;
    shelf.items.add(item);
    _areas = currentAreas;
  }

  void removeItem(List<int> selectedOrder, CountModel countModel) {
    var currentAreas = _areas;

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

    _areas = currentAreas;
  }

  void moveItemInShelf(
    int areaIndex,
    int shelfIndex,
    int oldIndex,
    int newIndex,
  ) {
    var currentAreas = _areas;
    var shelf = currentAreas[areaIndex].shelvesAndItems[shelfIndex] as Shelf;
    shelf.items.insert(newIndex, shelf.items.removeAt(oldIndex));
    _areas = currentAreas;
  }

  dynamic getShelfOrItem(List<int> selectedOrder) {
    int areaIndex = selectedOrder[0];
    int index = selectedOrder[1];
    int? index2 = selectedOrder.elementAtOrNull(2);

    if (index2 != null) {
      var shelf = _areas[areaIndex].shelvesAndItems[index] as Shelf;
      return shelf.items[index2];
    }
    return _areas[areaIndex].shelvesAndItems[index];
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
    var currentAreas = _areas;
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

    if (countListNeedsUpdate) {
      countModel!.maintainCountList(item);
    }

    _areas = currentAreas;
  }

  String exportAreasToJson() {
    final data = {
      'areas': _areas.map((item) => item.toJson()).toList(),
      'itemIdCounter': _itemIdCounter,
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

      // Clear existing areas first
      _areasBox.delete('areas');

      _areas = areasList;
    }

    // Import itemIdCounter
    if (data['itemIdCounter'] != null) {
      _itemIdCounter = data['itemIdCounter'];
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

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:inventory_count/models/count_model.dart';
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
    maintainExportList();
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
    maintainExportList();
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
    maintainExportList();
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
    maintainExportList();
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
    maintainExportList();
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
    int? newStrategyInt,
    int? newStrategyInt2,
    String? newCountName,
    int? newDefaultCount,
    CountPhase? newCountPhase,
    CountPhase? newPersonalCountPhase,
    CountModel? countModel,
    bool clearDefaultCount = false,
    bool clearStrategyInt = false,
    bool clearStrategyInt2 = false,
  }) {
    var currentAreas = _areasBox.get('areas');
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

    var exportListNeedsUpdate = false;
    var countListNeedsUpdate = false;

    if (newName != null) {
      item.name = newName;

      exportListNeedsUpdate = true;
      countListNeedsUpdate = true;
    }
    if (newStrategy != null) {
      item.strategy = newStrategy;
      countListNeedsUpdate = true;
    }
    if (newStrategyInt != null) {
      item.strategyInt = newStrategyInt;
      countListNeedsUpdate = true;
    }
    if (newStrategyInt2 != null) {
      item.strategyInt2 = newStrategyInt2;
      countListNeedsUpdate = true;
    }
    if (newCountName != null) {
      item.countName = newCountName.isEmpty ? null : newCountName;

      exportListNeedsUpdate = true;
      countListNeedsUpdate = true;
    }
    if (newDefaultCount != null) {
      item.defaultCount = newDefaultCount;
    }
    if (newCountPhase != null) {
      item.countPhase = newCountPhase;
      countListNeedsUpdate = true;
    }
    if (newPersonalCountPhase != null) {
      item.personalCountPhase = newPersonalCountPhase;
    }

    if (clearDefaultCount) {
      item.defaultCount = null;
    }
    if (clearStrategyInt) {
      item.strategyInt = null;
      countListNeedsUpdate = true;
    }
    if (clearStrategyInt2) {
      item.strategyInt2 = null;
      countListNeedsUpdate = true;
    }

    _areasBox.put('areas', currentAreas);
    if (exportListNeedsUpdate) {
      maintainExportList();
    }
    if (countListNeedsUpdate) {
      countModel!.maintainCountList(item);
    }

    notifyListeners();
  }

  List<ExportEntry> get exportList {
    try {
      final dynamic rawList = Hive.box('settings').get('exportList');
      if (rawList == null) {
        return <ExportEntry>[];
      }
      return List<ExportEntry>.from(rawList);
    } on TypeError {
      return <ExportEntry>[];
    }
  }

  void addToExportList(ExportEntry value) {
    var currentExportList = exportList;
    currentExportList.add(value);
    Hive.box('settings').put('exportList', currentExportList);
    notifyListeners();
  }

  void reorderExportList(int oldIndex, int newIndex) {
    var currentExportList = exportList;
    final item = currentExportList.removeAt(oldIndex);
    currentExportList.insert(newIndex, item);
    Hive.box('settings').put('exportList', currentExportList);
    notifyListeners();
  }

  void editExportListEntry(int index, {String? name}) {
    var currentExportList = exportList;
    var entry = currentExportList[index];

    if (name != null) {
      if (entry is ExportItem) {
        throw UnsupportedError('Cannot rename ExportItem entries');
      }

      entry.name = name;
    }

    Hive.box('settings').put('exportList', currentExportList);
    notifyListeners();
  }

  void removeFromExportList(int index) {
    var currentExportList = exportList;
    currentExportList.removeAt(index);
    Hive.box('settings').put('exportList', currentExportList);
    notifyListeners();
  }

  void maintainExportList() {
    var currentExportList = exportList;

    // Gather all current count names
    Set<String> currentCountNames = <String>{};
    Map<String, List<String>> paths = {};
    for (int areaIndex = 0; areaIndex < numAreas; areaIndex++) {
      var area = getArea(areaIndex);
      for (var shelfOrItem in area.shelvesAndItems) {
        if (shelfOrItem is Item) {
          var realCountName = shelfOrItem.countName ?? shelfOrItem.name;
          currentCountNames.add(realCountName);
          if (!paths.containsKey(realCountName)) {
            paths[realCountName] = [];
          }
          paths[realCountName]!.add('${area.name} > ${shelfOrItem.name}');
        } else if (shelfOrItem is Shelf) {
          for (var item in shelfOrItem.items) {
            var realCountName = item.countName ?? item.name;

            currentCountNames.add(realCountName);
            if (!paths.containsKey(realCountName)) {
              paths[realCountName] = [];
            }
            paths[realCountName]!.add(
              '${area.name} > ${shelfOrItem.name} > ${item.name}',
            );
          }
        }
      }
    }

    // Remove any count names that no longer exist
    currentExportList.removeWhere(
      (entry) => entry is ExportItem && !currentCountNames.contains(entry.name),
    );

    // Add any new count names that are not in the export list
    for (var countName in currentCountNames) {
      if (!currentExportList.any(
        (entry) => entry is ExportItem && entry.name == countName,
      )) {
        currentExportList.add(ExportItem(countName));
      }
    }

    for (var entry in currentExportList) {
      if (entry is ExportItem) {
        entry.paths = paths[entry.name] ?? [];
      }
    }

    // Update the export list
    Hive.box('settings').put('exportList', currentExportList);
    notifyListeners();
  }

  String exportAreasToJson() {
    final data = {
      'areas': _areasBox.get('areas'),
      'itemIdCounter': _areasBox.get('itemIdCounter', defaultValue: 0),
    };

    return jsonEncode(
      data.map((key, value) {
        if (value is List) {
          return MapEntry(key, value.map((item) => item.toJson()).toList());
        }
        return MapEntry(key, value);
      }),
    );
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

  String exportExportListToJson() {
    final currentExportList = exportList;

    final data = {
      'exportList': currentExportList.map((entry) => entry.toJson()).toList(),
    };

    return jsonEncode(data);
  }

  void importExportListFromJson(String jsonString) {
    final data = jsonDecode(jsonString) as Map<String, dynamic>;

    // Import export list
    if (data['exportList'] != null) {
      final exportListData = (data['exportList'] as List).map((json) {
        final type = json['type'] as String;
        switch (type) {
          case 'ExportItem':
            return ExportItem.fromJson(json as Map<String, dynamic>);
          case 'ExportTitle':
            return ExportTitle.fromJson(json as Map<String, dynamic>);
          case 'ExportPlaceholder':
            return ExportPlaceholder.fromJson(json as Map<String, dynamic>);
          default:
            throw Exception('Unknown export entry type: $type');
        }
      }).toList();

      Hive.box('settings').put('exportList', exportListData);
      maintainExportList();
    }

    notifyListeners();
  }
}

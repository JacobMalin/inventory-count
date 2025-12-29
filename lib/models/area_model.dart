import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
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

  void removeArea(int index) {
    var currentAreas = _areasBox.get('areas');
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

  void removeShelfOrItemFromArea(int areaIndex, int index) {
    var currentAreas = _areasBox.get('areas');
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

  void removeItem(List<int> selectedOrder) {
    var currentAreas = _areasBox.get('areas');

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
    String? newCountName,
    int? newDefaultCount,
    CountPhase? newCountPhase,
    CountPhase? newPersonalCountPhase,
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

    if (newName != null) {
      item.name = newName;

      exportListNeedsUpdate = true;
    }
    if (newStrategy != null) {
      item.strategy = newStrategy;
    }
    if (newStrategyInt != null) {
      item.strategyInt = newStrategyInt;
    }
    if (newCountName != null) {
      item.countName = newCountName.isEmpty ? null : newCountName;

      exportListNeedsUpdate = true;
    }
    if (newDefaultCount != null) {
      item.defaultCount = newDefaultCount;
    }
    if (newCountPhase != null) {
      item.countPhase = newCountPhase;
    }
    if (newPersonalCountPhase != null) {
      item.personalCountPhase = newPersonalCountPhase;
    }

    _areasBox.put('areas', currentAreas);
    if (exportListNeedsUpdate) {
      maintainExportList();
    }
    notifyListeners();
  }

  List<ExportEntry> get exportList {
    try {
      return Hive.box(
        'settings',
      ).get('exportList', defaultValue: <ExportEntry>[]);
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
}

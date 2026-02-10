import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:inventory_count/models/count_model.dart';
import 'package:inventory_count/models/count_strategy.dart';
import 'package:inventory_count/models/hive.dart';

class AreaModel with ChangeNotifier {
  final _areasBox = Hive.box('areas');

  Map<Profile, List<Area>> get profiles {
    final data = _areasBox.get(
      'profiles',
      defaultValue: <Profile, List<Area>>{
        // TODO: Get rid of
        Profile('default'): _areasBox
            .get('areas', defaultValue: <Area>[])
            .cast<Area>(),
      },
    );
    return (data as Map<dynamic, dynamic>).map<Profile, List<Area>>(
      (k, v) => MapEntry(k as Profile, (v as List<dynamic>).cast<Area>()),
    );
  }

  set profiles(Map<Profile, List<Area>> value) {
    _areasBox.put('profiles', value);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  List<Area> getAreas(Profile profile) {
    final currentProfiles = profiles;

    if (currentProfiles.containsKey(profile)) {
      return currentProfiles[profile]!;
    }

    currentProfiles[profile] = <Area>[];
    profiles = currentProfiles;

    return currentProfiles[profile]!;
  }

  void setAreas(List<Area> areas, Profile profile) {
    final currentProfiles = profiles;

    if (currentProfiles.containsKey(profile)) {
      currentProfiles[profile] = areas;
    } else {
      currentProfiles[profile] = areas;
    }

    profiles = currentProfiles;
  }

  int get _itemIdCounter => _areasBox.get('itemIdCounter', defaultValue: 0);
  set _itemIdCounter(int value) => _areasBox.put('itemIdCounter', value);

  int getNumAreas(Profile profile) => getAreas(profile).length;

  void addArea(Area area, Profile profile) {
    var currentAreas = getAreas(profile);
    currentAreas.add(area);
    setAreas(currentAreas, profile);
  }

  void removeArea(int index, CountModel countModel, Profile profile) {
    var currentAreas = getAreas(profile);
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
    setAreas(currentAreas, profile);
  }

  Area getArea(int index, Profile profile) => getAreas(profile)[index];

  void moveArea(int oldIndex, int newIndex, Profile profile) {
    var currentAreas = getAreas(profile);
    currentAreas.insert(newIndex, currentAreas.removeAt(oldIndex));
    setAreas(currentAreas, profile);
  }

  void renameArea(int index, String newName, Profile profile) {
    var currentAreas = getAreas(profile);
    currentAreas[index].name = newName;
    setAreas(currentAreas, profile);
  }

  void addShelfToArea(int areaIndex, Shelf shelf, Profile profile) {
    var currentAreas = getAreas(profile);
    currentAreas[areaIndex].shelvesAndItems.add(shelf);
    setAreas(currentAreas, profile);
  }

  void addItemToArea(int areaIndex, Item item, Profile profile) {
    var currentAreas = getAreas(profile);
    currentAreas[areaIndex].shelvesAndItems.add(item);
    setAreas(currentAreas, profile);
  }

  void removeShelfOrItemFromArea(
    int areaIndex,
    int index,
    Profile profile,
    CountModel countModel,
  ) {
    var currentAreas = getAreas(profile);
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
    setAreas(currentAreas, profile);
  }

  void moveShelfOrItemInArea(
    int areaIndex,
    int oldIndex,
    int newIndex,
    Profile profile,
  ) {
    var currentAreas = getAreas(profile);
    var shelvesAndItems = currentAreas[areaIndex].shelvesAndItems;
    shelvesAndItems.insert(newIndex, shelvesAndItems.removeAt(oldIndex));
    setAreas(currentAreas, profile);
  }

  void renameShelfInArea(
    int areaIndex,
    int index,
    String newName,
    Profile profile,
  ) {
    var currentAreas = getAreas(profile);
    currentAreas[areaIndex].shelvesAndItems[index].name = newName;
    setAreas(currentAreas, profile);
  }

  void addItemToShelf(
    int areaIndex,
    int shelfIndex,
    Item item,
    Profile profile,
  ) {
    var currentAreas = getAreas(profile);
    var shelf = currentAreas[areaIndex].shelvesAndItems[shelfIndex] as Shelf;
    shelf.items.add(item);
    setAreas(currentAreas, profile);
  }

  void removeItem(
    List<int> selectedOrder,
    Profile profile,
    CountModel countModel,
  ) {
    var currentAreas = getAreas(profile);

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

    setAreas(currentAreas, profile);
  }

  void moveItemInShelf(
    int areaIndex,
    int shelfIndex,
    int oldIndex,
    int newIndex,
    Profile profile,
  ) {
    var currentAreas = getAreas(profile);
    var shelf = currentAreas[areaIndex].shelvesAndItems[shelfIndex] as Shelf;
    shelf.items.insert(newIndex, shelf.items.removeAt(oldIndex));
    setAreas(currentAreas, profile);
  }

  dynamic getShelfOrItem(List<int> selectedOrder, Profile profile) {
    int areaIndex = selectedOrder[0];
    int index = selectedOrder[1];
    int? index2 = selectedOrder.elementAtOrNull(2);

    if (index2 != null) {
      var shelf = getAreas(profile)[areaIndex].shelvesAndItems[index] as Shelf;
      return shelf.items[index2];
    }
    return getAreas(profile)[areaIndex].shelvesAndItems[index];
  }

  void editItem(
    List<int> selectedOrder,
    Profile profile, {
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
    var currentAreas = getAreas(profile);
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

    setAreas(currentAreas, profile);
  }

  String exportAreasToJson() {
    final data = {
      'profiles': profiles.map(
        (profile, areas) => MapEntry(profile.name, areas),
      ),
      'itemIdCounter': _itemIdCounter,
    };

    return jsonEncode(data);
  }

  void importAreasFromJson(String jsonString) {
    final data = jsonDecode(jsonString) as Map<String, dynamic>;

    // Import areas
    if (data['profiles'] != null) {
      final importedProfiles = (data['profiles'] as Map<String, dynamic>).map((
        profileName,
        areasData,
      ) {
        final profile = Profile(profileName);
        final areas = (areasData as List<dynamic>)
            .map((areaData) => Area.fromJson(areaData))
            .toList();
        return MapEntry(profile, areas);
      });
      profiles = importedProfiles;
    }

    // Import itemIdCounter
    if (data['itemIdCounter'] != null) {
      _itemIdCounter = data['itemIdCounter'];
    }

    SchedulerBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  bool hasAnyItems(Profile profile) {
    for (int i = 0; i < getNumAreas(profile); i++) {
      final area = getArea(i, profile);
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

  List<String> getPathsForItem(String itemName, Profile profile) {
    List<String> paths = [];
    for (int i = 0; i < getNumAreas(profile); i++) {
      final area = getArea(i, profile);
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

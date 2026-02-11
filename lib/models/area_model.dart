import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:inventory_count/count_page.dart';
import 'package:inventory_count/models/count_model.dart';
import 'package:inventory_count/models/count_strategy.dart';
import 'package:inventory_count/models/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AreaModel with ChangeNotifier {
  StreamSubscription<List<Map<String, dynamic>>>? _setupsSubscription;
  StreamSubscription<InternetConnectionStatus>? _connectionSubscription;

  final _areasBox = Hive.box('areas');
  CountModel countModel;

  AreaModel(this.countModel) {
    if (_areasBox.get('profiles') == null) {
      _areasBox.put('profiles', <Profile, List<Area>>{});
    }
    if (_areasBox.get('updated_at') == null) {
      _areasBox.put('updated_at', <Profile, DateTime?>{});
    }

    _fetch();
    _listenForChanges();
  }

  Future<void> _fetch() async {
    try {
      final response = await Supabase.instance.client.from('profiles').select();

      _updateFromResponse(response);
    } catch (_) {
      // On fail, do nothing
    }
  }

  void _listenForChanges() {
    try {
      _setupsSubscription = Supabase.instance.client
          .from('profiles')
          .stream(primaryKey: ['updated_at'])
          .listen(
            (data) => _updateFromResponse(data),
            onError: (_) {
              // On fail, do nothing
            },
          );
    } catch (_) {
      // On fail, do nothing
    }

    // Listen for connectivity changes
    try {
      _connectionSubscription = InternetConnectionChecker
          .instance
          .onStatusChange
          .listen((InternetConnectionStatus status) async {
            if (status != InternetConnectionStatus.connected) return;

            await _fetch();
          });
    } catch (_) {
      // On fail, do nothing
    }
  }

  Future<void> _updateFromResponse(List<Map<String, dynamic>> response) async {
    if (response.isEmpty) return;

    final listOfProfiles = response
        .map((entry) => entry['name'] as String)
        .toList();
    final listOfRemoteProfilesInUpdatedAt = updatedAtMap.keys
        .map((profile) => profile.name)
        .toList();

    // Combine all profiles from remote and local
    final allProfileNames = <String>{
      ...listOfProfiles,
      ...listOfRemoteProfilesInUpdatedAt,
    };

    // Batch jobs to push at end
    final Map<Profile, DateTime> profilesToUpdateRemote = {};
    final Map<Profile, DateTime> profilesToDeleteRemote = {};

    // Compare timestamps for each profile
    for (final profileName in allProfileNames) {
      // Get remote data for this profile
      Map<String, dynamic>? remoteEntry;
      DateTime? remoteUpdatedAt;
      bool remoteIsDeleted = false;
      for (final entry in response) {
        if (entry['name'] == profileName) {
          remoteEntry = entry;
          remoteUpdatedAt = entry['updated_at'] != null
              ? DateTime.tryParse(entry['updated_at'].toString())
              : null;
          remoteIsDeleted = entry['deleted'] == true;
          break;
        }
      }

      // TODO: Fix infinite loop

      Profile targetProfile = Profile(profileName);

      // Find matching profile in updatedAtMap
      DateTime? localUpdatedAt = updatedAtMap[targetProfile];
      List<Area>? localAreas = profiles[targetProfile];
      bool localIsDeleted = localAreas == null;

      print('Comparing profile "$profileName":');
      print(
        '  Remote - updatedAt: $remoteUpdatedAt, isDeleted: $remoteIsDeleted',
      );
      print(
        '  Local  - updatedAt: $localUpdatedAt, isDeleted: $localIsDeleted',
      );

      if (remoteUpdatedAt == localUpdatedAt) {
        // Timestamps are the same, no action needed
        continue;
      }

      // Both exist and are different, compare them
      if (localUpdatedAt == null ||
          (remoteUpdatedAt != null &&
              remoteUpdatedAt.isAfter(localUpdatedAt))) {
        if (remoteIsDeleted) {
          // Remote is deleted but local is not, delete locally
          final currentProfiles = profiles;
          currentProfiles.remove(targetProfile);
          profiles = currentProfiles;

          final currentUpdatedAtMap = updatedAtMap;
          currentUpdatedAtMap[targetProfile] = remoteUpdatedAt;
          updatedAtMap = currentUpdatedAtMap;
        } else {
          // Remote is newer, import from remote
          final jsonData = remoteEntry!['json'] is String
              ? remoteEntry['json'] as String
              : jsonEncode(remoteEntry['json']);
          importProfileFromJson(targetProfile, jsonData);

          final newUpdatedAtMap = updatedAtMap;
          newUpdatedAtMap[Profile(profileName)] = remoteUpdatedAt;
          updatedAtMap = newUpdatedAtMap;
        }
      } else {
        if (localIsDeleted) {
          // Local is deleted, queue for remote deletion
          profilesToDeleteRemote[targetProfile] = localUpdatedAt;
        } else {
          // Local is newer, queue for remote update
          profilesToUpdateRemote[targetProfile] = localUpdatedAt;
        }
      }
    }

    // Batch push all changes at the end
    await _batchUpdateSupabase(profilesToUpdateRemote, profilesToDeleteRemote);
  }

  Future<void> _batchUpdateSupabase(
    Map<Profile, DateTime> profilesToUpdate,
    Map<Profile, DateTime> profilesToDelete,
  ) async {
    if (profilesToUpdate.isEmpty && profilesToDelete.isEmpty) return;

    try {
      final List<Map<String, dynamic>> batchData = [];

      // Add updates
      for (final MapEntry(key: profile, value: localUpdatedAt)
          in profilesToUpdate.entries) {
        final jsonString = exportProfileToJson(profile);

        batchData.add({
          'name': profile.name,
          'updated_at': localUpdatedAt.toIso8601String(),
          'json': jsonString,
          'deleted': false,
        });
      }

      // Add deletes
      for (final MapEntry(key: profile, value: localUpdatedAt)
          in profilesToDelete.entries) {
        batchData.add({
          'name': profile.name,
          'deleted': true,
          'updated_at': localUpdatedAt.toIso8601String(),
          'json': "{}",
        });
      }

      // Single batch upsert call
      await Supabase.instance.client.from('profiles').upsert(batchData);
    } catch (_) {
      // On fail, do nothing
    }
  }

  @override
  Future<void> dispose() async {
    await _setupsSubscription?.cancel();
    await _connectionSubscription?.cancel();
    super.dispose();
  }

  void updateSupabase(Profile profile) async {
    try {
      final jsonString = exportProfileToJson(profile);

      final DateTime now = DateTime.now().toUtc();
      final newUpdatedAtMap = updatedAtMap;
      newUpdatedAtMap[profile] = now;
      updatedAtMap = newUpdatedAtMap;

      await Supabase.instance.client.from('profiles').upsert({
        'name': profile.name,
        'updated_at': now.toIso8601String(),
        'json': jsonString,
        'deleted': false,
      });
    } catch (_) {
      // On fail, do nothing
    }
  }

  Future<void> deleteProfileFromSupabase(Profile profile) async {
    try {
      // Soft delete: mark as deleted instead of removing the row
      await Supabase.instance.client.from('profiles').upsert({
        'name': profile.name,
        'deleted': true,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'json': "{}",
      });
    } catch (_) {
      // On fail, keep in set for retry
    }
  }

  Map<Profile, List<Area>> get profiles {
    final data = _areasBox.get(
      'profiles',
      defaultValue: <Profile, List<Area>>{},
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

  Map<Profile, DateTime?> get updatedAtMap {
    final data = _areasBox.get(
      'updated_at',
      defaultValue: <Profile, DateTime?>{},
    );
    return (data as Map<dynamic, dynamic>).map<Profile, DateTime?>(
      (k, v) => MapEntry(k as Profile, v as DateTime?),
    );
  }

  set updatedAtMap(Map<Profile, DateTime?> value) {
    _areasBox.put('updated_at', value);
  }

  List<Area> getAreas() {
    if (countModel.selectedProfile == null) return [];

    final currentProfiles = profiles;

    if (currentProfiles.containsKey(countModel.selectedProfile)) {
      return currentProfiles[countModel.selectedProfile]!;
    }

    currentProfiles[countModel.selectedProfile!] = <Area>[];
    profiles = currentProfiles;

    return currentProfiles[countModel.selectedProfile]!;
  }

  void setAreas(List<Area> areas) {
    if (countModel.selectedProfile == null) return;

    final currentProfiles = profiles;
    final currentUpdatedAtMap = updatedAtMap;

    currentProfiles[countModel.selectedProfile!] = areas;
    currentUpdatedAtMap[countModel.selectedProfile!] = DateTime.now().toUtc();

    profiles = currentProfiles;
    updatedAtMap = currentUpdatedAtMap;

    updateSupabase(countModel.selectedProfile!);
  }

  int get _itemIdCounter => _areasBox.get('itemIdCounter', defaultValue: 0);
  set _itemIdCounter(int value) => _areasBox.put('itemIdCounter', value);

  int get numAreas => getAreas().length;

  void addArea(Area area) {
    var currentAreas = getAreas();
    currentAreas.add(area);
    setAreas(currentAreas);
  }

  void removeArea(int index) {
    var currentAreas = getAreas();
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
    setAreas(currentAreas);
  }

  Area getArea(int index) => getAreas()[index];

  void moveArea(int oldIndex, int newIndex) {
    var currentAreas = getAreas();
    currentAreas.insert(newIndex, currentAreas.removeAt(oldIndex));
    setAreas(currentAreas);
  }

  void renameArea(int index, String newName) {
    var currentAreas = getAreas();
    currentAreas[index].name = newName;
    setAreas(currentAreas);
  }

  void addShelfToArea(int areaIndex, Shelf shelf) {
    var currentAreas = getAreas();
    currentAreas[areaIndex].shelvesAndItems.add(shelf);
    setAreas(currentAreas);
  }

  void addItemToArea(int areaIndex, Item item) {
    var currentAreas = getAreas();
    currentAreas[areaIndex].shelvesAndItems.add(item);
    setAreas(currentAreas);
  }

  void removeShelfOrItemFromArea(int areaIndex, int index) {
    var currentAreas = getAreas();
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
    setAreas(currentAreas);
  }

  void moveShelfOrItemInArea(int areaIndex, int oldIndex, int newIndex) {
    var currentAreas = getAreas();
    var shelvesAndItems = currentAreas[areaIndex].shelvesAndItems;
    shelvesAndItems.insert(newIndex, shelvesAndItems.removeAt(oldIndex));
    setAreas(currentAreas);
  }

  void renameShelfInArea(int areaIndex, int index, String newName) {
    var currentAreas = getAreas();
    currentAreas[areaIndex].shelvesAndItems[index].name = newName;
    setAreas(currentAreas);
  }

  void addItemToShelf(int areaIndex, int shelfIndex, Item item) {
    var currentAreas = getAreas();
    var shelf = currentAreas[areaIndex].shelvesAndItems[shelfIndex] as Shelf;
    shelf.items.add(item);
    setAreas(currentAreas);
  }

  void removeItem(List<int> selectedOrder) {
    var currentAreas = getAreas();

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

    setAreas(currentAreas);
  }

  void moveItemInShelf(
    int areaIndex,
    int shelfIndex,
    int oldIndex,
    int newIndex,
  ) {
    var currentAreas = getAreas();
    var shelf = currentAreas[areaIndex].shelvesAndItems[shelfIndex] as Shelf;
    shelf.items.insert(newIndex, shelf.items.removeAt(oldIndex));
    setAreas(currentAreas);
  }

  dynamic getShelfOrItem(List<int> selectedOrder) {
    int areaIndex = selectedOrder[0];
    int index = selectedOrder[1];
    int? index2 = selectedOrder.elementAtOrNull(2);

    if (index2 != null) {
      var shelf = getAreas()[areaIndex].shelvesAndItems[index] as Shelf;
      return shelf.items[index2];
    }
    return getAreas()[areaIndex].shelvesAndItems[index];
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
    bool clearDefaultCount = false,
    bool clearPersonalCountPhase = false,
  }) {
    var currentAreas = getAreas();
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
      countModel.maintainCountList(item);
    }

    setAreas(currentAreas);
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

  String exportProfileToJson(Profile profile) {
    final currentProfiles = profiles;
    final areas = currentProfiles[profile] ?? [];

    final data = {'areas': areas};

    return jsonEncode(data);
  }

  void importProfileFromJson(Profile profile, String jsonString) {
    final data = jsonDecode(jsonString) as Map<String, dynamic>;

    // Import areas for this specific profile
    if (data['areas'] != null) {
      final areas = (data['areas'] as List<dynamic>)
          .map((areaData) => Area.fromJson(areaData))
          .toList();

      final currentProfiles = profiles;
      currentProfiles[profile] = areas;
      profiles = currentProfiles;
    }

    SchedulerBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
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

  List<ItemTreeData> findItemsByName(String name, CountPhase phase) {
    List<int> itemIds = [];
    List<ItemTreeData> items = [];

    if (countModel.selectedProfile == null) return [];

    for (final MapEntry<int, CountEntry> entry
        in countModel.itemCounts.entries) {
      if (entry.value.name == name && entry.value.phase == phase) {
        itemIds.add(entry.key);
      }
    }

    for (int i = 0; i < numAreas; i++) {
      final area = getArea(i);
      for (var shelfOrItem in area.shelvesAndItems) {
        if (shelfOrItem is Item) {
          if (itemIds.contains(shelfOrItem.id)) {
            items.add(ItemTreeData(shelfOrItem, area: area));
          }
        } else if (shelfOrItem is Shelf) {
          for (var item in shelfOrItem.items) {
            if (itemIds.contains(item.id)) {
              items.add(ItemTreeData(item, area: area, shelf: shelfOrItem));
            }
          }
        }
      }
    }

    return items;
  }
}

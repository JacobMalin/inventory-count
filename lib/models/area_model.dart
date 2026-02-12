import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../count_page.dart';
import 'count_model.dart';
import 'count_strategy.dart';
import 'hive.dart';

class AreaModel with ChangeNotifier {
  AreaModel(this.countModel) {
    if (_areasBox.get('profiles') == null) {
      unawaited(_areasBox.put('profiles', <Profile, List<Area>>{}));
    }
    if (_areasBox.get('updated_at') == null) {
      unawaited(_areasBox.put('updated_at', <Profile, DateTime?>{}));
    }

    unawaited(_fetch());
    _listenForChanges();
  }

  StreamSubscription<List<Map<String, dynamic>>>? _setupsSubscription;
  StreamSubscription<InternetConnectionStatus>? _connectionSubscription;

  final Box<dynamic> _areasBox = Hive.box('areas');
  CountModel countModel;

  Future<void> _fetch() async {
    try {
      final PostgrestList response = await Supabase.instance.client
          .from('profiles')
          .select();

      await _updateFromResponse(response);
    } on Exception catch (_) {
      // On fail, do nothing
    }
  }

  void _listenForChanges() {
    try {
      _setupsSubscription = Supabase.instance.client
          .from('profiles')
          .stream(primaryKey: ['updated_at'])
          .listen(
            _updateFromResponse,
            onError: (_) {
              // On fail, do nothing
            },
          );
    } on Exception catch (_) {
      // On fail, do nothing
    }

    // Listen for connectivity changes
    try {
      _connectionSubscription = InternetConnectionChecker
          .instance
          .onStatusChange
          .listen((status) async {
            if (status != InternetConnectionStatus.connected) return;

            await _fetch();
          });
    } on Exception catch (_) {
      // On fail, do nothing
    }
  }

  Future<void> _updateFromResponse(List<Map<String, dynamic>> response) async {
    if (response.isEmpty) return;

    final List<String> listOfProfiles = response
        .map((entry) => entry['name'] as String)
        .toList();
    final List<String> listOfRemoteProfilesInUpdatedAt = updatedAtMap.keys
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
      var remoteIsDeleted = false;
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

      final targetProfile = Profile(profileName);

      // Find matching profile in updatedAtMap
      final DateTime? localUpdatedAt = updatedAtMap[targetProfile];
      final List<Area>? localAreas = profiles[targetProfile];
      final localIsDeleted = localAreas == null;

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
          final Map<Profile, List<Area>> currentProfiles = profiles
            ..remove(targetProfile);
          profiles = currentProfiles;

          final Map<Profile, DateTime?> currentUpdatedAtMap = updatedAtMap;
          currentUpdatedAtMap[targetProfile] = remoteUpdatedAt;
          updatedAtMap = currentUpdatedAtMap;
        } else {
          // Remote is newer, import from remote
          final String jsonData = remoteEntry!['json'] is String
              ? remoteEntry['json'] as String
              : jsonEncode(remoteEntry['json']);
          importProfileFromJson(targetProfile, jsonData);

          final Map<Profile, DateTime?> newUpdatedAtMap = updatedAtMap;
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
        final String jsonString = exportProfileToJson(profile);

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
          'json': '{}',
        });
      }

      // Single batch upsert call
      await Supabase.instance.client.from('profiles').upsert(batchData);
    } on Exception catch (_) {
      // On fail, do nothing
    }
  }

  @override
  Future<void> dispose() async {
    await _setupsSubscription?.cancel();
    await _connectionSubscription?.cancel();
    super.dispose();
  }

  void updateSupabase(Profile profile) {
    try {
      final String jsonString = exportProfileToJson(profile);

      final DateTime now = DateTime.now().toUtc();
      final Map<Profile, DateTime?> newUpdatedAtMap = updatedAtMap;
      newUpdatedAtMap[profile] = now;
      updatedAtMap = newUpdatedAtMap;

      unawaited(
        Supabase.instance.client.from('profiles').upsert({
          'name': profile.name,
          'updated_at': now.toIso8601String(),
          'json': jsonString,
          'deleted': false,
        }),
      );
    } on Exception catch (_) {
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
        'json': '{}',
      });
    } on Exception catch (_) {
      // On fail, keep in set for retry
    }
  }

  Map<Profile, List<Area>> get profiles {
    final Map<dynamic, dynamic> data = _areasBox.get(
      'profiles',
      defaultValue: <Profile, List<Area>>{},
    );
    return data.map<Profile, List<Area>>(
      (k, v) => MapEntry(k as Profile, (v as List<dynamic>).cast<Area>()),
    );
  }

  set profiles(Map<Profile, List<Area>> value) {
    unawaited(_areasBox.put('profiles', value));
    SchedulerBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  Map<Profile, DateTime?> get updatedAtMap {
    final Map<dynamic, dynamic> data = _areasBox.get(
      'updated_at',
      defaultValue: <Profile, DateTime?>{},
    );
    return data.map<Profile, DateTime?>(
      (k, v) => MapEntry(k as Profile, v as DateTime?),
    );
  }

  set updatedAtMap(Map<Profile, DateTime?> value) {
    unawaited(_areasBox.put('updated_at', value));
  }

  List<Area> getAreas() {
    if (countModel.selectedProfile == null) return [];

    final Map<Profile, List<Area>> currentProfiles = profiles;

    if (currentProfiles.containsKey(countModel.selectedProfile)) {
      return currentProfiles[countModel.selectedProfile]!;
    }

    currentProfiles[countModel.selectedProfile!] = <Area>[];
    profiles = currentProfiles;

    return currentProfiles[countModel.selectedProfile]!;
  }

  void setAreas(List<Area> areas) {
    if (countModel.selectedProfile == null) return;

    final Map<Profile, List<Area>> currentProfiles = profiles;
    final Map<Profile, DateTime?> currentUpdatedAtMap = updatedAtMap;

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
    final List<Area> currentAreas = getAreas()..add(area);
    setAreas(currentAreas);
  }

  void removeArea(int index) {
    final List<Area> currentAreas = getAreas();
    final Area area = currentAreas[index];

    // Remove all items in the area from count list
    for (final StorageObject shelfOrItem in area.shelvesAndItems) {
      if (shelfOrItem is Item) {
        countModel.removeFromCountList(shelfOrItem);
      } else if (shelfOrItem is Shelf) {
        // Remove all items in the shelf from count list
        shelfOrItem.items.forEach(countModel.removeFromCountList);
      }
    }

    currentAreas.removeAt(index);
    setAreas(currentAreas);
  }

  Area getArea(int index) => getAreas()[index];

  void moveArea(int oldIndex, int newIndex) {
    final List<Area> currentAreas = getAreas();
    currentAreas.insert(newIndex, currentAreas.removeAt(oldIndex));
    setAreas(currentAreas);
  }

  void renameArea(int index, String newName) {
    final List<Area> currentAreas = getAreas();
    currentAreas[index].name = newName;
    setAreas(currentAreas);
  }

  void addShelfToArea(int areaIndex, Shelf shelf) {
    final List<Area> currentAreas = getAreas();
    currentAreas[areaIndex].shelvesAndItems.add(shelf);
    setAreas(currentAreas);
  }

  void addItemToArea(int areaIndex, Item item) {
    final List<Area> currentAreas = getAreas();
    currentAreas[areaIndex].shelvesAndItems.add(item);
    setAreas(currentAreas);
  }

  void removeShelfOrItemFromArea(int areaIndex, int index) {
    final List<Area> currentAreas = getAreas();
    final StorageObject shelfOrItem =
        currentAreas[areaIndex].shelvesAndItems[index];

    // Remove from count list if it's an Item
    if (shelfOrItem is Item) {
      countModel.removeFromCountList(shelfOrItem);
    } else if (shelfOrItem is Shelf) {
      // Remove all items in the shelf from count list
      shelfOrItem.items.forEach(countModel.removeFromCountList);
    }

    currentAreas[areaIndex].shelvesAndItems.removeAt(index);
    setAreas(currentAreas);
  }

  void moveShelfOrItemInArea(int areaIndex, int oldIndex, int newIndex) {
    final List<Area> currentAreas = getAreas();
    final List<StorageObject> shelvesAndItems =
        currentAreas[areaIndex].shelvesAndItems;
    shelvesAndItems.insert(newIndex, shelvesAndItems.removeAt(oldIndex));
    setAreas(currentAreas);
  }

  void renameShelfInArea(int areaIndex, int index, String newName) {
    final List<Area> currentAreas = getAreas();
    currentAreas[areaIndex].shelvesAndItems[index].name = newName;
    setAreas(currentAreas);
  }

  void addItemToShelf(int areaIndex, int shelfIndex, Item item) {
    final List<Area> currentAreas = getAreas();
    final shelf = currentAreas[areaIndex].shelvesAndItems[shelfIndex] as Shelf;
    shelf.items.add(item);
    setAreas(currentAreas);
  }

  void removeItem(List<int> selectedOrder) {
    final List<Area> currentAreas = getAreas();

    Item? itemToRemove;

    if (selectedOrder.length == 2) {
      // Item is directly in area
      final int areaIndex = selectedOrder[0];
      final int itemIndex = selectedOrder[1];
      itemToRemove = currentAreas[areaIndex].shelvesAndItems[itemIndex] as Item;
      currentAreas[areaIndex].shelvesAndItems.removeAt(itemIndex);
    } else {
      // Item is in shelf
      final int areaIndex = selectedOrder[0];
      final int shelfIndex = selectedOrder[1];
      final int itemIndex = selectedOrder[2];
      final shelf =
          currentAreas[areaIndex].shelvesAndItems[shelfIndex] as Shelf;
      itemToRemove = shelf.items[itemIndex];
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
    final List<Area> currentAreas = getAreas();
    final shelf = currentAreas[areaIndex].shelvesAndItems[shelfIndex] as Shelf;
    shelf.items.insert(newIndex, shelf.items.removeAt(oldIndex));
    setAreas(currentAreas);
  }

  dynamic getShelfOrItem(List<int> selectedOrder) {
    final int areaIndex = selectedOrder[0];
    final int index = selectedOrder[1];
    final int? index2 = selectedOrder.elementAtOrNull(2);

    if (index2 != null) {
      final shelf = getAreas()[areaIndex].shelvesAndItems[index] as Shelf;
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
    final List<Area> currentAreas = getAreas();
    Item? item;

    if (selectedOrder.length == 2) {
      // Item is directly in area
      final int areaIndex = selectedOrder[0];
      final int itemIndex = selectedOrder[1];
      item = currentAreas[areaIndex].shelvesAndItems[itemIndex] as Item;
    } else {
      // Item is in shelf
      final int areaIndex = selectedOrder[0];
      final int shelfIndex = selectedOrder[1];
      final int itemIndex = selectedOrder[2];
      final shelf =
          currentAreas[areaIndex].shelvesAndItems[shelfIndex] as Shelf;
      item = shelf.items[itemIndex];
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
    final Map<String, Object> data = {
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
      final Map<Profile, List<Area>> importedProfiles =
          (data['profiles'] as Map<String, dynamic>).map((
            profileName,
            areasData,
          ) {
            final profile = Profile(profileName);
            final List<Area> areas = (areasData as List<dynamic>)
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
    final Map<Profile, List<Area>> currentProfiles = profiles;
    final List<Area> areas = currentProfiles[profile] ?? [];

    final data = {'areas': areas};

    return jsonEncode(data);
  }

  void importProfileFromJson(Profile profile, String jsonString) {
    final data = jsonDecode(jsonString) as Map<String, dynamic>;

    // Import areas for this specific profile
    if (data['areas'] != null) {
      final List<Area> areas = (data['areas'] as List<dynamic>)
          .map((areaData) => Area.fromJson(areaData))
          .toList();

      final Map<Profile, List<Area>> currentProfiles = profiles;
      currentProfiles[profile] = areas;
      profiles = currentProfiles;
    }

    SchedulerBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  bool hasAnyItems() {
    for (var i = 0; i < numAreas; i++) {
      final Area area = getArea(i);
      for (final StorageObject shelfOrItem in area.shelvesAndItems) {
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
    final List<String> paths = [];
    for (var i = 0; i < numAreas; i++) {
      final Area area = getArea(i);
      final String areaName = area.name;
      for (final StorageObject shelfOrItem in area.shelvesAndItems) {
        if (shelfOrItem is Shelf) {
          final String shelfName = shelfOrItem.name;
          for (final Item item in shelfOrItem.items) {
            if ((item.countName ?? item.name) == itemName) {
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
    final List<int> itemIds = [];
    final List<ItemTreeData> items = [];

    if (countModel.selectedProfile == null) return [];

    for (final MapEntry<int, CountEntry> entry
        in countModel.itemCounts.entries) {
      if (entry.value.name == name && entry.value.phase == phase) {
        itemIds.add(entry.key);
      }
    }

    for (var i = 0; i < numAreas; i++) {
      final Area area = getArea(i);
      for (final StorageObject shelfOrItem in area.shelvesAndItems) {
        if (shelfOrItem is Item) {
          if (itemIds.contains(shelfOrItem.id)) {
            items.add(ItemTreeData(shelfOrItem, area: area));
          }
        } else if (shelfOrItem is Shelf) {
          for (final Item item in shelfOrItem.items) {
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

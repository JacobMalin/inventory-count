import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/types/json.dart';
import '../repositories/area_local_repository.dart';
import '../repositories/area_sync_repository.dart';
import '../repositories/device_id.dart';
import 'count_model.dart';
import 'data/count_strategy.dart';
import 'data/inventory_models.dart';
import 'sync_change_notifier.dart';
import 'sync_coordinator.dart';

class AreaModel extends LocalSyncChangeNotifier {
  AreaModel({
    required this.countModel,
    required SyncCoordinator syncCoordinator,
    AreaLocalRepository? localRepository,
    AreaSyncRepository? syncRepository,
    super.disableSync,
  }) : _localRepository = localRepository ?? HiveAreaLocalRepository(),
       _syncRepository = syncRepository ?? SupabaseAreaSyncRepository(),
       _syncCoordinator = syncCoordinator {
    unawaited(_localRepository.ensureInitialized());

    initializeSync(fetchInitial: _fetch, listenForChanges: _listenForChanges);
  }

  RealtimeChannel? _setupsSubscription;

  final AreaLocalRepository _localRepository;
  final AreaSyncRepository _syncRepository;
  final SyncCoordinator _syncCoordinator;

  CountModel countModel;

  final _notYetDeletedProfiles = <Profile>{};

  // TODO: Merge many of these functions into the sync repository
  // TODO: Make storageobjects save themselves

  Future<void> _fetch() async {
    try {
      final List<AreaSyncRecord> response = await _syncRepository
          .fetchProfiles();

      await _updateFromResponse(response);
    } on Exception catch (e) {
      logSyncError('Failed to fetch profiles from Supabase', e);
    }
  }

  Future<void> _listenForChanges() async {
    try {
      Future<void> reconnect() async {
        for (final profile in List<Profile>.from(_notYetDeletedProfiles)) {
          _notYetDeletedProfiles.remove(profile);
          await deleteProfileFromSupabase(profile);
        }

        await _fetch();
        await _setupsSubscription?.unsubscribe();
        final String ownUdid = await DeviceId.getDeviceId();
        _setupsSubscription = _syncRepository.subscribeProfileChanges(
          excludedUdid: ownUdid,
          onChange: _updateSingleFromResponse,
        );
      }

      registerReconnectCallback(reconnect);
    } on Exception catch (e) {
      logSyncError('Failed to register reconnect callback', e);
    }
  }

  Future<void> _updateFromResponse(List<AreaSyncRecord> response) async {
    if (response.isEmpty) return;

    final Map<String, AreaSyncRecord> profilesByName = {
      for (final AreaSyncRecord entry in response) entry.name: entry,
    };

    final List<String> remoteProfiles = profilesByName.keys.toList();

    // Batch jobs to push at end
    final Map<Profile, DateTime> profilesToUpdateRemote = {};

    await _syncCoordinator.reconcileCollection<AreaSyncRecord, Profile>(
      remoteRecords: profilesByName.values,
      keyOf: (record) => Profile(record.name),
      remoteUdid: (record) => record.udid,
      remoteUpdatedAt: (record) => record.updatedAt,
      localUpdatedAtOf: (profile) => _updatedAtMap[profile],
      onPullRemote: (profile, record, remoteUpdatedAt) async {
        importProfileFromJson(profile, record.json);

        final Map<Profile, DateTime?> newUpdatedAtMap = _updatedAtMap;
        newUpdatedAtMap[profile] = remoteUpdatedAt;
        _updatedAtMap = newUpdatedAtMap;
      },
      onPushLocal: (profile, localUpdatedAt) async {
        profilesToUpdateRemote[profile] = localUpdatedAt;
      },
    );

    // Batch push all changes at the end
    await _batchUpdateSupabase(profilesToUpdateRemote);

    // Handle deleted profiles
    final Set<String> localProfiles = {
      ..._updatedAtMap.keys.map((profile) => profile.name),
      ...profiles.keys.map((profile) => profile.name),
    };
    final List<String> profilesToDelete = localProfiles
        .where((localProfile) => !remoteProfiles.contains(localProfile))
        .toList();
    for (final profileName in profilesToDelete) {
      final targetProfile = Profile(profileName);
      final Map<Profile, List<Area>> currentProfiles = profiles
        ..remove(targetProfile);
      profiles = currentProfiles;

      final Map<Profile, DateTime?> newUpdatedAtMap = _updatedAtMap
        ..remove(targetProfile);
      _updatedAtMap = newUpdatedAtMap;
    }
  }

  Future<void> _updateSingleFromResponse(AreaSyncChange payload) async {
    if (payload.type == AreaSyncChangeType.delete) {
      final String? profileName = payload.deletedName;
      if (profileName == null) return;

      final targetProfile = Profile(profileName);

      final Map<Profile, List<Area>> currentProfiles = profiles
        ..remove(targetProfile);
      profiles = currentProfiles;

      final Map<Profile, DateTime?> newUpdatedAtMap = _updatedAtMap
        ..remove(targetProfile);
      _updatedAtMap = newUpdatedAtMap;

      return;
    }

    final AreaSyncRecord? newRecord = payload.record;
    if (newRecord != null) {
      await _syncCoordinator.reconcileSingle<AreaSyncRecord>(
        remoteRecord: newRecord,
        remoteUdid: (record) => record.udid,
        remoteUpdatedAt: (record) => record.updatedAt,
        localUpdatedAt: _updatedAtMap[Profile(newRecord.name)],
        onPullRemote: (record, remoteUpdatedAt) async {
          final targetProfile = Profile(record.name);
          importProfileFromJson(targetProfile, record.json);

          final Map<Profile, DateTime?> newUpdatedAtMap = _updatedAtMap;
          newUpdatedAtMap[targetProfile] = remoteUpdatedAt;
          _updatedAtMap = newUpdatedAtMap;
        },
        onPushLocal: () async {
          // Single change stream only reflects remote updates; local wins are
          // already pushed by local mutations.
        },
      );
    }
  }

  Future<void> _batchUpdateSupabase(
    Map<Profile, DateTime> profilesToUpdate,
  ) async {
    if (profilesToUpdate.isEmpty) return;

    try {
      final String ownUdid = await DeviceId.getDeviceId();
      final List<AreaSyncRecord> batchData = [];

      // Add updates
      for (final MapEntry(key: profile, value: localUpdatedAt)
          in profilesToUpdate.entries) {
        final String jsonString = exportProfileToJson(profile);

        batchData.add(
          AreaSyncRecord(
            name: profile.name,
            updatedAt: localUpdatedAt,
            json: jsonString,
            udid: ownUdid,
          ),
        );
      }

      // Single batch upsert call
      await _syncRepository.batchUpsertProfiles(batchData);
    } on Exception catch (e) {
      logSyncError('Failed to batch update profiles to Supabase', e);
    }
  }

  @override
  Future<void> dispose() async {
    await unregisterReconnectCallbacks();
    await _setupsSubscription?.unsubscribe();
    super.dispose();
  }

  void updateSupabase(Profile profile) {
    final String jsonString = exportProfileToJson(profile);

    final DateTime now = DateTime.now().toUtc();
    final Map<Profile, DateTime?> newUpdatedAtMap = _updatedAtMap;
    newUpdatedAtMap[profile] = now;
    _updatedAtMap = newUpdatedAtMap;

    unawaited(() async {
      final String ownUdid = await DeviceId.getDeviceId();

      await _syncRepository
          .upsertProfile(
            AreaSyncRecord(
              name: profile.name,
              updatedAt: now,
              json: jsonString,
              udid: ownUdid,
            ),
          )
          .onError((error, _) {
            if (kDebugMode) {
              print(
                'Failed to update profile "${profile.name}" to Supabase: '
                '$error',
              );
            }
          });
    }());
  }

  Future<void> deleteProfileFromSupabase(Profile profile) async {
    final Map<Profile, DateTime?> newUpdatedAtMap = _updatedAtMap
      ..remove(profile);
    _updatedAtMap = newUpdatedAtMap;

    try {
      await _syncRepository.deleteProfile(profile.name);
    } on Exception catch (error) {
      _notYetDeletedProfiles.add(profile);

      if (kDebugMode) {
        print(
          'Failed to delete profile "${profile.name}" from Supabase: $error',
        );
      }
    }
  }

  Map<Profile, List<Area>> get profiles => _localRepository.readProfiles();

  set profiles(Map<Profile, List<Area>> value) {
    unawaited(_localRepository.writeProfiles(value));
    SchedulerBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  Map<Profile, DateTime?> _updatedAtMap = {};

  void _reindexAreaDuplicateOrders(List<Area> areas) {
    final areaNameCount = <String, int>{};
    for (final area in areas) {
      final int nextOrder = (areaNameCount[area.name] ?? 0) + 1;
      areaNameCount[area.name] = nextOrder;
      area
        ..duplicateOrder = nextOrder
        ..relinkParentReferences();
    }
  }

  List<Area> getAreas() {
    if (countModel.selectedProfile == null) return [];

    final Map<Profile, List<Area>> currentProfiles = profiles;

    if (currentProfiles.containsKey(countModel.selectedProfile)) {
      return currentProfiles[countModel.selectedProfile]!;
    }

    countModel.selectedProfile = null;

    return [];
  }

  void setAreas(List<Area> areas) {
    if (countModel.selectedProfile == null) return;

    _reindexAreaDuplicateOrders(areas);

    final Map<Profile, List<Area>> currentProfiles = profiles;
    currentProfiles[countModel.selectedProfile!] = areas;
    profiles = currentProfiles;

    updateSupabase(countModel.selectedProfile!);
  }

  int get numAreas => getAreas().length;

  void addArea(Area area) {
    final List<Area> currentAreas = getAreas()..add(area);
    setAreas(currentAreas);
  }

  void removeArea(Area area) {
    final List<Area> currentAreas = getAreas();
    // Remove all items in the area from count list
    area.forEachItem(countModel.removeFromCountList);

    currentAreas.remove(area);
    setAreas(currentAreas);
  }

  Area getArea(int index) => getAreas()[index];

  void moveArea(Area area, int newIndex) {
    final List<Area> currentAreas = getAreas();
    final int oldIndex = currentAreas.indexOf(area);
    if (oldIndex == -1) return;
    currentAreas.insert(newIndex, currentAreas.removeAt(oldIndex));
    setAreas(currentAreas);
  }

  void renameArea(Area area, String newName) {
    final List<Area> currentAreas = getAreas();
    final int index = currentAreas.indexOf(area);
    if (index == -1) return;
    currentAreas[index].name = newName;
    setAreas(currentAreas);
  }

  void addShelfToArea(int areaIndex, String shelfName) {
    final List<Area> currentAreas = getAreas();
    currentAreas[areaIndex].addShelf(shelfName);
    setAreas(currentAreas);
  }

  void addItemToArea(int areaIndex, String itemName) {
    final List<Area> currentAreas = getAreas();
    currentAreas[areaIndex].addItem(itemName);
    setAreas(currentAreas);
  }

  void removeShelfOrItemFromArea(int areaIndex, int index) {
    final List<Area> currentAreas = getAreas();
    final StorageObject shelfOrItem = currentAreas[areaIndex][index];

    // Remove from count list if it's an Item
    if (shelfOrItem is Item) {
      countModel.removeFromCountList(shelfOrItem);
    } else if (shelfOrItem is Shelf) {
      // Remove all items in the shelf from count list
      shelfOrItem.forEach(countModel.removeFromCountList);
    }

    currentAreas[areaIndex].removeAt(index);
    setAreas(currentAreas);
  }

  void moveShelfOrItemInArea(int areaIndex, int oldIndex, int newIndex) {
    final List<Area> currentAreas = getAreas();
    currentAreas[areaIndex].insert(
      newIndex,
      currentAreas[areaIndex].removeAt(oldIndex),
    );
    setAreas(currentAreas);
  }

  void renameShelfInArea(int areaIndex, int index, String newName) {
    final List<Area> currentAreas = getAreas();
    currentAreas[areaIndex][index].name = newName;
    setAreas(currentAreas);
  }

  void addItemToShelf(int areaIndex, int shelfIndex, String itemName) {
    final List<Area> currentAreas = getAreas();
    (currentAreas[areaIndex][shelfIndex] as Shelf).addItem(itemName);
    setAreas(currentAreas);
  }

  void moveShelfToArea({
    required int sourceAreaIndex,
    required int shelfIndex,
    required int targetAreaIndex,
  }) {
    if (sourceAreaIndex == targetAreaIndex) {
      return;
    }

    final List<Area> currentAreas = getAreas();
    final shelf = currentAreas[sourceAreaIndex][shelfIndex] as Shelf;
    final Map<Item, String> oldPathsByItem = {};

    shelf.forEach((item) {
      oldPathsByItem[item] = item.path;
    });

    final StorageObject removed = currentAreas[sourceAreaIndex].removeAt(
      shelfIndex,
    );
    currentAreas[targetAreaIndex].insert(
      currentAreas[targetAreaIndex].numItemsAndShelves,
      removed,
    );

    shelf.forEach((item) {
      final String? oldPath = oldPathsByItem[item];
      if (oldPath != null) {
        countModel.moveCountPath(oldPath, item);
      }
    });

    setAreas(currentAreas);
  }

  void moveItemToDestination({
    required List<int> sourceOrder,
    required int targetAreaIndex,
    int? targetShelfIndex,
  }) {
    final List<Area> currentAreas = getAreas();

    final int sourceAreaIndex = sourceOrder[0];
    final int sourceIndex = sourceOrder[1];
    final int? sourceShelfIndex = sourceOrder.elementAtOrNull(2) != null
        ? sourceOrder[1]
        : null;

    final bool sameDestination =
        sourceAreaIndex == targetAreaIndex &&
        sourceShelfIndex == targetShelfIndex;
    if (sameDestination) {
      return;
    }

    final Item item;
    if (sourceOrder.length == 2) {
      item = currentAreas[sourceAreaIndex][sourceIndex] as Item;
    } else {
      final sourceShelf =
          currentAreas[sourceAreaIndex][sourceOrder[1]] as Shelf;
      item = sourceShelf[sourceOrder[2]];
    }

    final String oldPath = item.path;

    if (sourceOrder.length == 2) {
      currentAreas[sourceAreaIndex].removeAt(sourceIndex);
    } else {
      (currentAreas[sourceAreaIndex][sourceOrder[1]] as Shelf).removeAt(
        sourceOrder[2],
      );
    }

    if (targetShelfIndex == null) {
      currentAreas[targetAreaIndex].insert(
        currentAreas[targetAreaIndex].numItemsAndShelves,
        item,
      );
    } else {
      final targetShelf =
          currentAreas[targetAreaIndex][targetShelfIndex] as Shelf;
      targetShelf.insert(targetShelf.numItems, item);
    }

    countModel.moveCountPath(oldPath, item);
    setAreas(currentAreas);
  }

  bool ensurePathExistsForCountEntry(String path, CountEntry entry) {
    final List<String> parts = path
        .split(' > ')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.length < 2 || parts.length > 3) {
      return false;
    }

    final List<Area> currentAreas = getAreas();
    final String areaPath = parts[0];
    final String itemPath = parts.last;

    int areaIndex = currentAreas.indexWhere((area) => area.path == areaPath);
    if (areaIndex == -1) {
      currentAreas.add(Area(areaPath));
      areaIndex = currentAreas.length - 1;
    }

    final ItemCountType countType = entry.countType;
    final CountStrategy strategy;
    if (countType is ItemCount) {
      strategy = countType.strategy;
    } else {
      strategy = SingularCountStrategy();
    }
    final String? countName = itemPath == entry.name ? null : entry.name;

    if (parts.length == 2) {
      if (_hasDirectItemWithPath(currentAreas[areaIndex], path)) {
        return false;
      }

      currentAreas[areaIndex].insert(
        currentAreas[areaIndex].numItemsAndShelves,
        Item(
          itemPath,
          strategy: strategy,
          countName: countName,
          countPhase: entry.phase,
        ),
      );
      setAreas(currentAreas);
      return true;
    }

    final shelfPath = '${parts[0]} > ${parts[1]}';
    int shelfIndex = _findShelfIndexByPath(currentAreas[areaIndex], shelfPath);
    if (shelfIndex == -1) {
      currentAreas[areaIndex].insert(
        currentAreas[areaIndex].numItemsAndShelves,
        Shelf(parts[1]),
      );
      shelfIndex = _findShelfIndexByPath(currentAreas[areaIndex], shelfPath);
      if (shelfIndex == -1) {
        return false;
      }
    }

    final shelf = currentAreas[areaIndex][shelfIndex] as Shelf;
    final bool itemAlreadyExists = [
      for (var i = 0; i < shelf.numItems; i++) shelf[i],
    ].any((item) => item.path == path);
    if (itemAlreadyExists) {
      return false;
    }

    shelf.insert(
      shelf.numItems,
      Item(
        itemPath,
        strategy: strategy,
        countName: countName,
        countPhase: entry.phase,
      ),
    );
    setAreas(currentAreas);
    return true;
  }

  bool _hasDirectItemWithPath(Area area, String path) {
    for (var i = 0; i < area.numItemsAndShelves; i++) {
      final StorageObject child = area[i];
      if (child is Item && child.path == path) {
        return true;
      }
    }

    return false;
  }

  int _findShelfIndexByPath(Area area, String path) {
    for (var i = 0; i < area.numItemsAndShelves; i++) {
      final StorageObject child = area[i];
      if (child is Shelf && child.path == path) {
        return i;
      }
    }

    return -1;
  }

  void removeItem(List<int> selectedOrder) {
    final List<Area> currentAreas = getAreas();

    Item? itemToRemove;

    if (selectedOrder.length == 2) {
      // Item is directly in area
      final int areaIndex = selectedOrder[0];
      final int itemIndex = selectedOrder[1];
      itemToRemove = currentAreas[areaIndex][itemIndex] as Item;
      currentAreas[areaIndex].removeAt(itemIndex);
    } else {
      // Item is in shelf
      final int areaIndex = selectedOrder[0];
      final int shelfIndex = selectedOrder[1];
      final int itemIndex = selectedOrder[2];
      final shelf = currentAreas[areaIndex][shelfIndex] as Shelf;
      itemToRemove = shelf[itemIndex];
      shelf.removeAt(itemIndex);
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
    final shelf = currentAreas[areaIndex][shelfIndex] as Shelf;
    shelf.insert(newIndex, shelf.removeAt(oldIndex));
    setAreas(currentAreas);
  }

  dynamic getShelfOrItem(List<int> selectedOrder) {
    final int areaIndex = selectedOrder[0];
    final int index = selectedOrder[1];
    final int? index2 = selectedOrder.elementAtOrNull(2);

    if (index2 != null) {
      final shelf = getAreas()[areaIndex][index] as Shelf;
      return shelf[index2];
    }
    return getAreas()[areaIndex][index];
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
      item = currentAreas[areaIndex][itemIndex] as Item;
    } else {
      // Item is in shelf
      final int areaIndex = selectedOrder[0];
      final int shelfIndex = selectedOrder[1];
      final int itemIndex = selectedOrder[2];
      final shelf = currentAreas[areaIndex][shelfIndex] as Shelf;
      item = shelf[itemIndex];
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
    };

    return jsonEncode(data);
  }

  void importAreasFromJson(String jsonString) {
    final data = jsonDecode(jsonString) as Json;

    // Import areas
    if (data['profiles'] != null) {
      final Map<Profile, List<Area>> importedProfiles =
          (data['profiles'] as Json).map((profileName, areasData) {
            final profile = Profile(profileName);
            final List<Area> areas = (areasData as List<dynamic>)
                .map((areaData) => Area.fromJson(areaData))
                .toList();
            _reindexAreaDuplicateOrders(areas);
            return MapEntry(profile, areas);
          });
      profiles = importedProfiles;
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
    final data = jsonDecode(jsonString) as Json;

    // Import areas for this specific profile
    List<Area> areas = [];
    if (data['areas'] != null) {
      areas = (data['areas'] as List<dynamic>)
          .map((areaData) => Area.fromJson(areaData))
          .toList();
      _reindexAreaDuplicateOrders(areas);
    }

    final Map<Profile, List<Area>> currentProfiles = profiles;
    currentProfiles[profile] = areas;
    profiles = currentProfiles;

    SchedulerBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  bool hasAnyItems() {
    return getAreas().any((area) => area.hasAnyItems());
  }

  List<String> getPathsForItem(String itemName) => [
    for (final area in getAreas()) ...area.getPathsForItem(itemName),
  ];

  List<Item> findItemsByName(String name, CountPhase phase) {
    final List<String> itemPaths = [];
    final List<Item> items = [];

    if (countModel.selectedProfile == null) return [];

    for (final MapEntry<String, CountEntry> entry
        in countModel.itemCounts.entries) {
      if (entry.value.name == name && entry.value.phase == phase) {
        itemPaths.add(entry.key);
      }
    }

    for (var i = 0; i < numAreas; i++) {
      getArea(i).forEachItem((item) {
        if (itemPaths.contains(item.path)) items.add(item);
      });
    }

    return items;
  }
}

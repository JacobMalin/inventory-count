import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_udid/flutter_udid.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../count_page.dart';
import 'count_model.dart';
import 'data/count_strategy.dart';
import 'data/inventory_models.dart';

class AreaModel with ChangeNotifier {
  AreaModel(this.countModel) {
    if (_areasBox.get('profiles') == null) {
      unawaited(_areasBox.put('profiles', <Profile, List<Area>>{}));
    }
    if (_areasBox.get('itemIdCounter') == null) {
      unawaited(_areasBox.put('itemIdCounter', 0));
    }

    unawaited(() async {
      await _fetch();
      await _listenForChanges();
    }());
  }

  RealtimeChannel? _setupsSubscription;
  StreamSubscription<InternetConnectionStatus>? _connectionSubscription;

  final Box<dynamic> _areasBox = Hive.box('areas');
  CountModel countModel;

  final _notYetDeletedProfiles = <Profile>{};

  Future<void> _fetch() async {
    try {
      final PostgrestList response = await Supabase.instance.client
          .from('profiles')
          .select();

      await _updateFromResponse(response);
    } on Exception catch (e) {
      if (kDebugMode) print('Failed to fetch profiles from Supabase: $e');
    }
  }

  Future<void> _listenForChanges() async {
    try {
      _setupsSubscription = Supabase.instance.client
          .channel('public:profiles')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'profiles',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.neq,
              column: 'udid',
              value: await FlutterUdid.udid,
            ),
            callback: (payload) async {
              await _updateSingleFromResponse(payload);
            },
          )
          .subscribe();
    } on Exception catch (e) {
      if (kDebugMode) print('Failed to subscribe to Supabase changes: $e');
    }

    // Listen for connectivity changes
    try {
      _connectionSubscription = InternetConnectionChecker
          .instance
          .onStatusChange
          .listen((status) async {
            if (status != InternetConnectionStatus.connected) return;

            for (final profile in List<Profile>.from(_notYetDeletedProfiles)) {
              _notYetDeletedProfiles.remove(profile);
              await deleteProfileFromSupabase(profile);
            }
            await _fetch();
          });
    } on Exception catch (e) {
      if (kDebugMode) print('Failed to listen for connectivity changes: $e');
    }
  }

  Future<void> _updateFromResponse(List<Map<String, dynamic>> response) async {
    if (response.isEmpty) return;

    final List<String> remoteProfiles = response
        .map((entry) => entry['name'] as String)
        .toList();

    // Batch jobs to push at end
    final Map<Profile, DateTime> profilesToUpdateRemote = {};

    // Compare timestamps for each profile
    for (final profileName in remoteProfiles) {
      // Get remote data for this profile
      Map<String, dynamic>? remoteEntry;
      DateTime? remoteUpdatedAt;
      String? remoteUdid;
      for (final entry in response) {
        if (entry['name'] == profileName) {
          remoteUdid = entry['udid'];
          remoteEntry = entry;
          remoteUpdatedAt = entry['updated_at'] != null
              ? DateTime.tryParse(entry['updated_at'].toString())
              : null;
          break;
        }
      }

      if (remoteUdid == await FlutterUdid.udid) {
        // Don't update from our own changes
        continue;
      }

      if (remoteUpdatedAt == null) continue; // Should not be possible

      final targetProfile = Profile(profileName);
      final DateTime? localUpdatedAt = _updatedAtMap[targetProfile];

      if (localUpdatedAt == null || localUpdatedAt.isBefore(remoteUpdatedAt)) {
        // Remote is newer, import from remote
        final String jsonData = remoteEntry!['json'] is String
            ? remoteEntry['json'] as String
            : jsonEncode(remoteEntry['json']);
        importProfileFromJson(targetProfile, jsonData);

        final Map<Profile, DateTime?> newUpdatedAtMap = _updatedAtMap;
        newUpdatedAtMap[Profile(profileName)] = remoteUpdatedAt;
        _updatedAtMap = newUpdatedAtMap;
      } else if (localUpdatedAt.isAfter(remoteUpdatedAt)) {
        // Local is newer, queue for remote update
        profilesToUpdateRemote[targetProfile] = localUpdatedAt;
      }
    }

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

  Future<void> _updateSingleFromResponse(PostgresChangePayload payload) async {
    if (payload.eventType == PostgresChangeEvent.delete) {
      final profileName = payload.oldRecord['name'] as String;
      final targetProfile = Profile(profileName);

      final Map<Profile, List<Area>> currentProfiles = profiles
        ..remove(targetProfile);
      profiles = currentProfiles;

      final Map<Profile, DateTime?> newUpdatedAtMap = _updatedAtMap
        ..remove(targetProfile);
      _updatedAtMap = newUpdatedAtMap;

      return;
    }

    final Map<String, dynamic> entry = payload.newRecord;

    final profileName = entry['name'] as String;
    final DateTime? remoteUpdatedAt = entry['updated_at'] != null
        ? DateTime.tryParse(entry['updated_at'].toString())
        : null;
    final String? remoteUdid = entry['udid'];

    if (remoteUdid == await FlutterUdid.udid) {
      // Don't update from our own changes
      return;
    }

    if (remoteUpdatedAt == null) return; // Should not be possible

    final targetProfile = Profile(profileName);
    final DateTime? localUpdatedAt = _updatedAtMap[targetProfile];

    if (localUpdatedAt == null || localUpdatedAt.isBefore(remoteUpdatedAt)) {
      // Remote is newer, import from remote
      final String jsonData = entry['json'] is String
          ? entry['json'] as String
          : jsonEncode(entry['json']);
      importProfileFromJson(targetProfile, jsonData);

      final Map<Profile, DateTime?> newUpdatedAtMap = _updatedAtMap;
      newUpdatedAtMap[Profile(profileName)] = remoteUpdatedAt;
      _updatedAtMap = newUpdatedAtMap;
    }
  }

  Future<void> _batchUpdateSupabase(
    Map<Profile, DateTime> profilesToUpdate,
  ) async {
    if (profilesToUpdate.isEmpty) return;

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
          'udid': await FlutterUdid.udid,
        });
      }

      // Single batch upsert call
      await Supabase.instance.client.from('profiles').upsert(batchData);
    } on Exception catch (e) {
      if (kDebugMode) print('Failed to batch update profiles to Supabase: $e');
    }
  }

  @override
  Future<void> dispose() async {
    await _setupsSubscription?.unsubscribe();
    await _connectionSubscription?.cancel();
    super.dispose();
  }

  void updateSupabase(Profile profile) {
    final String jsonString = exportProfileToJson(profile);

    final DateTime now = DateTime.now().toUtc();
    final Map<Profile, DateTime?> newUpdatedAtMap = _updatedAtMap;
    newUpdatedAtMap[profile] = now;
    _updatedAtMap = newUpdatedAtMap;

    unawaited(() async {
      await Supabase.instance.client
          .from('profiles')
          .upsert({
            'name': profile.name,
            'updated_at': now.toIso8601String(),
            'json': jsonString,
            'udid': await FlutterUdid.udid,
          })
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

    await Supabase.instance.client
        .from('profiles')
        .delete()
        .eq('name', profile.name)
        .onError((error, _) {
          _notYetDeletedProfiles.add(profile);

          if (kDebugMode) {
            print(
              'Failed to delete profile "${profile.name}" from Supabase: '
              '$error',
            );
          }
        });
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

  Map<Profile, DateTime?> _updatedAtMap = {};

  List<Area> getAreas() {
    if (countModel.selectedProfile == null) return [];

    final Map<Profile, List<Area>> currentProfiles = profiles;

    if (currentProfiles.containsKey(countModel.selectedProfile)) {
      return currentProfiles[countModel.selectedProfile]!;
    }

    currentProfiles[countModel.selectedProfile!] = <Area>[];
    _updatedAtMap[countModel.selectedProfile!] = DateTime.now().toUtc();
    profiles = currentProfiles;

    return currentProfiles[countModel.selectedProfile]!;
  }

  void setAreas(List<Area> areas) {
    if (countModel.selectedProfile == null) return;

    final Map<Profile, List<Area>> currentProfiles = profiles;
    currentProfiles[countModel.selectedProfile!] = areas;
    profiles = currentProfiles;

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
    List<Area> areas = [];
    if (data['areas'] != null) {
      areas = (data['areas'] as List<dynamic>)
          .map((areaData) => Area.fromJson(areaData))
          .toList();
    }

    final Map<Profile, List<Area>> currentProfiles = profiles;
    currentProfiles[profile] = areas;
    profiles = currentProfiles;

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

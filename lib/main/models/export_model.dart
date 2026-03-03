import 'dart:async';
import 'dart:convert';

import 'package:intl/intl.dart';

import '../repositories/device_id_repository.dart';
import '../repositories/export_local_repository.dart';
import '../repositories/export_sync_repository.dart';
import 'count_model.dart';
import 'data/export_entry.dart';
import 'sync_change_notifier.dart';
import 'sync_coordinator.dart';

class ExportModel extends SyncChangeNotifier {
  ExportModel({
    required DeviceIdRepository deviceIdRepository,
    required SyncCoordinator syncCoordinator,
    ExportLocalRepository? localRepository,
    ExportSyncRepository? syncRepository,
    super.syncRuntime,
  }) : _localRepository = localRepository ?? HiveExportLocalRepository(),
       _syncRepository = syncRepository ?? SupabaseExportSyncRepository(),
       _deviceIdRepository = deviceIdRepository,
       _syncCoordinator = syncCoordinator {
    unawaited(_localRepository.ensureInitialized());

    // TODO: Figure out why this causes debugging disconnection
    initializeSync(fetchInitial: _fetch, listenForChanges: _listenForChanges);
  }

  final ExportLocalRepository _localRepository;
  final ExportSyncRepository _syncRepository;
  final DeviceIdRepository _deviceIdRepository;
  final SyncCoordinator _syncCoordinator;

  StreamSubscription<ExportSyncRecord?>? _setupsSubscription;
  DateTime? _lastTimestamp;

  Future<void> _fetch() async {
    try {
      final ExportSyncRecord? response = await _syncRepository.fetchLatest();
      await _updateFromResponse(response);
    } on Exception catch (e) {
      logSyncError('Failed to fetch setups from Supabase', e);
    }
  }

  Future<void> _listenForChanges() async {
    try {
      Future<void> reconnect() async {
        await _setupsSubscription?.cancel();
        _setupsSubscription = _syncRepository.watchLatest().listen(
          _updateFromResponse,
          onError: (e) {
            logSyncError('Error listening to Supabase changes', e);
          },
        );
      }

      registerReconnectCallback(reconnect);
    } on Exception catch (e) {
      logSyncError('Failed to register reconnect callback', e);
    }
  }

  Future<void> _updateFromResponse(ExportSyncRecord? response) async {
    await _syncCoordinator.reconcileSingle<ExportSyncRecord>(
      remoteRecord: response,
      remoteUdid: (record) => record.udid,
      remoteUpdatedAt: (record) => record.updatedAt,
      localUpdatedAt: _lastTimestamp,
      onPullRemote: (record, remoteUpdatedAt) async {
        await importFromJson(record.json);
        _lastTimestamp = remoteUpdatedAt;
      },
      onPushLocal: () async {
        _updateSupabase();
      },
    );
  }

  @override
  Future<void> dispose() async {
    await unregisterReconnectCallbacks();
    await _setupsSubscription?.cancel();
    super.dispose();
  }

  void _updateSupabase() {
    final String jsonString = exportToJson();

    final DateTime now = DateTime.now().toUtc();
    final id = '${DateFormat('yyyy-MM-dd HH').format(now)}h';

    _lastTimestamp = now;

    unawaited(() async {
      final String ownUdid = await _deviceIdRepository.getDeviceId();

      await _syncRepository
          .upsertLatest(
            ExportSyncRecord(
              id: id,
              updatedAt: now,
              json: jsonString,
              udid: ownUdid,
            ),
          )
          .catchError((error) {
            logSyncError('Failed to upsert to Supabase', error);
          });
    }());
  }

  List<ExportEntry> get exportList => _localRepository.readExportList();

  Future<void> add(ExportEntry value) async {
    final List<ExportEntry> currentExportList = exportList..add(value);
    await _localRepository.writeExportList(currentExportList);
    _updateSupabase();
    notifyListeners();
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    final List<ExportEntry> currentExportList = exportList;
    final ExportEntry item = currentExportList.removeAt(oldIndex);
    currentExportList.insert(newIndex, item);
    await _localRepository.writeExportList(currentExportList);
    _updateSupabase();
    notifyListeners();
  }

  Future<void> editEntry(
    int index, {
    String? name,
    bool? isHidden,
    bool? isNotCounted,
    String? omniName,
    bool updateOmniName = false,
  }) async {
    final List<ExportEntry> currentExportList = exportList;
    final ExportEntry entry = currentExportList[index];

    if (name != null) entry.name = name;
    if (isHidden != null) entry.isHidden = isHidden;
    if (isNotCounted != null) entry.isNotCounted = isNotCounted;
    if (entry is ExportItem && updateOmniName) {
      entry.omniName = omniName;
    }

    await _localRepository.writeExportList(currentExportList);
    _updateSupabase();
    notifyListeners();
  }

  Future<void> removeAt(int index) async {
    final List<ExportEntry> currentExportList = exportList..removeAt(index);
    await _localRepository.writeExportList(currentExportList);
    _updateSupabase();
    notifyListeners();
  }

  bool contains(String countName) {
    final List<ExportEntry> currentExportList = exportList;

    var titleHidden = false;
    var titleNotCounted = false;
    for (final entry in currentExportList) {
      if (entry is ExportItem &&
          entry.name == countName &&
          !entry.isHidden &&
          !titleHidden &&
          !entry.isNotCounted &&
          !titleNotCounted) {
        return true;
      } else if (entry is ExportTitle) {
        titleHidden = entry.isHidden;
        titleNotCounted = entry.isNotCounted;
      }
    }
    return false;
  }

  String exportInExportOrder(CountModel countModel) {
    final List<ExportEntry> currentExportList = exportList;

    final Map<String, dynamic> data = {};

    var currentTitle = '';
    var titleHidden = false;
    var titleNotCounted = false;
    for (final entry in currentExportList) {
      if (entry is ExportItem && !entry.isHidden && !titleHidden) {
        final bool useNotCountedJson = entry.isNotCounted || titleNotCounted;

        final currentBucket = data[currentTitle] as Map<dynamic, dynamic>;
        currentBucket[entry.name] = useNotCountedJson
            ? countModel.getItemNotCountedJson(entry.omniName)
            : countModel.getItemExportJson(entry.name, entry.omniName);
      } else if (entry is ExportTitle) {
        currentTitle = entry.name;
        titleHidden = entry.isHidden;
        titleNotCounted = entry.isNotCounted;
        if (!data.containsKey(currentTitle)) data[currentTitle] = {};
      }
    }
    return jsonEncode(data);
  }

  Future<void> upsertCountExport(CountModel countModel) async {
    final String jsonString = exportInExportOrder(countModel);

    await _syncRepository.upsertCountExport(
      when: countModel.selectedDate,
      profile: countModel.selectedProfile?.name ?? 'Default',
      json: jsonString,
    );
  }

  String exportToJson() {
    final List<ExportEntry> currentExportList = exportList;

    final Map<String, List<Map<String, dynamic>>> data = {
      'exportList': currentExportList.map((entry) => entry.toJson()).toList(),
    };

    return jsonEncode(data);
  }

  Future<void> importFromJson(String jsonString) async {
    final data = jsonDecode(jsonString) as Map<String, dynamic>;

    // Import export list
    if (data['exportList'] != null) {
      final List<ExportEntry> exportListData = (data['exportList'] as List)
          .map((json) => ExportEntry.fromJson(json as Map<String, dynamic>))
          .toList();

      await _localRepository.writeExportList(exportListData);
    }

    notifyListeners();
  }
}

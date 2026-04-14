import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/types/json.dart';
import '../repositories/device_id.dart';
import '../repositories/export_local_repository.dart';
import '../repositories/export_sync_repository.dart';
import 'data/export_entry.dart';
import 'sync_coordinator.dart';

class ExportModel extends ChangeNotifier {
  ExportModel({bool disableSync = false})
    : _localRepository = HiveExportLocalRepository(),
      _syncRepository = SupabaseExportSyncRepository(disableSync: disableSync) {
    _syncRepository.init(_updateFromResponse);
  }

  final ExportLocalRepository _localRepository;
  final ExportSyncRepository _syncRepository;

  DateTime? _lastTimestamp;

  Future<void> _updateFromResponse(ExportSyncRecord? response) async {
    await SyncCoordinator.reconcileSingle<ExportSyncRecord>(
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
    await _syncRepository.dispose();
    super.dispose();
  }

  void _updateSupabase() {
    final String jsonString = exportToJson();

    final DateTime now = DateTime.now().toUtc();
    final id = '${DateFormat('yyyy-MM-dd HH').format(now)}h';

    _lastTimestamp = now;

    unawaited(() async {
      final String ownUdid = await DeviceId.getDeviceId();

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
            _syncRepository.logSyncError('Failed to upsert to Supabase', error);
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

  String exportToJson() {
    final List<ExportEntry> currentExportList = exportList;

    final Map<String, List<Json>> data = {
      'exportList': currentExportList.map((entry) => entry.toJson()).toList(),
    };

    return jsonEncode(data);
  }

  Future<void> importFromJson(String jsonString) async {
    final data = jsonDecode(jsonString) as Json;

    // Import export list
    if (data['exportList'] != null) {
      final List<ExportEntry> exportListData = (data['exportList'] as List)
          .map((json) => ExportEntry.fromJson(json as Json))
          .toList();

      await _localRepository.writeExportList(exportListData);
    }

    notifyListeners();
  }
}

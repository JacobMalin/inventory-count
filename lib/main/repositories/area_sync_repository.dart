import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/types/json.dart';
import '../models/area_model.dart';
import '../models/data/inventory_models.dart';
import '../models/sync_coordinator.dart';
import 'device_id.dart';
import 'repository.dart';

enum AreaSyncChangeType { insert, update, delete }

typedef FetchProfilesRows = Future<List<Json>> Function();
typedef SubscribeProfileChanges =
    RealtimeChannel Function({
      required String excludedUdid,
      required Future<void> Function(Json newRow) onInsertRow,
      required Future<void> Function(Json newRow) onUpdateRow,
      required Future<void> Function(Json oldRow) onDeleteRow,
    });
typedef UpsertProfilesRows = Future<void> Function(List<Json> rows);
typedef UpsertProfileRow = Future<void> Function(Json row);
typedef DeleteProfileByName = Future<void> Function(String profileName);

class AreaSyncRecord {
  AreaSyncRecord({
    required this.name,
    required this.updatedAt,
    required this.json,
    required this.udid,
  });

  factory AreaSyncRecord.fromJson(Json row) {
    final requiredFields = <String>['name', 'updated_at', 'json', 'udid'];
    if (!requiredFields.every((field) => row.containsKey(field))) {
      throw ArgumentError('Invalid row data: missing required fields');
    }

    final name = row['name'] as String;
    final udid = row['udid'] as String;
    final DateTime updatedAt =
        DateTime.tryParse(row['updated_at'].toString())?.toUtc() ??
        (throw ArgumentError(
          'Invalid row data: updated_at is not a valid DateTime',
        ));

    final String json = row['json'] is String
        ? row['json'] as String
        : jsonEncode(row['json']);

    return AreaSyncRecord(
      name: name,
      updatedAt: updatedAt,
      json: json,
      udid: udid,
    );
  }

  final String name;
  final DateTime updatedAt;
  final String json;
  final String udid;

  Json toJson() {
    return {
      'name': name,
      'updated_at': updatedAt.toIso8601String(),
      'json': json,
      'udid': udid,
    };
  }
}

class AreaSyncChange {
  AreaSyncChange.insert(this.record)
    : type = AreaSyncChangeType.insert,
      deletedName = null;

  AreaSyncChange.update(this.record)
    : type = AreaSyncChangeType.update,
      deletedName = null;

  AreaSyncChange.delete(this.deletedName)
    : type = AreaSyncChangeType.delete,
      record = null;

  final AreaSyncChangeType type;
  final AreaSyncRecord? record;
  final String? deletedName;
}

abstract class AreaSyncRepository extends SyncRepository {
  AreaSyncRepository({super.disableSync = false});

  late AreaModel areaModel;

  Future<List<AreaSyncRecord>> fetchProfiles();
  Future<void> upsertProfile(AreaSyncRecord record);
  Future<void> deleteProfile(String profileName);

  RealtimeChannel subscribeProfileChanges({
    required String excludedUdid,
    required Future<void> Function(AreaSyncChange change) onChange,
  });

  Future<void> batchUpsertProfiles(List<AreaSyncRecord> records);

  void updateSupabase(Profile profile);
  Future<void> deleteProfileFromSupabase(Profile profile);

  Future<void> dispose();
}

class SupabaseAreaSyncRepository extends AreaSyncRepository {
  SupabaseAreaSyncRepository({super.disableSync = false}) {
    initializeSync(fetchInitial: _fetch, listenForChanges: _listenForChanges);
  }

  final SupabaseClient _client = Supabase.instance.client;

  RealtimeChannel? _setupsSubscription;

  Map<Profile, DateTime?> _updatedAtMap = {};
  final _notYetDeletedProfiles = <Profile>{};

  @override
  Future<void> dispose() async {
    await _setupsSubscription?.unsubscribe();
    await unregisterReconnectCallbacks();
  }

  Future<void> _fetch() async {
    try {
      final List<AreaSyncRecord> response = await fetchProfiles();

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
        _setupsSubscription = subscribeProfileChanges(
          excludedUdid: ownUdid,
          onChange: _updateSingleFromResponse,
        );
      }

      await registerReconnectCallback(reconnect);
    } on Exception catch (e) {
      logSyncError('Failed to register reconnect callback', e);
    }
  }

  @override
  Future<List<AreaSyncRecord>> fetchProfiles() async {
    final PostgrestList response = await _client.from('profiles').select();

    return response
        .map((row) => AreaSyncRecord.fromJson(Json.from(row as Map)))
        .toList();
  }

  @override
  Future<void> upsertProfile(AreaSyncRecord record) {
    return _client.from('profiles').upsert(record.toJson());
  }

  @override
  Future<void> deleteProfile(String profileName) {
    return _client.from('profiles').delete().eq('name', profileName);
  }

  @override
  RealtimeChannel subscribeProfileChanges({
    required String excludedUdid,
    required Future<void> Function(AreaSyncChange change) onChange,
  }) {
    Future<void> onInsertRow(Json newRow) async {
      final record = AreaSyncRecord.fromJson(newRow);
      await onChange(AreaSyncChange.insert(record));
    }

    Future<void> onUpdateRow(Json newRow) async {
      final record = AreaSyncRecord.fromJson(newRow);
      await onChange(AreaSyncChange.update(record));
    }

    Future<void> onDeleteRow(Json oldRow) async {
      final deletedName = oldRow['name'] as String?;
      if (deletedName == null) return;

      await onChange(AreaSyncChange.delete(deletedName));
    }

    return _client
        .channel('public:profiles')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'profiles',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.neq,
            column: 'udid',
            value: excludedUdid,
          ),
          callback: (payload) => onInsertRow(payload.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'profiles',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.neq,
            column: 'udid',
            value: excludedUdid,
          ),
          callback: (payload) => onUpdateRow(payload.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'profiles',
          callback: (payload) => onDeleteRow(payload.oldRecord),
        )
        .subscribe();
  }

  @override
  Future<void> batchUpsertProfiles(List<AreaSyncRecord> records) {
    if (records.isEmpty) return Future<void>.value();

    return _client
        .from('profiles')
        .upsert(records.map((record) => record.toJson()).toList());
  }

  Future<void> _updateFromResponse(List<AreaSyncRecord> response) async {
    if (response.isEmpty) return;

    final Map<String, AreaSyncRecord> profilesByName = {
      for (final AreaSyncRecord entry in response) entry.name: entry,
    };

    final List<String> remoteProfiles = profilesByName.keys.toList();

    // Batch jobs to push at end
    final Map<Profile, DateTime> profilesToUpdateRemote = {};

    await SyncCoordinator.reconcileCollection<AreaSyncRecord, Profile>(
      remoteRecords: profilesByName.values,
      keyOf: (record) => Profile(record.name),
      remoteUdid: (record) => record.udid,
      remoteUpdatedAt: (record) => record.updatedAt,
      localUpdatedAtOf: (profile) => _updatedAtMap[profile],
      onPullRemote: (profile, record, remoteUpdatedAt) async {
        areaModel.importProfileFromJson(profile, record.json);

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
      ...areaModel.profiles.keys.map((profile) => profile.name),
    };
    final List<String> profilesToDelete = localProfiles
        .where((localProfile) => !remoteProfiles.contains(localProfile))
        .toList();
    for (final profileName in profilesToDelete) {
      final targetProfile = Profile(profileName);
      final Map<Profile, List<Area>> currentProfiles = areaModel.profiles
        ..remove(targetProfile);
      areaModel.profiles = currentProfiles;

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

      final Map<Profile, List<Area>> currentProfiles = areaModel.profiles
        ..remove(targetProfile);
      areaModel.profiles = currentProfiles;

      final Map<Profile, DateTime?> newUpdatedAtMap = _updatedAtMap
        ..remove(targetProfile);
      _updatedAtMap = newUpdatedAtMap;

      return;
    }

    final AreaSyncRecord? newRecord = payload.record;
    if (newRecord != null) {
      await SyncCoordinator.reconcileSingle<AreaSyncRecord>(
        remoteRecord: newRecord,
        remoteUdid: (record) => record.udid,
        remoteUpdatedAt: (record) => record.updatedAt,
        localUpdatedAt: _updatedAtMap[Profile(newRecord.name)],
        onPullRemote: (record, remoteUpdatedAt) async {
          final targetProfile = Profile(record.name);
          areaModel.importProfileFromJson(targetProfile, record.json);

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
        final String jsonString = areaModel.exportProfileToJson(profile);

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
      await batchUpsertProfiles(batchData);
    } on Exception catch (e) {
      logSyncError('Failed to batch update profiles to Supabase', e);
    }
  }

  @override
  void updateSupabase(Profile profile) {
    final String jsonString = areaModel.exportProfileToJson(profile);

    final DateTime now = DateTime.now().toUtc();
    final Map<Profile, DateTime?> newUpdatedAtMap = _updatedAtMap;
    newUpdatedAtMap[profile] = now;
    _updatedAtMap = newUpdatedAtMap;

    unawaited(() async {
      final String ownUdid = await DeviceId.getDeviceId();

      await upsertProfile(
        AreaSyncRecord(
          name: profile.name,
          updatedAt: now,
          json: jsonString,
          udid: ownUdid,
        ),
      ).onError((error, _) {
        if (kDebugMode) {
          print(
            'Failed to update profile "${profile.name}" to Supabase: '
            '$error',
          );
        }
      });
    }());
  }

  @override
  Future<void> deleteProfileFromSupabase(Profile profile) async {
    final Map<Profile, DateTime?> newUpdatedAtMap = _updatedAtMap
      ..remove(profile);
    _updatedAtMap = newUpdatedAtMap;

    try {
      await deleteProfile(profile.name);
    } on Exception catch (error) {
      _notYetDeletedProfiles.add(profile);

      if (kDebugMode) {
        print(
          'Failed to delete profile "${profile.name}" from Supabase: $error',
        );
      }
    }
  }
}

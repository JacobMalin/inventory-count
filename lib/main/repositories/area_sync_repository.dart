import 'dart:async';
import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/types/json.dart';
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
  Future<List<AreaSyncRecord>> fetchProfiles();
  Future<void> upsertProfile(AreaSyncRecord record);
  Future<void> deleteProfile(String profileName);

  RealtimeChannel subscribeProfileChanges({
    required String excludedUdid,
    required Future<void> Function(AreaSyncChange change) onChange,
  });

  Future<void> batchUpsertProfiles(List<AreaSyncRecord> records);
}

class SupabaseAreaSyncRepository extends AreaSyncRepository {
  SupabaseAreaSyncRepository({
    SupabaseClient? client,
    super.disableSync = false,
  })
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

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
}

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum AreaSyncChangeType { insert, update, delete }

typedef FetchProfilesRows = Future<List<Map<String, dynamic>>> Function();
typedef SubscribeProfileChanges =
    RealtimeChannel Function({
      required String excludedUdid,
      required Future<void> Function(Map<String, dynamic> newRow) onInsertRow,
      required Future<void> Function(Map<String, dynamic> newRow) onUpdateRow,
      required Future<void> Function(Map<String, dynamic> oldRow) onDeleteRow,
    });
typedef UpsertProfilesRows =
    Future<void> Function(List<Map<String, dynamic>> rows);
typedef UpsertProfileRow = Future<void> Function(Map<String, dynamic> row);
typedef DeleteProfileByName = Future<void> Function(String profileName);

class AreaSyncRecord {
  AreaSyncRecord({
    required this.name,
    required this.updatedAt,
    required this.json,
    required this.udid,
  });

  final String name;
  final DateTime updatedAt;
  final String json;
  final String udid;
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

abstract class AreaSyncRepository {
  Future<List<AreaSyncRecord>> fetchProfiles();

  RealtimeChannel subscribeProfileChanges({
    required String excludedUdid,
    required Future<void> Function(AreaSyncChange change) onChange,
  });

  Future<void> batchUpsertProfiles(List<AreaSyncRecord> records);

  Future<void> upsertProfile(AreaSyncRecord record);

  Future<void> deleteProfile(String profileName);
}

class SupabaseAreaSyncRepository implements AreaSyncRepository {
  SupabaseAreaSyncRepository({
    SupabaseClient? client,
    FetchProfilesRows? fetchProfilesRows,
    SubscribeProfileChanges? subscribeProfileChanges,
    UpsertProfilesRows? upsertProfilesRows,
    UpsertProfileRow? upsertProfileRow,
    DeleteProfileByName? deleteProfileByName,
  }) : _client = client ?? Supabase.instance.client,
       _fetchProfilesRows = fetchProfilesRows,
       _subscribeProfileChanges = subscribeProfileChanges,
       _upsertProfilesRows = upsertProfilesRows,
       _upsertProfileRow = upsertProfileRow,
       _deleteProfileByName = deleteProfileByName;

  final SupabaseClient _client;
  final FetchProfilesRows? _fetchProfilesRows;
  final SubscribeProfileChanges? _subscribeProfileChanges;
  final UpsertProfilesRows? _upsertProfilesRows;
  final UpsertProfileRow? _upsertProfileRow;
  final DeleteProfileByName? _deleteProfileByName;

  @override
  Future<List<AreaSyncRecord>> fetchProfiles() async {
    final List<Map<String, dynamic>> response =
        await (_fetchProfilesRows ?? _defaultFetchProfilesRows)();

    return response.map(_parseRecord).nonNulls.toList();
  }

  @override
  RealtimeChannel subscribeProfileChanges({
    required String excludedUdid,
    required Future<void> Function(AreaSyncChange change) onChange,
  }) {
    return (_subscribeProfileChanges ?? _defaultSubscribeProfileChanges)(
      excludedUdid: excludedUdid,
      onInsertRow: (row) async {
        final AreaSyncRecord? record = _parseRecord(row);
        if (record == null) return;

        await onChange(AreaSyncChange.insert(record));
      },
      onUpdateRow: (row) async {
        final AreaSyncRecord? record = _parseRecord(row);
        if (record == null) return;

        await onChange(AreaSyncChange.update(record));
      },
      onDeleteRow: (row) async {
        final deletedName = row['name'] as String?;
        if (deletedName == null) return;

        await onChange(AreaSyncChange.delete(deletedName));
      },
    );
  }

  @override
  Future<void> batchUpsertProfiles(List<AreaSyncRecord> records) {
    if (records.isEmpty) {
      return Future<void>.value();
    }

    return (_upsertProfilesRows ?? _defaultUpsertProfilesRows)(
      records.map(_toPayload).toList(),
    );
  }

  @override
  Future<void> upsertProfile(AreaSyncRecord record) {
    return (_upsertProfileRow ?? _defaultUpsertProfileRow)(_toPayload(record));
  }

  @override
  Future<void> deleteProfile(String profileName) {
    return (_deleteProfileByName ?? _defaultDeleteProfileByName)(profileName);
  }

  Future<List<Map<String, dynamic>>> _defaultFetchProfilesRows() async {
    final PostgrestList response = await _client.from('profiles').select();
    return response
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  RealtimeChannel _defaultSubscribeProfileChanges({
    required String excludedUdid,
    required Future<void> Function(Map<String, dynamic> newRow) onInsertRow,
    required Future<void> Function(Map<String, dynamic> newRow) onUpdateRow,
    required Future<void> Function(Map<String, dynamic> oldRow) onDeleteRow,
  }) {
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

  Future<void> _defaultUpsertProfilesRows(List<Map<String, dynamic>> rows) {
    return _client.from('profiles').upsert(rows);
  }

  Future<void> _defaultUpsertProfileRow(Map<String, dynamic> row) {
    return _client.from('profiles').upsert(row);
  }

  Future<void> _defaultDeleteProfileByName(String profileName) {
    return _client.from('profiles').delete().eq('name', profileName);
  }

  @visibleForTesting
  AreaSyncRecord? parseRecordForTest(Map<String, dynamic> row) {
    return _parseRecord(row);
  }

  @visibleForTesting
  Map<String, dynamic> toPayloadForTest(AreaSyncRecord record) {
    return _toPayload(record);
  }

  Map<String, dynamic> _toPayload(AreaSyncRecord record) {
    return {
      'name': record.name,
      'updated_at': record.updatedAt.toIso8601String(),
      'json': record.json,
      'udid': record.udid,
    };
  }

  AreaSyncRecord? _parseRecord(Map<String, dynamic> row) {
    final name = row['name'] as String?;
    final udid = row['udid'] as String?;
    final DateTime? updatedAt = row['updated_at'] != null
        ? DateTime.tryParse(row['updated_at'].toString())
        : null;

    if (name == null || udid == null || updatedAt == null) {
      return null;
    }

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
}

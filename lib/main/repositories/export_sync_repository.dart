import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/types/json.dart';

class ExportSyncRecord {
  ExportSyncRecord({
    required this.id,
    required this.updatedAt,
    required this.json,
    required this.udid,
  });

  final String id;
  final DateTime updatedAt;
  final String json;
  final String udid;
}

typedef FetchLatestRows = Future<List<Json>> Function();
typedef WatchLatestRows = Stream<List<Json>> Function();
typedef UpsertRow = Future<void> Function(Json row);

abstract class ExportSyncRepository {
  Future<ExportSyncRecord?> fetchLatest();

  Stream<ExportSyncRecord?> watchLatest();

  Future<void> upsertLatest(ExportSyncRecord record);

  Future<void> upsertCountExport({
    required DateTime when,
    required String profile,
    required String json,
  });
}

class SupabaseExportSyncRepository implements ExportSyncRepository {
  SupabaseExportSyncRepository({
    SupabaseClient? client,
    FetchLatestRows? fetchLatestRows,
    WatchLatestRows? watchLatestRows,
    UpsertRow? upsertLatestRow,
    UpsertRow? upsertCountRow,
  }) : _client = client ?? Supabase.instance.client,
       _fetchLatestRows = fetchLatestRows,
       _watchLatestRows = watchLatestRows,
       _upsertLatestRow = upsertLatestRow,
       _upsertCountRow = upsertCountRow;

  final SupabaseClient _client;
  final FetchLatestRows? _fetchLatestRows;
  final WatchLatestRows? _watchLatestRows;
  final UpsertRow? _upsertLatestRow;
  final UpsertRow? _upsertCountRow;

  @override
  Future<ExportSyncRecord?> fetchLatest() async {
    final List<Json> response =
        await (_fetchLatestRows ?? _defaultFetchLatestRows)();

    if (response.isEmpty) {
      return null;
    }

    return _parseRecord(response.first);
  }

  @override
  Stream<ExportSyncRecord?> watchLatest() {
    return (_watchLatestRows ?? _defaultWatchLatestRows)().map((rows) {
      if (rows.isEmpty) {
        return null;
      }

      return _parseRecord(rows.first);
    });
  }

  @override
  Future<void> upsertLatest(ExportSyncRecord record) {
    return (_upsertLatestRow ?? _defaultUpsertLatestRow)(_toPayload(record));
  }

  @override
  Future<void> upsertCountExport({
    required DateTime when,
    required String profile,
    required String json,
  }) {
    final String exportName = DateFormat('yyyy-MM-dd').format(when);

    return (_upsertCountRow ?? _defaultUpsertCountRow)(<String, dynamic>{
      'name': exportName,
      'profile': profile,
      'json': json,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<List<Json>> _defaultFetchLatestRows() async {
    final PostgrestList response = await _client
        .from('setups')
        .select()
        .order('updated_at')
        .limit(1);
    return response.map((row) => Json.from(row as Map)).toList();
  }

  Stream<List<Json>> _defaultWatchLatestRows() {
    return _client
        .from('setups')
        .stream(primaryKey: ['updated_at'])
        .order('updated_at')
        .limit(1)
        .map((rows) => rows.map((row) => Json.from(row as Map)).toList());
  }

  Future<void> _defaultUpsertLatestRow(Json row) {
    return _client.from('setups').upsert(row);
  }

  Future<void> _defaultUpsertCountRow(Json row) {
    return _client.from('counts').upsert(row);
  }

  @visibleForTesting
  ExportSyncRecord? parseRecordForTest(Json row) {
    return _parseRecord(row);
  }

  @visibleForTesting
  Json toPayloadForTest(ExportSyncRecord record) {
    return _toPayload(record);
  }

  Json _toPayload(ExportSyncRecord record) {
    return {
      'id': record.id,
      'updated_at': record.updatedAt.toIso8601String(),
      'json': record.json,
      'udid': record.udid,
    };
  }

  ExportSyncRecord? _parseRecord(Json row) {
    final DateTime? updatedAt = row['updated_at'] != null
        ? DateTime.tryParse(row['updated_at'].toString())?.toUtc()
        : null;
    if (updatedAt == null) {
      return null;
    }

    final String json = row['json'] is String
        ? row['json'] as String
        : jsonEncode(row['json']);

    return ExportSyncRecord(
      id: row['id'] as String,
      updatedAt: updatedAt,
      json: json,
      udid: row['udid'] as String,
    );
  }
}

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

typedef FetchLatestRows = Future<List<Map<String, dynamic>>> Function();
typedef WatchLatestRows = Stream<List<Map<String, dynamic>>> Function();
typedef UpsertLatestRow = Future<void> Function(Map<String, dynamic> row);

abstract class ExportSyncRepository {
  Future<ExportSyncRecord?> fetchLatest();

  Stream<ExportSyncRecord?> watchLatest();

  Future<void> upsertLatest(ExportSyncRecord record);
}

class SupabaseExportSyncRepository implements ExportSyncRepository {
  SupabaseExportSyncRepository({
    SupabaseClient? client,
    FetchLatestRows? fetchLatestRows,
    WatchLatestRows? watchLatestRows,
    UpsertLatestRow? upsertLatestRow,
  }) : _client = client ?? Supabase.instance.client,
       _fetchLatestRows = fetchLatestRows,
       _watchLatestRows = watchLatestRows,
       _upsertLatestRow = upsertLatestRow;

  final SupabaseClient _client;
  final FetchLatestRows? _fetchLatestRows;
  final WatchLatestRows? _watchLatestRows;
  final UpsertLatestRow? _upsertLatestRow;

  @override
  Future<ExportSyncRecord?> fetchLatest() async {
    final List<Map<String, dynamic>> response =
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

  Future<List<Map<String, dynamic>>> _defaultFetchLatestRows() async {
    final PostgrestList response = await _client
        .from('setups')
        .select()
        .order('updated_at')
        .limit(1);
    return response
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Stream<List<Map<String, dynamic>>> _defaultWatchLatestRows() {
    return _client
        .from('setups')
        .stream(primaryKey: ['updated_at'])
        .order('updated_at')
        .limit(1)
        .map(
          (rows) =>
              rows.map((row) => Map<String, dynamic>.from(row as Map)).toList(),
        );
  }

  Future<void> _defaultUpsertLatestRow(Map<String, dynamic> row) {
    return _client.from('setups').upsert(row);
  }

  @visibleForTesting
  ExportSyncRecord? parseRecordForTest(Map<String, dynamic> row) {
    return _parseRecord(row);
  }

  @visibleForTesting
  Map<String, dynamic> toPayloadForTest(ExportSyncRecord record) {
    return _toPayload(record);
  }

  Map<String, dynamic> _toPayload(ExportSyncRecord record) {
    return {
      'id': record.id,
      'updated_at': record.updatedAt.toIso8601String(),
      'json': record.json,
      'udid': record.udid,
    };
  }

  ExportSyncRecord? _parseRecord(Map<String, dynamic> row) {
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

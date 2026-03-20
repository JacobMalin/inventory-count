import 'dart:async';
import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/types/json.dart';
import 'repository.dart';

class ExportSyncRecord {
  ExportSyncRecord({
    required this.id,
    required this.updatedAt,
    required this.json,
    required this.udid,
  });

  factory ExportSyncRecord.fromJson(Json row) {
    final requiredFields = <String>['id', 'updated_at', 'json', 'udid'];
    if (!requiredFields.every((field) => row.containsKey(field))) {
      throw ArgumentError('Invalid row data: missing required fields');
    }

    final id = row['id'] as String;
    final udid = row['udid'] as String;
    final DateTime updatedAt =
        DateTime.tryParse(row['updated_at'].toString())?.toUtc() ??
        (throw ArgumentError(
          'Invalid row data: updated_at is not a valid DateTime',
        ));

    final String json = row['json'] is String
        ? row['json'] as String
        : jsonEncode(row['json']);

    return ExportSyncRecord(
      id: id,
      updatedAt: updatedAt,
      json: json,
      udid: udid,
    );
  }

  final String id;
  final DateTime updatedAt;
  final String json;
  final String udid;

  Json toJson() {
    return {
      'id': id,
      'updated_at': updatedAt.toIso8601String(),
      'json': json,
      'udid': udid,
    };
  }
}

typedef FetchLatestRows = Future<List<Json>> Function();
typedef WatchLatestRows = Stream<List<Json>> Function();
typedef UpsertRow = Future<void> Function(Json row);

abstract class ExportSyncRepository extends SyncRepository {
  Future<ExportSyncRecord?> fetchLatest();
  Future<void> upsertLatest(ExportSyncRecord record);

  Stream<ExportSyncRecord?> watchLatest();
}

class SupabaseExportSyncRepository implements ExportSyncRepository {
  SupabaseExportSyncRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<ExportSyncRecord?> fetchLatest() async {
    final PostgrestList response = await _client
        .from('setups')
        .select()
        .order('updated_at')
        .limit(1);

    if (response.isEmpty) return null;
    return ExportSyncRecord.fromJson(response.first);
  }

  @override
  Future<void> upsertLatest(ExportSyncRecord record) {
    return _client.from('setups').upsert(record.toJson());
  }

  @override
  Stream<ExportSyncRecord?> watchLatest() {
    return _client
        .from('setups')
        .stream(primaryKey: ['updated_at'])
        .order('updated_at')
        .limit(1)
        .map((rows) {
          if (rows.isEmpty) return null;
          return ExportSyncRecord.fromJson(rows.first);
        });
  }
}

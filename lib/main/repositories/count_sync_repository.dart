import 'dart:convert';

import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/types/json.dart';

class CountSyncRecord {
  CountSyncRecord({
    required this.name,
    required this.profile,
    required this.updatedAt,
    required this.json,
    required this.expected,
    required this.actual,
  });

  final String name;
  final String profile;
  final DateTime updatedAt;
  final String json;
  final String? expected;
  final String actual;
}

typedef UpsertCountRow = Future<void> Function(Json row);
typedef FetchCountRows = Future<List<Json>> Function(String rowName);
typedef WatchCountRows = Stream<List<Json>> Function(String rowName);

abstract class CountSyncRepository {
  Future<CountSyncRecord?> fetchRow({required String rowName});

  Stream<CountSyncRecord?> watchRow({required String rowName});

  Future<void> upsertCount({
    required DateTime when,
    required String profile,
    required String json,
    required String actual,
  });
}

class NoopCountSyncRepository implements CountSyncRepository {
  @override
  Future<CountSyncRecord?> fetchRow({required String rowName}) {
    return Future<CountSyncRecord?>.value();
  }

  @override
  Stream<CountSyncRecord?> watchRow({required String rowName}) {
    return const Stream<CountSyncRecord?>.empty();
  }

  @override
  Future<void> upsertCount({
    required DateTime when,
    required String profile,
    required String json,
    required String actual,
  }) {
    return Future<void>.value();
  }
}

class SupabaseCountSyncRepository implements CountSyncRepository {
  SupabaseCountSyncRepository({
    SupabaseClient? client,
    UpsertCountRow? upsertCountRow,
    FetchCountRows? fetchCountRows,
    WatchCountRows? watchCountRows,
  }) : _client = client ?? Supabase.instance.client,
       _upsertCountRow = upsertCountRow,
       _fetchCountRows = fetchCountRows,
       _watchCountRows = watchCountRows;

  final SupabaseClient _client;
  final UpsertCountRow? _upsertCountRow;
  final FetchCountRows? _fetchCountRows;
  final WatchCountRows? _watchCountRows;

  @override
  Future<CountSyncRecord?> fetchRow({required String rowName}) async {
    final List<Json> rows = await (_fetchCountRows ?? _defaultFetchCountRows)(
      rowName,
    );
    final Iterable<CountSyncRecord> parsed = rows.map(_parseRecord).nonNulls;
    return parsed.firstOrNull;
  }

  @override
  Stream<CountSyncRecord?> watchRow({required String rowName}) {
    return (_watchCountRows ?? _defaultWatchCountRows)(rowName).map((rows) {
      final Iterable<CountSyncRecord> parsed = rows.map(_parseRecord).nonNulls;
      return parsed.firstOrNull;
    });
  }

  @override
  Future<void> upsertCount({
    required DateTime when,
    required String profile,
    required String json,
    required String actual,
  }) {
    final String exportName = DateFormat('yyyy-MM-dd').format(when);

    return (_upsertCountRow ?? _defaultUpsertCountRow)(<String, dynamic>{
      'name': exportName,
      'profile': profile,
      'json': json,
      'actual': actual,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> _defaultUpsertCountRow(Json row) {
    return _client.from('counts').upsert(row);
  }

  Future<List<Json>> _defaultFetchCountRows(String rowName) async {
    final PostgrestList response = await _client
        .from('counts')
        .select()
        .eq('name', rowName)
        .order('updated_at')
        .limit(1);

    return response.map((row) => Json.from(row as Map)).toList();
  }

  Stream<List<Json>> _defaultWatchCountRows(String rowName) {
    return _client
        .from('counts')
        .stream(primaryKey: ['name'])
        .eq('name', rowName)
        .order('updated_at')
        .limit(1)
        .map((rows) => rows.map((row) => Json.from(row as Map)).toList());
  }

  CountSyncRecord? _parseRecord(Json row) {
    final name = row['name'] as String?;
    final profile = row['profile'] as String?;
    final DateTime? updatedAt = row['updated_at'] != null
        ? DateTime.tryParse(row['updated_at'].toString())?.toUtc()
        : null;
    if (name == null || profile == null || updatedAt == null) {
      return null;
    }

    final String json = row['json'] is String
        ? row['json'] as String
        : jsonEncode(row['json']);
    final String? expected = row['expected'] == null
        ? null
        : row['expected'] is String
        ? row['expected'] as String
        : jsonEncode(row['expected']);
    final String actual = row['actual'] is String
        ? row['actual'] as String
        : row['actual'] == null
        ? json
        : jsonEncode(row['actual']);

    return CountSyncRecord(
      name: name,
      profile: profile,
      updatedAt: updatedAt,
      json: json,
      expected: expected,
      actual: actual,
    );
  }
}

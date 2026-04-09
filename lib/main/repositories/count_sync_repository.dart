import 'dart:async';
import 'dart:convert';

import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/types/json.dart';
import 'repository.dart';

class CountSyncRecord {
  CountSyncRecord({
    required this.name,
    required this.profile,
    required this.updatedAt,
    required this.json,
    required this.actual,
    this.expected,
  });

  factory CountSyncRecord.fromJson(Json row) {
    final requiredFields = <String>[
      'name',
      'profile',
      'updated_at',
      'json',
      'actual',
    ];
    if (!requiredFields.every((field) => row.containsKey(field))) {
      throw ArgumentError('Invalid row data: missing required fields');
    }

    final name = row['name'] as String;
    final profile = row['profile'] as String;
    final DateTime updatedAt =
        DateTime.tryParse(row['updated_at'].toString())?.toUtc() ??
        (throw ArgumentError(
          'Invalid row data: updated_at is not a valid DateTime',
        ));

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

  final String name;
  final String profile;
  final DateTime updatedAt;
  final String json;
  final String? expected;
  final String actual;

  Json toJson() {
    return {
      'name': name,
      'profile': profile,
      'updated_at': updatedAt.toIso8601String(),
      'json': json,
      if (expected != null) 'expected': expected,
      'actual': actual,
    };
  }
}

typedef UpsertCountRow = Future<void> Function(Json row);
typedef FetchCountRows = Future<List<Json>> Function(String rowName);
typedef WatchCountRows = Stream<List<Json>> Function(String rowName);

abstract class CountSyncRepository extends SyncRepository {
  CountSyncRepository({super.disableSync = false});

  String rowName(DateTime selectedDate);

  Future<void> reconnect(DateTime selectedDate);

  Future<CountSyncRecord?> fetchRow({required String rowName});
  Future<void> upsertCount(CountSyncRecord record);

  Stream<CountSyncRecord?> watchRow({required String rowName});
}

class SupabaseCountSyncRepository extends CountSyncRepository {
  SupabaseCountSyncRepository({
    required DateTime selectedDate,
    required Future<void> Function(CountSyncRecord?) updateFromResponse,
    super.disableSync = false,
  }) : _updateFromResponse = updateFromResponse {
    initializeSync(
      fetchInitial: () => _fetch(selectedDate),
      listenForChanges: () => _listenForChanges(selectedDate),
    );
  }

  final SupabaseClient _client = Supabase.instance.client;
  final Future<void> Function(CountSyncRecord?) _updateFromResponse;

  StreamSubscription<CountSyncRecord?>? _countSubscription;
  DateTime? _lastTimestamp;

  @override
  String rowName(DateTime selectedDate) =>
      DateFormat('yyyy-MM-dd').format(selectedDate);

  @override
  Future<CountSyncRecord?> fetchRow({required String rowName}) async {
    final PostgrestList response = await _client
        .from('counts')
        .select()
        .eq('name', rowName)
        .order('updated_at')
        .limit(1);

    if (response.isEmpty) return null;
    return CountSyncRecord.fromJson(response.first);
  }

  @override
  Future<void> upsertCount(CountSyncRecord record) {
    return _client.from('counts').upsert(record.toJson());
  }

  @override
  Stream<CountSyncRecord?> watchRow({required String rowName}) {
    return _client
        .from('counts')
        .stream(primaryKey: ['name'])
        .eq('name', rowName)
        .order('updated_at')
        .limit(1)
        .map((rows) {
          if (rows.isEmpty) return null;
          return CountSyncRecord.fromJson(rows.first);
        });
  }

  Future<void> _fetch(DateTime selectedDate) async {
    try {
      final CountSyncRecord? response = await fetchRow(
        rowName: rowName(selectedDate),
      );
      await _updateFromResponse(response);
    } on Exception catch (e) {
      logSyncError('Failed to fetch counts from Supabase', e);
    }
  }

  Future<void> _listenForChanges(DateTime selectedDate) async {
    try {
      registerReconnectCallback(() => reconnect(selectedDate));
      await reconnect(selectedDate);
    } on Exception catch (e) {
      logSyncError('Failed to register count reconnect callback', e);
    }
  }

  @override
  Future<void> reconnect(DateTime selectedDate) async {
    await _countSubscription?.cancel();

    _countSubscription = watchRow(rowName: rowName(selectedDate)).listen(
      (row) {
        unawaited(_updateFromResponse(row));
      },
      onError: (Object e) {
        logSyncError('Error listening to count changes', e);
      },
    );
  }
}

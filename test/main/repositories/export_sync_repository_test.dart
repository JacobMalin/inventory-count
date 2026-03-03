import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_count/main/repositories/export_sync_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _latestId = 'latest';
const _deviceA = 'device-a';
const _defaultProfile = 'Default';
const _itemsJson = '{"items":[]}';
const _emptyJson = '{}';

SupabaseClient _client() => SupabaseClient('https://example.com', 'anon-key');

void main() {
  group('ExportSyncRecord', () {
    test('stores constructor values', () {
      final updatedAt = DateTime.utc(2026, 2, 19, 12);
      final record = ExportSyncRecord(
        id: _latestId,
        updatedAt: updatedAt,
        json: _itemsJson,
        udid: _deviceA,
      );

      expect(record.id, _latestId);
      expect(record.updatedAt, updatedAt);
      expect(record.json, _itemsJson);
      expect(record.udid, _deviceA);
    });
  });

  group('SupabaseExportSyncRepository', () {
    test('fetchLatest returns null for empty rows', () async {
      final SupabaseClient client = _client();
      final repository = SupabaseExportSyncRepository(
        client: client,
        fetchLatestRows: () async => <Map<String, dynamic>>[],
      );

      final ExportSyncRecord? result = await repository.fetchLatest();

      expect(result, isNull);
    });

    test('fetchLatest returns parsed first row', () async {
      final SupabaseClient client = _client();
      final repository = SupabaseExportSyncRepository(
        client: client,
        fetchLatestRows: () async => <Map<String, dynamic>>[
          <String, dynamic>{
            'id': _latestId,
            'updated_at': DateTime.utc(2026, 2, 19).toIso8601String(),
            'json': _itemsJson,
            'udid': _deviceA,
          },
        ],
      );

      final ExportSyncRecord? result = await repository.fetchLatest();

      expect(result, isNotNull);
      expect(result!.id, _latestId);
    });

    test(
      'watchLatest maps rows to records and null for empty/invalid rows',
      () async {
        final SupabaseClient client = _client();
        final controller = StreamController<List<Map<String, dynamic>>>();
        final repository = SupabaseExportSyncRepository(
          client: client,
          watchLatestRows: () => controller.stream,
        );

        final events = <ExportSyncRecord?>[];
        final StreamSubscription<ExportSyncRecord?> subscription = repository
            .watchLatest()
            .listen(events.add);

        controller
          ..add(<Map<String, dynamic>>[])
          ..add(<Map<String, dynamic>>[
            <String, dynamic>{
              'id': _latestId,
              'updated_at': DateTime.utc(2026, 2, 19).toIso8601String(),
              'json': _itemsJson,
              'udid': _deviceA,
            },
          ])
          ..add(<Map<String, dynamic>>[
            <String, dynamic>{
              'id': _latestId,
              'updated_at': 'invalid-date',
              'json': _emptyJson,
              'udid': _deviceA,
            },
          ]);
        await Future<void>.delayed(Duration.zero);

        expect(events.length, 3);
        expect(events[0], isNull);
        expect(events[1], isNotNull);
        expect(events[2], isNull);

        await subscription.cancel();
        await controller.close();
      },
    );

    test('upsertLatest calls upsertLatestRow with mapped record', () async {
      final SupabaseClient client = _client();
      Map<String, dynamic>? capturedRow;
      final repository = SupabaseExportSyncRepository(
        client: client,
        upsertLatestRow: (row) async {
          capturedRow = row;
        },
      );

      await repository.upsertLatest(
        ExportSyncRecord(
          id: _latestId,
          updatedAt: DateTime.utc(2026, 2, 19, 12),
          json: _itemsJson,
          udid: _deviceA,
        ),
      );

      expect(capturedRow, isNotNull);
      expect(capturedRow!['id'], _latestId);
      expect(capturedRow!['udid'], _deviceA);
    });

    test(
      'upsertCountExport calls upsertCountRow with mapped payload',
      () async {
        final SupabaseClient client = _client();
        Map<String, dynamic>? capturedRow;
        final repository = SupabaseExportSyncRepository(
          client: client,
          upsertCountRow: (row) async {
            capturedRow = row;
          },
        );

        final when = DateTime.utc(2026, 3, 1, 14, 30);
        await repository.upsertCountExport(
          when: when,
          profile: _defaultProfile,
          json: _itemsJson,
        );

        expect(capturedRow, isNotNull);
        expect(capturedRow!['name'], '2026-03-01');
        expect(capturedRow!['profile'], _defaultProfile);
        expect(capturedRow!['json'], _itemsJson);
        expect(capturedRow!['updated_at'], when.toUtc().toIso8601String());
      },
    );

    test(
      'parseRecordForTest parses valid row and converts updatedAt to UTC',
      () {
        final SupabaseClient client = _client();
        final repository = SupabaseExportSyncRepository(client: client);

        final ExportSyncRecord? record = repository
            .parseRecordForTest(<String, dynamic>{
              'id': _latestId,
              'updated_at': '2026-02-19T12:00:00-05:00',
              'json': _itemsJson,
              'udid': _deviceA,
            });

        expect(record, isNotNull);
        expect(record!.id, _latestId);
        expect(record.updatedAt.isUtc, isTrue);
        expect(record.json, _itemsJson);
        expect(record.udid, _deviceA);
      },
    );

    test('parseRecordForTest encodes map json values', () {
      final SupabaseClient client = _client();
      final repository = SupabaseExportSyncRepository(client: client);

      final ExportSyncRecord? record = repository.parseRecordForTest(
        <String, dynamic>{
          'id': _latestId,
          'updated_at': DateTime.utc(2026, 2, 19).toIso8601String(),
          'json': <String, dynamic>{'items': <dynamic>[]},
          'udid': _deviceA,
        },
      );

      expect(record, isNotNull);
      expect(record!.json, _itemsJson);
    });

    test(
      'parseRecordForTest returns null when updatedAt is missing or invalid',
      () {
        final SupabaseClient client = _client();
        final repository = SupabaseExportSyncRepository(client: client);

        expect(
          repository.parseRecordForTest(<String, dynamic>{
            'id': _latestId,
            'json': _emptyJson,
            'udid': _deviceA,
          }),
          isNull,
        );

        expect(
          repository.parseRecordForTest(<String, dynamic>{
            'id': _latestId,
            'updated_at': 'invalid-date',
            'json': _emptyJson,
            'udid': _deviceA,
          }),
          isNull,
        );
      },
    );

    test('toPayloadForTest maps record to upsert payload', () {
      final SupabaseClient client = _client();
      final repository = SupabaseExportSyncRepository(client: client);
      final updatedAt = DateTime.utc(2026, 2, 19, 12);
      final record = ExportSyncRecord(
        id: _latestId,
        updatedAt: updatedAt,
        json: _itemsJson,
        udid: _deviceA,
      );

      final Map<String, dynamic> payload = repository.toPayloadForTest(record);

      expect(payload['id'], _latestId);
      expect(payload['updated_at'], updatedAt.toIso8601String());
      expect(payload['json'], _itemsJson);
      expect(payload['udid'], _deviceA);
    });
  });
}

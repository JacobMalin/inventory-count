import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_count/core/types/json.dart';
import 'package:inventory_count/main/repositories/area_sync_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeRealtimeChannel extends Fake implements RealtimeChannel {}

const _profileName = 'ER';
const _localUdid = 'local-udid';
const _deviceA = 'device-a';
const _emptyJson = '{}';
const _profileJson = '{"name":"ER"}';
const _okJson = '{"ok":true}';
const _fooJson = '{"foo":1}';

SupabaseClient _client() => SupabaseClient('https://example.com', 'anon-key');

void main() {
  group('AreaSyncRecord', () {
    test('stores constructor values', () {
      final updatedAt = DateTime.utc(2026, 2, 19);
      final record = AreaSyncRecord(
        name: _profileName,
        updatedAt: updatedAt,
        json: _profileJson,
        udid: _deviceA,
      );

      expect(record.name, _profileName);
      expect(record.updatedAt, updatedAt);
      expect(record.json, _profileJson);
      expect(record.udid, _deviceA);
    });
  });

  group('AreaSyncChange', () {
    test('insert creates insert change with record', () {
      final record = AreaSyncRecord(
        name: _profileName,
        updatedAt: DateTime.utc(2026, 2, 19),
        json: _emptyJson,
        udid: _deviceA,
      );

      final change = AreaSyncChange.insert(record);

      expect(change.type, AreaSyncChangeType.insert);
      expect(change.record, same(record));
      expect(change.deletedName, isNull);
    });

    test('update creates update change with record', () {
      final record = AreaSyncRecord(
        name: _profileName,
        updatedAt: DateTime.utc(2026, 2, 19),
        json: _emptyJson,
        udid: _deviceA,
      );

      final change = AreaSyncChange.update(record);

      expect(change.type, AreaSyncChangeType.update);
      expect(change.record, same(record));
      expect(change.deletedName, isNull);
    });

    test('delete creates delete change with deleted name', () {
      final change = AreaSyncChange.delete(_profileName);

      expect(change.type, AreaSyncChangeType.delete);
      expect(change.record, isNull);
      expect(change.deletedName, _profileName);
    });
  });

  group('SupabaseAreaSyncRepository', () {
    test('fetchProfiles maps valid rows and filters invalid rows', () async {
      final SupabaseClient client = _client();
      final repository = SupabaseAreaSyncRepository(
        client: client,
        fetchProfilesRows: () async => <Json>[
          <String, dynamic>{
            'name': _profileName,
            'updated_at': DateTime.utc(2026, 2, 19).toIso8601String(),
            'json': _okJson,
            'udid': _deviceA,
          },
          <String, dynamic>{
            'updated_at': DateTime.utc(2026, 2, 19).toIso8601String(),
            'json': _emptyJson,
            'udid': 'missing-name',
          },
        ],
      );

      final List<AreaSyncRecord> records = await repository.fetchProfiles();

      expect(records.length, 1);
      expect(records.single.name, _profileName);
    });

    test(
      'subscribeProfileChanges maps insert update and delete events',
      () async {
        final SupabaseClient client = _client();
        Future<void> Function(Json row)? insert;
        Future<void> Function(Json row)? update;
        Future<void> Function(Json row)? delete;
        final channel = _FakeRealtimeChannel();
        final changes = <AreaSyncChange>[];

        final repository = SupabaseAreaSyncRepository(
          client: client,
          subscribeProfileChanges:
              ({
                required excludedUdid,
                required Future<void> Function(Json) onInsertRow,
                required Future<void> Function(Json) onUpdateRow,
                required Future<void> Function(Json) onDeleteRow,
              }) {
                expect(excludedUdid, _localUdid);
                insert = onInsertRow;
                update = onUpdateRow;
                delete = onDeleteRow;
                return channel;
              },
        );

        final RealtimeChannel result = repository.subscribeProfileChanges(
          excludedUdid: _localUdid,
          onChange: (change) async => changes.add(change),
        );

        expect(result, same(channel));

        await insert!(<String, dynamic>{
          'name': _profileName,
          'updated_at': DateTime.utc(2026, 2, 19).toIso8601String(),
          'json': _emptyJson,
          'udid': 'remote-a',
        });
        await update!(<String, dynamic>{
          'name': _profileName,
          'updated_at': DateTime.utc(2026, 2, 20).toIso8601String(),
          'json': _emptyJson,
          'udid': 'remote-b',
        });
        await delete!(<String, dynamic>{'name': _profileName});
        await delete!(<String, dynamic>{});

        expect(changes.length, 3);
        expect(changes[0].type, AreaSyncChangeType.insert);
        expect(changes[1].type, AreaSyncChangeType.update);
        expect(changes[2].type, AreaSyncChangeType.delete);
        expect(changes[2].deletedName, _profileName);
      },
    );

    test('batchUpsertProfiles sends mapped payload rows', () async {
      final SupabaseClient client = _client();
      List<Json>? capturedRows;
      final repository = SupabaseAreaSyncRepository(
        client: client,
        upsertProfilesRows: (rows) async {
          capturedRows = rows;
        },
      );

      await repository.batchUpsertProfiles(<AreaSyncRecord>[
        AreaSyncRecord(
          name: _profileName,
          updatedAt: DateTime.utc(2026, 2, 19),
          json: _okJson,
          udid: _deviceA,
        ),
      ]);

      expect(capturedRows, isNotNull);
      expect(capturedRows!.single['name'], _profileName);
      expect(capturedRows!.single['udid'], _deviceA);
    });

    test('upsertProfile sends mapped payload row', () async {
      final SupabaseClient client = _client();
      Json? capturedRow;
      final repository = SupabaseAreaSyncRepository(
        client: client,
        upsertProfileRow: (row) async {
          capturedRow = row;
        },
      );

      await repository.upsertProfile(
        AreaSyncRecord(
          name: 'ICU',
          updatedAt: DateTime.utc(2026, 2, 19),
          json: '{"ok":true}',
          udid: 'device-z',
        ),
      );

      expect(capturedRow, isNotNull);
      expect(capturedRow!['name'], 'ICU');
      expect(capturedRow!['udid'], 'device-z');
    });

    test('deleteProfile delegates profile name', () async {
      final SupabaseClient client = _client();
      String? deletedName;
      final repository = SupabaseAreaSyncRepository(
        client: client,
        deleteProfileByName: (profileName) async {
          deletedName = profileName;
        },
      );

      await repository.deleteProfile(_profileName);

      expect(deletedName, _profileName);
    });

    test('batchUpsertProfiles returns for empty list', () async {
      final SupabaseClient client = _client();
      final repository = SupabaseAreaSyncRepository(client: client);

      await repository.batchUpsertProfiles(<AreaSyncRecord>[]);
    });

    test('parseRecordForTest parses valid row and keeps json string', () {
      final SupabaseClient client = _client();
      final repository = SupabaseAreaSyncRepository(client: client);
      final updatedAt = DateTime.utc(2026, 2, 19);

      final AreaSyncRecord? record = repository
          .parseRecordForTest(<String, dynamic>{
            'name': _profileName,
            'updated_at': updatedAt.toIso8601String(),
            'json': _fooJson,
            'udid': _deviceA,
          });

      expect(record, isNotNull);
      expect(record!.name, _profileName);
      expect(record.updatedAt, updatedAt);
      expect(record.json, _fooJson);
      expect(record.udid, _deviceA);
    });

    test('parseRecordForTest encodes non-string json values', () {
      final SupabaseClient client = _client();
      final repository = SupabaseAreaSyncRepository(client: client);

      final AreaSyncRecord? record = repository.parseRecordForTest(
        <String, dynamic>{
          'name': _profileName,
          'updated_at': DateTime.utc(2026, 2, 19).toIso8601String(),
          'json': <String, dynamic>{'foo': 1},
          'udid': _deviceA,
        },
      );

      expect(record, isNotNull);
      expect(record!.json, '{"foo":1}');
    });

    test(
      'parseRecordForTest returns null when required fields are invalid',
      () {
        final SupabaseClient client = _client();
        final repository = SupabaseAreaSyncRepository(client: client);

        expect(
          repository.parseRecordForTest(<String, dynamic>{
            'updated_at': DateTime.utc(2026, 2, 19).toIso8601String(),
            'json': _emptyJson,
            'udid': _deviceA,
          }),
          isNull,
        );

        expect(
          repository.parseRecordForTest(<String, dynamic>{
            'name': _profileName,
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
      final repository = SupabaseAreaSyncRepository(client: client);
      final updatedAt = DateTime.utc(2026, 2, 19, 12);
      final record = AreaSyncRecord(
        name: _profileName,
        updatedAt: updatedAt,
        json: _fooJson,
        udid: _deviceA,
      );

      final Json payload = repository.toPayloadForTest(record);

      expect(payload['name'], _profileName);
      expect(payload['updated_at'], updatedAt.toIso8601String());
      expect(payload['json'], _fooJson);
      expect(payload['udid'], _deviceA);
    });
  });
}

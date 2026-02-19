import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_count/main/models/sync_coordinator.dart';
import 'package:inventory_count/main/repositories/device_id_repository.dart';

const remoteDeviceId = 'remote-device';
const itemAKey = 'item-a';
const itemBKey = 'item-b';

class _FakeDeviceIdRepository implements DeviceIdRepository {
  _FakeDeviceIdRepository(this._id);

  final String _id;

  @override
  Future<String> getDeviceId() async => _id;
}

class _FakeRecord {
  _FakeRecord({required this.udid, required this.updatedAt, this.key = ''});

  final String udid;
  final DateTime updatedAt;
  final String key;
}

void main() {
  group('SyncCoordinator', () {
    late DateTime now;
    late SyncCoordinator coordinator;
    late bool pulled;
    late bool pushed;

    setUp(() {
      now = DateTime.now().toUtc();
      coordinator = SyncCoordinator(
        deviceIdRepository: _FakeDeviceIdRepository('local-device'),
      );
      pulled = false;
      pushed = false;
    });

    test('pulls remote when remote timestamp is newer', () async {
      await coordinator.reconcileSingle<_FakeRecord>(
        remoteRecord: _FakeRecord(udid: remoteDeviceId, updatedAt: now),
        remoteUdid: (record) => record.udid,
        remoteUpdatedAt: (record) => record.updatedAt,
        localUpdatedAt: now.subtract(const Duration(minutes: 5)),
        onPullRemote: (record, remoteUpdatedAt) async {
          pulled = true;
          expect(remoteUpdatedAt, now);
        },
        onPushLocal: () async {
          pushed = true;
        },
      );

      expect(pulled, isTrue);
      expect(pushed, isFalse);
    });

    test('pushes local when local timestamp is newer', () async {
      await coordinator.reconcileSingle<_FakeRecord>(
        remoteRecord: _FakeRecord(
          udid: remoteDeviceId,
          updatedAt: now.subtract(const Duration(minutes: 5)),
        ),
        remoteUdid: (record) => record.udid,
        remoteUpdatedAt: (record) => record.updatedAt,
        localUpdatedAt: now,
        onPullRemote: (record, remoteUpdatedAt) async {
          pulled = true;
        },
        onPushLocal: () async {
          pushed = true;
        },
      );

      expect(pulled, isFalse);
      expect(pushed, isTrue);
    });

    test('ignores records originating from this device', () async {
      coordinator = SyncCoordinator(
        deviceIdRepository: _FakeDeviceIdRepository('same-device'),
      );

      await coordinator.reconcileSingle<_FakeRecord>(
        remoteRecord: _FakeRecord(udid: 'same-device', updatedAt: now),
        remoteUdid: (record) => record.udid,
        remoteUpdatedAt: (record) => record.updatedAt,
        localUpdatedAt: now.subtract(const Duration(minutes: 10)),
        onPullRemote: (record, remoteUpdatedAt) async {
          pulled = true;
        },
        onPushLocal: () async {
          pushed = true;
        },
      );

      expect(pulled, isFalse);
      expect(pushed, isFalse);
    });

    test('does nothing when remote record is null', () async {
      await coordinator.reconcileSingle<_FakeRecord>(
        remoteRecord: null,
        remoteUdid: (record) => record.udid,
        remoteUpdatedAt: (record) => record.updatedAt,
        localUpdatedAt: now,
        onPullRemote: (record, remoteUpdatedAt) async {
          pulled = true;
        },
        onPushLocal: () async {
          pushed = true;
        },
      );

      expect(pulled, isFalse);
      expect(pushed, isFalse);
    });

    test('does nothing when timestamps are equal', () async {
      await coordinator.reconcileSingle<_FakeRecord>(
        remoteRecord: _FakeRecord(udid: remoteDeviceId, updatedAt: now),
        remoteUdid: (record) => record.udid,
        remoteUpdatedAt: (record) => record.updatedAt,
        localUpdatedAt: now,
        onPullRemote: (record, remoteUpdatedAt) async {
          pulled = true;
        },
        onPushLocal: () async {
          pushed = true;
        },
      );

      expect(pulled, isFalse);
      expect(pushed, isFalse);
    });

    test('reconcileCollection routes pull and push by record key', () async {
      final DateTime older = now.subtract(const Duration(minutes: 10));
      final DateTime newer = now.add(const Duration(minutes: 10));
      final localByKey = <String, DateTime>{itemAKey: older, itemBKey: newer};
      final pulledKeys = <String>[];
      final pushedKeys = <String>[];

      await coordinator.reconcileCollection<_FakeRecord, String>(
        remoteRecords: <_FakeRecord>[
          _FakeRecord(udid: 'remote-device-1', updatedAt: now, key: itemAKey),
          _FakeRecord(udid: 'remote-device-2', updatedAt: now, key: itemBKey),
        ],
        keyOf: (record) => record.key,
        remoteUdid: (record) => record.udid,
        remoteUpdatedAt: (record) => record.updatedAt,
        localUpdatedAtOf: (key) => localByKey[key],
        onPullRemote: (key, record, remoteUpdatedAt) async {
          pulledKeys.add(key);
          expect(record.key, key);
          expect(remoteUpdatedAt, now);
        },
        onPushLocal: (key, localUpdatedAt) async {
          pushedKeys.add(key);
          expect(localUpdatedAt, localByKey[key]);
        },
      );

      expect(pulledKeys, <String>[itemAKey]);
      expect(pushedKeys, <String>[itemBKey]);
    });
  });
}

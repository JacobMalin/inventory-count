import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_count/main/dependencies/app_dependencies.dart';
import 'package:inventory_count/main/models/data/export_entry.dart';
import 'package:inventory_count/main/models/data/inventory_models.dart';
import 'package:inventory_count/main/models/sync_coordinator.dart';
import 'package:inventory_count/main/repositories/area_local_repository.dart';
import 'package:inventory_count/main/repositories/area_sync_repository.dart';
import 'package:inventory_count/main/repositories/device_id_repository.dart';
import 'package:inventory_count/main/repositories/export_local_repository.dart';
import 'package:inventory_count/main/repositories/export_sync_repository.dart';
import 'package:inventory_count/main/repositories/sync_runtime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../test_hive_setup.dart';

class _FakeAreaLocalRepository implements AreaLocalRepository {
  @override
  Future<void> ensureInitialized() async {}

  @override
  int readItemIdCounter() => 0;

  @override
  Map<Profile, List<Area>> readProfiles() => <Profile, List<Area>>{};

  @override
  Future<void> writeItemIdCounter(int value) async {}

  @override
  Future<void> writeProfiles(Map<Profile, List<Area>> profiles) async {}
}

class _FakeAreaSyncRepository implements AreaSyncRepository {
  @override
  Future<void> batchUpsertProfiles(List<AreaSyncRecord> records) async {}

  @override
  Future<void> deleteProfile(String profileName) async {}

  @override
  Future<List<AreaSyncRecord>> fetchProfiles() async => <AreaSyncRecord>[];

  @override
  RealtimeChannel subscribeProfileChanges({
    required String excludedUdid,
    required Future<void> Function(AreaSyncChange change) onChange,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> upsertProfile(AreaSyncRecord record) async {}
}

class _FakeExportLocalRepository implements ExportLocalRepository {
  @override
  Future<void> ensureInitialized() async {}

  @override
  List<ExportEntry> readExportList() => <ExportEntry>[];

  @override
  Future<void> writeExportList(List<ExportEntry> exportList) async {}
}

class _FakeExportSyncRepository implements ExportSyncRepository {
  @override
  Future<ExportSyncRecord?> fetchLatest() async => null;

  @override
  Future<void> upsertLatest(ExportSyncRecord record) async {}

  @override
  Stream<ExportSyncRecord?> watchLatest() => const Stream.empty();
}

class _FakeDeviceIdRepository implements DeviceIdRepository {
  _FakeDeviceIdRepository(this._id);

  final String _id;

  @override
  Future<String> getDeviceId() async => _id;
}

class _RemoteRecord {
  _RemoteRecord({required this.udid, required this.updatedAt});

  final String udid;
  final DateTime updatedAt;
}

var _supabaseInitialized = false;

Future<void> _initializeSupabaseIfNeeded() async {
  const channel = MethodChannel('plugins.flutter.io/shared_preferences');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (methodCall) async {
        if (methodCall.method == 'getAll') {
          return <String, Object>{};
        }

        if (methodCall.method == 'setString' ||
            methodCall.method == 'setBool' ||
            methodCall.method == 'setInt' ||
            methodCall.method == 'setDouble' ||
            methodCall.method == 'setStringList' ||
            methodCall.method == 'remove' ||
            methodCall.method == 'clear') {
          return true;
        }

        return null;
      });

  if (_supabaseInitialized) {
    return;
  }

  try {
    await Supabase.initialize(url: 'https://example.com', anonKey: 'anon-key');
  } on Object {
    // Already initialized in this test process.
  }

  _supabaseInitialized = true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppDependencies', () {
    setUpAll(() async {
      await initializeTestHive();
      await _initializeSupabaseIfNeeded();
    });

    tearDownAll(() async {
      await disposeTestHive();
    });

    test('uses provided dependency instances', () {
      final areaLocalRepository = _FakeAreaLocalRepository();
      final areaSyncRepository = _FakeAreaSyncRepository();
      final exportLocalRepository = _FakeExportLocalRepository();
      final exportSyncRepository = _FakeExportSyncRepository();
      final deviceIdRepository = _FakeDeviceIdRepository('device-1');
      final syncRuntime = SyncRuntime.forTest(
        statusChanges: const Stream.empty(),
      );
      final syncCoordinator = SyncCoordinator(
        deviceIdRepository: _FakeDeviceIdRepository('device-2'),
      );

      final dependencies = AppDependencies(
        areaLocalRepository: areaLocalRepository,
        areaSyncRepository: areaSyncRepository,
        exportLocalRepository: exportLocalRepository,
        exportSyncRepository: exportSyncRepository,
        deviceIdRepository: deviceIdRepository,
        syncRuntime: syncRuntime,
        syncCoordinator: syncCoordinator,
      );

      expect(
        identical(dependencies.areaLocalRepository, areaLocalRepository),
        isTrue,
      );
      expect(
        identical(dependencies.areaSyncRepository, areaSyncRepository),
        isTrue,
      );
      expect(
        identical(dependencies.exportLocalRepository, exportLocalRepository),
        isTrue,
      );
      expect(
        identical(dependencies.exportSyncRepository, exportSyncRepository),
        isTrue,
      );
      expect(
        identical(dependencies.deviceIdRepository, deviceIdRepository),
        isTrue,
      );
      expect(identical(dependencies.syncRuntime, syncRuntime), isTrue);
      expect(identical(dependencies.syncCoordinator, syncCoordinator), isTrue);
    });

    test('builds syncCoordinator with resolved deviceIdRepository', () async {
      final dependencies = AppDependencies(
        areaLocalRepository: _FakeAreaLocalRepository(),
        areaSyncRepository: _FakeAreaSyncRepository(),
        exportLocalRepository: _FakeExportLocalRepository(),
        exportSyncRepository: _FakeExportSyncRepository(),
        deviceIdRepository: _FakeDeviceIdRepository('local-device'),
        syncRuntime: SyncRuntime.forTest(statusChanges: const Stream.empty()),
      );

      var pulled = false;
      var pushed = false;
      final DateTime now = DateTime.now().toUtc();

      await dependencies.syncCoordinator.reconcileSingle<_RemoteRecord>(
        remoteRecord: _RemoteRecord(udid: 'local-device', updatedAt: now),
        remoteUdid: (record) => record.udid,
        remoteUpdatedAt: (record) => record.updatedAt,
        localUpdatedAt: now.subtract(const Duration(minutes: 5)),
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

    test('creates expected defaults when optional values are omitted', () {
      final dependencies = AppDependencies(
        areaSyncRepository: _FakeAreaSyncRepository(),
        exportSyncRepository: _FakeExportSyncRepository(),
      );

      expect(dependencies.areaLocalRepository, isA<HiveAreaLocalRepository>());
      expect(
        dependencies.exportLocalRepository,
        isA<HiveExportLocalRepository>(),
      );
      expect(
        dependencies.deviceIdRepository,
        isA<FlutterUdidDeviceIdRepository>(),
      );
      expect(identical(dependencies.syncRuntime, SyncRuntime()), isTrue);
      expect(dependencies.syncCoordinator, isA<SyncCoordinator>());
    });

    test('uses provided values and defaults only omitted dependencies', () {
      final areaLocalRepository = _FakeAreaLocalRepository();
      final areaSyncRepository = _FakeAreaSyncRepository();
      final exportSyncRepository = _FakeExportSyncRepository();

      final dependencies = AppDependencies(
        areaLocalRepository: areaLocalRepository,
        areaSyncRepository: areaSyncRepository,
        exportSyncRepository: exportSyncRepository,
      );

      expect(
        identical(dependencies.areaLocalRepository, areaLocalRepository),
        isTrue,
      );
      expect(
        identical(dependencies.areaSyncRepository, areaSyncRepository),
        isTrue,
      );
      expect(
        identical(dependencies.exportSyncRepository, exportSyncRepository),
        isTrue,
      );
      expect(
        dependencies.exportLocalRepository,
        isA<HiveExportLocalRepository>(),
      );
      expect(dependencies.syncCoordinator, isA<SyncCoordinator>());
    });

    test(
      'prefers provided syncCoordinator over implicit construction',
      () async {
        final providedDeviceRepository = _FakeDeviceIdRepository(
          'provided-device',
        );
        final coordinatorDeviceRepository = _FakeDeviceIdRepository(
          'coordinator-device',
        );
        final providedCoordinator = SyncCoordinator(
          deviceIdRepository: coordinatorDeviceRepository,
        );

        final dependencies = AppDependencies(
          areaLocalRepository: _FakeAreaLocalRepository(),
          areaSyncRepository: _FakeAreaSyncRepository(),
          exportLocalRepository: _FakeExportLocalRepository(),
          exportSyncRepository: _FakeExportSyncRepository(),
          deviceIdRepository: providedDeviceRepository,
          syncRuntime: SyncRuntime.forTest(statusChanges: const Stream.empty()),
          syncCoordinator: providedCoordinator,
        );

        var pulled = false;
        final DateTime now = DateTime.now().toUtc();

        await dependencies.syncCoordinator.reconcileSingle<_RemoteRecord>(
          remoteRecord: _RemoteRecord(udid: 'provided-device', updatedAt: now),
          remoteUdid: (record) => record.udid,
          remoteUpdatedAt: (record) => record.updatedAt,
          localUpdatedAt: now.subtract(const Duration(minutes: 5)),
          onPullRemote: (record, remoteUpdatedAt) async {
            pulled = true;
          },
          onPushLocal: () async {},
        );

        expect(
          identical(dependencies.syncCoordinator, providedCoordinator),
          isTrue,
        );
        expect(pulled, isTrue);
      },
    );

    test('uses singleton SyncRuntime when runtime is omitted', () {
      final dependencies = AppDependencies(
        areaLocalRepository: _FakeAreaLocalRepository(),
        areaSyncRepository: _FakeAreaSyncRepository(),
        exportLocalRepository: _FakeExportLocalRepository(),
        exportSyncRepository: _FakeExportSyncRepository(),
      );

      expect(identical(dependencies.syncRuntime, SyncRuntime()), isTrue);
    });

    test('creates default sync repositories when omitted', () {
      final dependencies = AppDependencies(
        areaLocalRepository: _FakeAreaLocalRepository(),
        exportLocalRepository: _FakeExportLocalRepository(),
      );

      expect(
        dependencies.areaSyncRepository,
        isA<SupabaseAreaSyncRepository>(),
      );
      expect(
        dependencies.exportSyncRepository,
        isA<SupabaseExportSyncRepository>(),
      );
    });
  });
}

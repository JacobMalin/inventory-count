import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_count/main/models/area_model.dart';
import 'package:inventory_count/main/models/count_model.dart';
import 'package:inventory_count/main/models/data/export_entry.dart';
import 'package:inventory_count/main/models/data/inventory_models.dart';
import 'package:inventory_count/main/models/export_model.dart';
import 'package:inventory_count/main/models/sync_coordinator.dart';
import 'package:inventory_count/main/repositories/area_local_repository.dart';
import 'package:inventory_count/main/repositories/area_sync_repository.dart';
import 'package:inventory_count/main/repositories/device_id_repository.dart';
import 'package:inventory_count/main/repositories/export_local_repository.dart';
import 'package:inventory_count/main/repositories/export_sync_repository.dart';
import 'package:inventory_count/main/repositories/sync_runtime.dart';
import 'package:inventory_count/main/setup/setup_page.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../test_hive_setup.dart';

class _InMemoryAreaLocalRepository implements AreaLocalRepository {
  final Map<Profile, List<Area>> _profiles = <Profile, List<Area>>{};
  int _itemIdCounter = 0;

  @override
  Future<void> ensureInitialized() async {}

  @override
  int readItemIdCounter() => _itemIdCounter;

  @override
  Map<Profile, List<Area>> readProfiles() => _profiles;

  @override
  Future<void> writeItemIdCounter(int value) async {
    _itemIdCounter = value;
  }

  @override
  Future<void> writeProfiles(Map<Profile, List<Area>> profiles) async {
    _profiles
      ..clear()
      ..addAll(profiles);
  }
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

class _InMemoryExportLocalRepository implements ExportLocalRepository {
  final List<ExportEntry> _exportList = <ExportEntry>[];

  @override
  Future<void> ensureInitialized() async {}

  @override
  List<ExportEntry> readExportList() => _exportList;

  @override
  Future<void> writeExportList(List<ExportEntry> exportList) async {
    _exportList
      ..clear()
      ..addAll(exportList);
  }
}

class _FakeExportSyncRepository implements ExportSyncRepository {
  @override
  Future<ExportSyncRecord?> fetchLatest() async => null;

  @override
  Future<void> upsertCountExport({
    required DateTime when,
    required String profile,
    required String json,
  }) async {}

  @override
  Future<void> upsertLatest(ExportSyncRecord record) async {}

  @override
  Stream<ExportSyncRecord?> watchLatest() => const Stream.empty();
}

class _FakeDeviceIdRepository implements DeviceIdRepository {
  @override
  Future<String> getDeviceId() async => 'test-device';
}

void main() {
  setUpAll(initializeTestHive);
  tearDownAll(disposeTestHive);
  setUp(resetTestHiveData);

  group('SetupPage', () {
    testWidgets('shows tab labels and areas tab content by default', (
      tester,
    ) async {
      final deviceIdRepository = _FakeDeviceIdRepository();
      final syncRuntime = SyncRuntime.forTest(
        statusChanges: const Stream.empty(),
      );
      final areaModel = AreaModel(
        countModel: CountModel(),
        deviceIdRepository: deviceIdRepository,
        syncCoordinator: SyncCoordinator(
          deviceIdRepository: deviceIdRepository,
        ),
        localRepository: _InMemoryAreaLocalRepository(),
        syncRepository: _FakeAreaSyncRepository(),
        syncRuntime: syncRuntime,
      );
      final exportModel = ExportModel(
        deviceIdRepository: deviceIdRepository,
        syncCoordinator: SyncCoordinator(
          deviceIdRepository: deviceIdRepository,
        ),
        localRepository: _InMemoryExportLocalRepository(),
        syncRepository: _FakeExportSyncRepository(),
        syncRuntime: syncRuntime,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AreaModel>.value(value: areaModel),
            ChangeNotifierProvider<ExportModel>.value(value: exportModel),
          ],
          child: const MaterialApp(home: SetupPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Areas'), findsNWidgets(2));
      expect(find.text('Export Order'), findsOneWidget);
      expect(find.text('Add Area'), findsOneWidget);
    });

    testWidgets('switches to export tab when tapped', (tester) async {
      final deviceIdRepository = _FakeDeviceIdRepository();
      final syncRuntime = SyncRuntime.forTest(
        statusChanges: const Stream.empty(),
      );
      final areaModel = AreaModel(
        countModel: CountModel(),
        deviceIdRepository: deviceIdRepository,
        syncCoordinator: SyncCoordinator(
          deviceIdRepository: deviceIdRepository,
        ),
        localRepository: _InMemoryAreaLocalRepository(),
        syncRepository: _FakeAreaSyncRepository(),
        syncRuntime: syncRuntime,
      );
      final exportModel = ExportModel(
        deviceIdRepository: deviceIdRepository,
        syncCoordinator: SyncCoordinator(
          deviceIdRepository: deviceIdRepository,
        ),
        localRepository: _InMemoryExportLocalRepository(),
        syncRepository: _FakeExportSyncRepository(),
        syncRuntime: syncRuntime,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AreaModel>.value(value: areaModel),
            ChangeNotifierProvider<ExportModel>.value(value: exportModel),
          ],
          child: const MaterialApp(home: SetupPage()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Export Order').first);
      await tester.pumpAndSettle();

      expect(find.text('No items to export'), findsOneWidget);
    });
  });
}

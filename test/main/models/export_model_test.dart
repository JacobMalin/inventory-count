import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_count/main/models/count_model.dart';
import 'package:inventory_count/main/models/data/export_entry.dart';
import 'package:inventory_count/main/models/data/inventory_models.dart';
import 'package:inventory_count/main/models/export_model.dart';
import 'package:inventory_count/main/models/sync_coordinator.dart';
import 'package:inventory_count/main/repositories/device_id_repository.dart';
import 'package:inventory_count/main/repositories/export_local_repository.dart';
import 'package:inventory_count/main/repositories/export_sync_repository.dart';
import 'package:inventory_count/main/repositories/sync_runtime.dart';

import '../../test_hive_setup.dart';

class _InMemoryExportLocalRepository implements ExportLocalRepository {
  _InMemoryExportLocalRepository([List<ExportEntry>? entries])
    : _entries = entries ?? <ExportEntry>[];

  final List<ExportEntry> _entries;

  @override
  Future<void> ensureInitialized() async {}

  @override
  List<ExportEntry> readExportList() => _entries;

  @override
  Future<void> writeExportList(List<ExportEntry> exportList) async {
    _entries
      ..clear()
      ..addAll(exportList);
  }
}

class _CapturingExportSyncRepository implements ExportSyncRepository {
  DateTime? capturedWhen;
  String? capturedProfile;
  String? capturedJson;

  @override
  Future<ExportSyncRecord?> fetchLatest() async => null;

  @override
  Future<void> upsertCountExport({
    required DateTime when,
    required String profile,
    required String json,
  }) async {
    capturedWhen = when;
    capturedProfile = profile;
    capturedJson = json;
  }

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

  group('ExportModel', () {
    test(
      'upsertCountExport forwards selectedDate to sync repository',
      () async {
        final selectedDate = DateTime.utc(2026, 3, 1, 5, 30);
        final countModel = CountModel()
          ..setSelectedDate(selectedDate)
          ..selectedProfile = Profile('Night Shift');

        final syncRepository = _CapturingExportSyncRepository();
        final model = ExportModel(
          deviceIdRepository: _FakeDeviceIdRepository(),
          syncCoordinator: SyncCoordinator(
            deviceIdRepository: _FakeDeviceIdRepository(),
          ),
          localRepository: _InMemoryExportLocalRepository(),
          syncRepository: syncRepository,
          syncRuntime: SyncRuntime.forTest(statusChanges: const Stream.empty()),
        );

        await model.upsertCountExport(countModel);

        expect(syncRepository.capturedWhen, selectedDate);
        expect(syncRepository.capturedProfile, 'Night Shift');
        expect(syncRepository.capturedJson, '{}');

        await model.dispose();
      },
    );
  });
}

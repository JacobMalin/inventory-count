import '../models/sync_coordinator.dart';
import '../repositories/area_local_repository.dart';
import '../repositories/area_sync_repository.dart';
import '../repositories/device_id_repository.dart';
import '../repositories/export_local_repository.dart';
import '../repositories/export_sync_repository.dart';
import '../repositories/sync_runtime.dart';

class AppDependencies {
  factory AppDependencies({
    AreaLocalRepository? areaLocalRepository,
    AreaSyncRepository? areaSyncRepository,
    ExportLocalRepository? exportLocalRepository,
    ExportSyncRepository? exportSyncRepository,
    DeviceIdRepository? deviceIdRepository,
    SyncCoordinator? syncCoordinator,
    SyncRuntime? syncRuntime,
  }) {
    final DeviceIdRepository resolvedDeviceIdRepository =
        deviceIdRepository ?? FlutterUdidDeviceIdRepository();

    return AppDependencies._(
      areaLocalRepository: areaLocalRepository ?? HiveAreaLocalRepository(),
      areaSyncRepository: areaSyncRepository ?? SupabaseAreaSyncRepository(),
      exportLocalRepository:
          exportLocalRepository ?? HiveExportLocalRepository(),
      exportSyncRepository:
          exportSyncRepository ?? SupabaseExportSyncRepository(),
      deviceIdRepository: resolvedDeviceIdRepository,
      syncRuntime: syncRuntime ?? SyncRuntime(),
      syncCoordinator:
          syncCoordinator ??
          SyncCoordinator(deviceIdRepository: resolvedDeviceIdRepository),
    );
  }

  AppDependencies._({
    required this.areaLocalRepository,
    required this.areaSyncRepository,
    required this.exportLocalRepository,
    required this.exportSyncRepository,
    required this.deviceIdRepository,
    required this.syncRuntime,
    required this.syncCoordinator,
  });

  final AreaLocalRepository areaLocalRepository;
  final AreaSyncRepository areaSyncRepository;
  final ExportLocalRepository exportLocalRepository;
  final ExportSyncRepository exportSyncRepository;
  final DeviceIdRepository deviceIdRepository;
  final SyncRuntime syncRuntime;
  final SyncCoordinator syncCoordinator;
}

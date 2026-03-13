import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../models/area_model.dart';
import '../models/count_model.dart';
import '../models/export_model.dart';
import '../models/sync_coordinator.dart';
import '../repositories/area_local_repository.dart';
import '../repositories/area_sync_repository.dart';
import '../repositories/count_local_repository.dart';
import '../repositories/count_sync_repository.dart';
import '../repositories/device_id_repository.dart';
import '../repositories/export_local_repository.dart';
import '../repositories/export_sync_repository.dart';
import '../repositories/notes_local_repository.dart';
import '../repositories/sync_runtime.dart';

class AppDependencies {
  factory AppDependencies({
    CountLocalRepository? countLocalRepository,
    CountSyncRepository? countSyncRepository,
    AreaLocalRepository? areaLocalRepository,
    AreaSyncRepository? areaSyncRepository,
    ExportLocalRepository? exportLocalRepository,
    ExportSyncRepository? exportSyncRepository,
    NotesLocalRepository? notesLocalRepository,
    DeviceIdRepository? deviceIdRepository,
    SyncCoordinator? syncCoordinator,
    SyncRuntime? syncRuntime,
    bool disableSync = false,
  }) {
    final DeviceIdRepository resolvedDeviceIdRepository =
        deviceIdRepository ?? FlutterUdidDeviceIdRepository();

    return AppDependencies._(
      countLocalRepository: countLocalRepository ?? HiveCountLocalRepository(),
      countSyncRepository: countSyncRepository ?? SupabaseCountSyncRepository(),
      areaLocalRepository: areaLocalRepository ?? HiveAreaLocalRepository(),
      areaSyncRepository: areaSyncRepository ?? SupabaseAreaSyncRepository(),
      exportLocalRepository:
          exportLocalRepository ?? HiveExportLocalRepository(),
      exportSyncRepository:
          exportSyncRepository ?? SupabaseExportSyncRepository(),
      notesLocalRepository: notesLocalRepository ?? HiveNotesLocalRepository(),
      deviceIdRepository: resolvedDeviceIdRepository,
      syncRuntime: syncRuntime ?? SyncRuntime(),
      syncCoordinator:
          syncCoordinator ??
          SyncCoordinator(deviceIdRepository: resolvedDeviceIdRepository),
      disableSync: disableSync,
    );
  }

  AppDependencies._({
    required this.countLocalRepository,
    required this.countSyncRepository,
    required this.areaLocalRepository,
    required this.areaSyncRepository,
    required this.exportLocalRepository,
    required this.exportSyncRepository,
    required this.notesLocalRepository,
    required this.deviceIdRepository,
    required this.syncRuntime,
    required this.syncCoordinator,
    required this.disableSync,
  });
  final bool disableSync;

  final CountLocalRepository countLocalRepository;
  final CountSyncRepository countSyncRepository;
  final AreaLocalRepository areaLocalRepository;
  final AreaSyncRepository areaSyncRepository;
  final ExportLocalRepository exportLocalRepository;
  final ExportSyncRepository exportSyncRepository;
  final NotesLocalRepository notesLocalRepository;
  final DeviceIdRepository deviceIdRepository;
  final SyncRuntime syncRuntime;
  final SyncCoordinator syncCoordinator;

  List<SingleChildWidget> createProviders() {
    return [
      Provider<AppDependencies>.value(value: this),
      Provider<NotesLocalRepository>.value(value: notesLocalRepository),
      ChangeNotifierProvider<ExportModel>(
        create: (context) => ExportModel(
          localRepository: exportLocalRepository,
          syncRepository: exportSyncRepository,
          deviceIdRepository: deviceIdRepository,
          syncCoordinator: syncCoordinator,
          syncRuntime: syncRuntime,
        ),
      ),
      ChangeNotifierProxyProvider<ExportModel, CountModel>(
        create: (context) => CountModel(
          localRepository: countLocalRepository,
          syncRepository: countSyncRepository,
          exportLocalRepository: exportLocalRepository,
          exportModel: context.read<ExportModel>(),
          syncRuntime: syncRuntime,
          disableSync: disableSync,
        ),
        update: (context, exportModel, countModel) {
          if (countModel != null) {
            countModel.exportModel = exportModel;
            return countModel;
          }

          return CountModel(
            localRepository: countLocalRepository,
            syncRepository: countSyncRepository,
            exportLocalRepository: exportLocalRepository,
            exportModel: exportModel,
            syncRuntime: syncRuntime,
            disableSync: disableSync,
          );
        },
      ),
      ChangeNotifierProxyProvider<CountModel, AreaModel>(
        create: (context) => AreaModel(
          countModel: context.read<CountModel>(),
          localRepository: areaLocalRepository,
          syncRepository: areaSyncRepository,
          deviceIdRepository: deviceIdRepository,
          syncCoordinator: syncCoordinator,
          syncRuntime: syncRuntime,
          disableSync: disableSync,
        ),
        update: (context, countModel, areaModel) {
          areaModel?.countModel = countModel;
          if (areaModel != null) {
            return areaModel;
          }

          return AreaModel(
            countModel: countModel,
            localRepository: areaLocalRepository,
            syncRepository: areaSyncRepository,
            deviceIdRepository: deviceIdRepository,
            syncCoordinator: syncCoordinator,
            syncRuntime: syncRuntime,
            disableSync: disableSync,
          );
        },
      ),
    ];
  }
}

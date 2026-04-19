import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../models/area_model.dart';
import '../models/count_model.dart';
import '../models/export_model.dart';
import '../repositories/notes_local_repository.dart';

class AppDependencies {
  factory AppDependencies({bool disableSync = false}) {
    return AppDependencies._(disableSync: disableSync);
  }

  AppDependencies._({required this.disableSync});
  final bool disableSync;

  List<SingleChildWidget> createProviders() {
    return [
      Provider<AppDependencies>.value(value: this),
      Provider<NotesLocalRepository>.value(value: HiveNotesLocalRepository()),
      ChangeNotifierProvider<ExportModel>(
        create: (context) => ExportModel(disableSync: disableSync),
      ),
      ChangeNotifierProxyProvider<ExportModel, CountModel>(
        create: (context) => CountModel(
          exportModel: context.read<ExportModel>(),
          disableSync: disableSync,
        ),
        update: (context, exportModel, countModel) {
          if (countModel != null) {
            countModel.exportModel = exportModel;
            return countModel;
          }

          return CountModel(exportModel: exportModel, disableSync: disableSync);
        },
      ),
      ChangeNotifierProxyProvider<CountModel, AreaModel>(
        create: (context) => AreaModel(
          countModel: context.read<CountModel>(),
          disableSync: disableSync,
        ),
        update: (context, countModel, areaModel) {
          areaModel?.countModel = countModel;
          if (areaModel != null) {
            return areaModel;
          }

          return AreaModel(countModel: countModel, disableSync: disableSync);
        },
      ),
    ];
  }
}

import 'package:device_preview/device_preview.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'count_page.dart';
import 'dependencies/app_dependencies.dart';
import 'export_page.dart';
import 'fix_page.dart';
import 'models/area_model.dart';
import 'models/count_model.dart';
import 'models/data/inventory_models.dart';
import 'models/export_model.dart';
import 'setup/setup_page.dart';
import 'widgets/date_picker.dart';
import 'widgets/profile_selection.dart';

class MainApp extends StatelessWidget {
  const MainApp({super.key, AppDependencies? dependencies})
    : _dependencies = dependencies;

  final AppDependencies? _dependencies;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AppDependencies>(
          create: (context) => _dependencies ?? AppDependencies(),
        ),
        ChangeNotifierProvider<CountModel>(create: (context) => CountModel()),
        ChangeNotifierProvider<ExportModel>(
          create: (context) {
            final AppDependencies appDependencies = context
                .read<AppDependencies>();

            return ExportModel(
              localRepository: appDependencies.exportLocalRepository,
              syncRepository: appDependencies.exportSyncRepository,
              deviceIdRepository: appDependencies.deviceIdRepository,
              syncCoordinator: appDependencies.syncCoordinator,
              syncRuntime: appDependencies.syncRuntime,
            );
          },
        ),
        ChangeNotifierProxyProvider<CountModel, AreaModel>(
          create: (context) {
            final AppDependencies appDependencies = context
                .read<AppDependencies>();

            return AreaModel(
              countModel: context.read<CountModel>(),
              localRepository: appDependencies.areaLocalRepository,
              syncRepository: appDependencies.areaSyncRepository,
              deviceIdRepository: appDependencies.deviceIdRepository,
              syncCoordinator: appDependencies.syncCoordinator,
              syncRuntime: appDependencies.syncRuntime,
            );
          },
          update: (context, countModel, areaModel) {
            areaModel?.countModel = countModel;
            if (areaModel != null) {
              return areaModel;
            }

            final AppDependencies appDependencies = context
                .read<AppDependencies>();
            return AreaModel(
              countModel: countModel,
              localRepository: appDependencies.areaLocalRepository,
              syncRepository: appDependencies.areaSyncRepository,
              deviceIdRepository: appDependencies.deviceIdRepository,
              syncCoordinator: appDependencies.syncCoordinator,
              syncRuntime: appDependencies.syncRuntime,
            );
          },
        ),
      ],
      builder: (context, child) => MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: DevicePreview.locale(context),
        builder: DevicePreview.appBuilder,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color.fromARGB(255, 18, 75, 99),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: const HomePage(),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentPageIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Consumer<CountModel>(
      builder: (context, countModel, child) {
        final Profile? currentProfile = countModel.selectedProfile;

        return Scaffold(
          bottomNavigationBar: BottomAppBar(
            height: currentProfile != null ? 136 : 64,
            padding: const EdgeInsets.only(left: 16, right: 16, top: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (currentProfile != null) ...[
                  TooltipVisibility(
                    visible: false,
                    child: NavigationBar(
                      height: 60,
                      onDestinationSelected: (index) {
                        setState(() {
                          _currentPageIndex = index;
                        });
                      },
                      selectedIndex: _currentPageIndex,
                      destinations: const <Widget>[
                        NavigationDestination(
                          icon: Icon(Icons.list),
                          label: 'Count',
                          tooltip: '',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.bug_report),
                          label: 'Fix',
                          tooltip: '',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.print),
                          label: 'Export',
                          tooltip: '',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.settings),
                          label: 'Setup',
                          tooltip: '',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                const DatePicker(),
              ],
            ),
          ),
          body: currentProfile != null
              ? [
                  const CountPage(),
                  const FixPage(),
                  const ExportPage(),
                  const SetupPage(),
                ][_currentPageIndex]
              : const SelectProfile(),
        );
      },
    );
  }
}

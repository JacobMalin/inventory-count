import 'package:device_preview/device_preview.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'main/count_page.dart';
import 'main/dependencies/app_dependencies.dart';
import 'main/export_page.dart';
import 'main/fix_page.dart';
import 'main/models/count_model.dart';
import 'main/models/data/inventory_models.dart';
import 'main/setup_page.dart';
import 'main/tools_page.dart';
import 'main/widgets/date_picker.dart';
import 'main/widgets/profile_selection.dart';

class MainApp extends StatelessWidget {
  const MainApp({
    super.key,
    AppDependencies? dependencies,
    bool disableSync = false,
  }) : _disableSync = disableSync,
       _dependencies = dependencies;

  final AppDependencies? _dependencies;
  final bool _disableSync;

  @override
  Widget build(BuildContext context) {
    final AppDependencies dependencies =
        _dependencies ?? AppDependencies(disableSync: _disableSync);

    return MultiProvider(
      providers: dependencies.createProviders(),
      child: MaterialApp(
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
                        if (index == 4 && _currentPageIndex == 4) {
                          // If Tools is reselected, pop to tool selection
                          ToolsPage.navigatorKey.currentState?.popUntil(
                            (route) => route.isFirst,
                          );
                        } else {
                          setState(() {
                            _currentPageIndex = index;
                          });
                        }
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
                        NavigationDestination(
                          icon: Icon(Icons.build),
                          label: 'Tools',
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
                  const ToolsPage(),
                ][_currentPageIndex]
              : const SelectProfile(),
        );
      },
    );
  }
}

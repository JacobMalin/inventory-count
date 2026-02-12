import 'package:device_preview/device_preview.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'companion/companion_app.dart';
import 'companion/companion_setup.dart';
import 'count_page.dart';
import 'export_page.dart';
import 'fix_page.dart';
import 'hive_error_page.dart';
import 'models/area_model.dart';
import 'models/count_model.dart';
import 'models/export_model.dart';
import 'models/hive.dart';
import 'setup/setup_page.dart';
import 'widgets/date_picker.dart';
import 'widgets/profile_selection.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://qvlnvdgtmvjgjcsgfiiq.supabase.co',
    anonKey: 'sb_publishable_6GGLYRmVrTZ5yLI64u1vmQ_jkm5imVL',
  );

  // Environment variable is set via --dart-define=COMPANION=true to build the
  // companion app
  // ignore: do_not_use_environment
  if (const String.fromEnvironment('COMPANION') == 'true') {
    await companionHiveSetup();

    await windowSetup();

    runApp(const CompanionApp());

    return;
  }

  String? hiveError;
  try {
    await hiveSetup();
  } on Exception catch (e) {
    hiveError = e.toString();
  }

  runApp(
    DevicePreview(
      // False positive
      // ignore: avoid_redundant_argument_values
      enabled: !kReleaseMode,
      builder: (context) => hiveError != null
          ? HiveErrorPage(errorMessage: hiveError)
          : const MainApp(),
    ),
  );
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<CountModel>(create: (context) => CountModel()),
        ChangeNotifierProvider<ExportModel>(create: (context) => ExportModel()),
        ChangeNotifierProxyProvider<CountModel, AreaModel>(
          create: (context) => AreaModel(context.read<CountModel>()),
          update: (context, countModel, areaModel) {
            return areaModel ?? AreaModel(countModel);
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
                  NavigationBar(
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

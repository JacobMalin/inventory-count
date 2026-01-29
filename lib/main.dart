import 'package:device_preview/device_preview.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:inventory_count/companion/companion_app.dart';
import 'package:inventory_count/companion/companion_setup.dart';
import 'package:inventory_count/fix_page.dart';
import 'package:inventory_count/models/count_model.dart';
import 'package:inventory_count/models/hive.dart';
import 'package:inventory_count/models/area_model.dart';
import 'package:inventory_count/count_page.dart';
import 'package:inventory_count/export_page.dart';
import 'package:inventory_count/setup/setup_page.dart';
import 'package:inventory_count/hive_error_page.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://qvlnvdgtmvjgjcsgfiiq.supabase.co',
    anonKey: 'sb_publishable_6GGLYRmVrTZ5yLI64u1vmQ_jkm5imVL',
  );

  if (args.contains('-companion') || true) {
    await companionHiveSetup();

    await windowSetup();

    runApp(const CompanionApp());

    return;
  }

  String? hiveError;
  try {
    await hiveSetup();
  } catch (e) {
    hiveError = e.toString();
  }

  runApp(
    DevicePreview(
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
        ChangeNotifierProvider(create: (context) => AreaModel()),
        ChangeNotifierProvider(create: (context) => CountModel()),
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
  int currentPageIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: NavigationBar(
        onDestinationSelected: (int index) {
          setState(() {
            currentPageIndex = index;
          });
        },
        selectedIndex: currentPageIndex,
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
        labelBehavior: null,
      ),
      body: [
        const CountPage(),
        const FixPage(),
        const ExportPage(),
        const SetupPage(),
      ][currentPageIndex],
    );
  }
}

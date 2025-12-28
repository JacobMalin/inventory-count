import 'package:device_preview/device_preview.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:inventory_count/area.dart';
import 'package:inventory_count/count_page.dart';
import 'package:inventory_count/setup_page.dart';

void main() async {
  await Hive.initFlutter('inventory_count');

  Hive.registerAdapter<Area>(AreaAdapter());

  await Hive.openBox<Area>('areas');
  await Hive.openBox('shelves');

  runApp(
    kDebugMode
        ? DevicePreview(builder: (context) => const MainApp())
        : const MainApp(),
  );
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
          NavigationDestination(icon: Icon(Icons.home), label: 'Setup'),
          NavigationDestination(icon: Icon(Icons.list), label: 'Count'),
          NavigationDestination(icon: Icon(Icons.bug_report), label: 'Fix'),
          NavigationDestination(icon: Icon(Icons.print), label: 'Print'),
        ],
      ),
      body: [
        const SetupPage(),
        const CountPage(),
        const Center(child: Text('Fix Page')),
        const Center(child: Text('Print Page')),
      ][currentPageIndex],
    );
  }
}

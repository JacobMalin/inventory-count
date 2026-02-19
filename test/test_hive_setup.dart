import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:inventory_count/main/models/data/count_strategy.dart';
import 'package:inventory_count/main/models/data/export_entry.dart';
import 'package:inventory_count/main/models/data/inventory_models.dart';

Directory? hiveDirectory;
var _adaptersRegistered = false;

Future<void> initializeTestHive() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  hiveDirectory = await Directory.systemTemp.createTemp(
    'inventory_count_test_',
  );

  Hive.init(hiveDirectory!.path);
  _registerAdaptersIfNeeded();

  await Hive.openBox('areas');
  await Hive.openBox<Count>('counts');
  await Hive.openBox('settings');

  await resetTestHiveData();
}

Future<void> resetTestHiveData() async {
  await Hive.box('areas').clear();
  await Hive.box<Count>('counts').clear();
  await Hive.box('settings').clear();

  await Hive.box('areas').put('profiles', <Profile, List<Area>>{});
  await Hive.box('areas').put('itemIdCounter', 0);

  await Hive.box('settings').put('hideCountedItems', false);
  await Hive.box('settings').put('isProfileRemembered', false);
  await Hive.box('settings').put('exportList', <ExportEntry>[]);
}

Future<void> disposeTestHive() async {
  await Hive.close();
}

void _registerAdaptersIfNeeded() {
  if (_adaptersRegistered) {
    return;
  }

  Hive
    ..registerAdapter<Area>(AreaAdapter())
    ..registerAdapter<Shelf>(ShelfAdapter())
    ..registerAdapter<Item>(ItemAdapter())
    ..registerAdapter<CountPhase>(CountPhaseAdapter())
    ..registerAdapter<Count>(CountAdapter())
    ..registerAdapter<CountEntry>(CountEntryAdapter())
    ..registerAdapter<Profile>(ProfileAdapter());

  registerCountStrategyAdapters();
  registerExportEntryAdapters();

  _adaptersRegistered = true;
}

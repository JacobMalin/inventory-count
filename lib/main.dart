import 'package:device_preview/device_preview.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'companion/companion_app.dart';
import 'companion/companion_setup.dart';
import 'main/hive_error_page.dart';
import 'main/main_app.dart';
import 'main/models/data/inventory_models.dart';

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
      isToolbarVisible: false,
      builder: (context) => hiveError != null
          ? HiveErrorPage(errorMessage: hiveError)
          : const MainApp(),
    ),
  );
}

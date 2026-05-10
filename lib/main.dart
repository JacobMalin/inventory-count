import 'dart:io';

import 'package:device_preview/device_preview.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'companion/companion_setup.dart';
import 'companion_app.dart';
import 'main/hive_error_page.dart';
import 'main/models/data/inventory_models.dart';
import 'main_app.dart';

void main() async {
  // Read DISABLE_SYNC flag from environment
  // ignore: do_not_use_environment
  const disableSync = String.fromEnvironment('DISABLE_SYNC') == 'true';

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

    final ByteData data = await PlatformAssetBundle().load(
      'assets/Sectigo Public Server Authentication CA DV E36.crt',
    );
    SecurityContext.defaultContext.setTrustedCertificatesBytes(
      data.buffer.asUint8List(),
    );

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
      enabled: !kReleaseMode && Platform.isWindows,
      isToolbarVisible: false,
      builder: (context) => hiveError != null
          ? HiveErrorPage(errorMessage: hiveError)
          // False positive
          // ignore: avoid_redundant_argument_values
          : const MainApp(disableSync: disableSync),
    ),
  );
}

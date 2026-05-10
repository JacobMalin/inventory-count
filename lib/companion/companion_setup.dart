import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:win32/win32.dart';
import 'package:window_manager/window_manager.dart';

import 'window_model.dart';

const minSize = Size(450, 350);

Future<void> companionHiveSetup() async {
  await Hive.initFlutter('Inventory Count');

  await Hive.openBox('window');
}

Future<void> windowSetup() async {
  await windowManager.ensureInitialized();

  final windowModel = WindowModel();

  final Offset? startPosition = windowModel.position;
  final Size? startSize = windowModel.size;
  final bool? startIsMaximized = windowModel.isMaximized;

  final PackageInfo packageInfo = await PackageInfo.fromPlatform();
  final String version = packageInfo.version;

  final windowOptions = WindowOptions(
    title: 'Inventory Count v$version',
    minimumSize: minSize,
    size: startSize ?? minSize,
  );
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    if (startPosition != null) {
      if (startPosition.dx > 2800) {
        await windowManager.setAlignment(Alignment.center);
      } else {
        await windowManager.setPosition(startPosition);
      }
    }

    if (startIsMaximized != null && startIsMaximized) {
      await windowManager.maximize();
    }

    // Check if window has landed offscreen
    if (!isWindowOnValidMonitor()) {
      await windowManager.setPosition(const Offset(10, 10));
    }

    await WindowModel.refocusWindow();
  });
}

bool isWindowOnValidMonitor() {
  final HWND hwnd = GetForegroundWindow();
  if (hwnd.isNull) return false;

  final HMONITOR monitor = MonitorFromWindow(hwnd, MONITOR_DEFAULTTONULL);
  return !monitor.isNull;
}

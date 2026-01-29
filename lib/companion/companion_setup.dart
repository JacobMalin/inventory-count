import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:inventory_count/companion/window_model.dart';
import 'package:win32/win32.dart';
import 'package:window_manager/window_manager.dart';

const minSize = Size(450, 250);

Future<void> companionHiveSetup() async {
  await Hive.initFlutter('inventory_count');

  await Hive.openBox('window');
}

Future<void> windowSetup() async {
  await windowManager.ensureInitialized();

  final Offset? startPosition = WindowModel.position;
  final Size? startSize = WindowModel.size;
  final bool? startIsMaximized = WindowModel.isMaximized;

  final windowOptions = WindowOptions(
    title: 'Inventory Count',
    minimumSize: minSize,
    size: startSize ?? minSize,
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    if (startPosition != null) windowManager.setPosition(startPosition);

    if (startIsMaximized != null && startIsMaximized) {
      windowManager.maximize();
    }

    // Check if window has landed offscreen
    if (!isWindowOnValidMonitor()) {
      windowManager.setAlignment(Alignment.center);
    }

    await windowManager.show();
    await windowManager.focus();
  });
}

bool isWindowOnValidMonitor() {
  final int hwnd = GetForegroundWindow();
  if (hwnd == 0) return false;

  final int monitor = MonitorFromWindow(hwnd, MONITOR_DEFAULTTONULL);
  return monitor != 0; // If 0, the window is offscreen
}

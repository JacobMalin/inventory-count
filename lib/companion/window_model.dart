import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:window_manager/window_manager.dart';

class WindowModel {
  factory WindowModel() => _instance;

  WindowModel._();

  static final WindowModel _instance = WindowModel._();

  final Box<dynamic> _box = Hive.box('window');

  bool? get isMaximized => _box.get('isMaximized') as bool?;
  set isMaximized(bool? value) {
    if (value == null) {
      unawaited(_box.delete('isMaximized'));
    } else {
      unawaited(_box.put('isMaximized', value));
    }
  }

  Size? get size {
    final width = _box.get('width') as double?;
    final height = _box.get('height') as double?;
    if (width != null && height != null) {
      return Size(width, height);
    }
    return null;
  }

  set size(Size? value) {
    if (value == null) {
      unawaited(_box.delete('width'));
      unawaited(_box.delete('height'));
    } else {
      unawaited(_box.put('width', value.width));
      unawaited(_box.put('height', value.height));
    }
  }

  Offset? get position {
    final x = _box.get('x') as double?;
    final y = _box.get('y') as double?;
    if (x != null && y != null) {
      return Offset(x, y);
    }
    return null;
  }

  set position(Offset? value) {
    if (value == null) {
      unawaited(_box.delete('x'));
      unawaited(_box.delete('y'));
    } else {
      unawaited(_box.put('x', value.dx));
      unawaited(_box.put('y', value.dy));
    }
  }

  String? get countExcelPath => _box.get('countExcelPath') as String?;
  set countExcelPath(String? value) {
    if (value == null) {
      unawaited(_box.delete('countExcelPath'));
    } else {
      unawaited(_box.put('countExcelPath', value));
    }
  }

  static Future<void> refocusWindow() async {
    await windowManager.show();
    await windowManager.setAlwaysOnTop(true);
    await windowManager.setAlwaysOnTop(false);
    await windowManager.focus();
  }
}

class WindowSetupWatcher extends StatefulWidget {
  /// A widget that watches the window for changes and saves them to the
  /// settings.
  const WindowSetupWatcher(Widget child, {super.key}) : _child = child;

  final Widget _child;

  @override
  State<WindowSetupWatcher> createState() => _WindowSetupWatcherState();
}

class _WindowSetupWatcherState extends State<WindowSetupWatcher>
    with WindowListener {
  final _windowModel = WindowModel();

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget._child;

  @override
  Future<void> onWindowMoved([int? windowId]) async {
    _windowModel.position = await windowManager.getPosition();
    _windowModel.size = await windowManager.getSize();
  }

  @override
  Future<void> onWindowResized([int? windowId]) async {
    _windowModel.size = await windowManager.getSize();
    _windowModel.size = await windowManager.getSize();
  }

  @override
  void onWindowFocus([int? windowId]) {
    // Make sure to call once.
    setState(() {});
  }

  @override
  void onWindowMaximize([int? windowId]) {
    _windowModel.isMaximized = true;
  }

  @override
  void onWindowUnmaximize([int? windowId]) {
    _windowModel.isMaximized = false;
  }
}

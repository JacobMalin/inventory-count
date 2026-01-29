import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:window_manager/window_manager.dart';

class WindowModel {
  static final _box = Hive.box('window');

  static bool? get isMaximized => _box.get('isMaximized') as bool?;
  static set isMaximized(bool? value) {
    if (value == null) {
      _box.delete('isMaximized');
    } else {
      _box.put('isMaximized', value);
    }
  }

  static Size? get size {
    final width = _box.get('width') as double?;
    final height = _box.get('height') as double?;
    if (width != null && height != null) {
      return Size(width, height);
    }
    return null;
  }

  static set size(Size? value) {
    if (value == null) {
      _box.delete('width');
      _box.delete('height');
    } else {
      _box.put('width', value.width);
      _box.put('height', value.height);
    }
  }

  static Offset? get position {
    final x = _box.get('x') as double?;
    final y = _box.get('y') as double?;
    if (x != null && y != null) {
      return Offset(x, y);
    }
    return null;
  }

  static set position(Offset? value) {
    if (value == null) {
      _box.delete('x');
      _box.delete('y');
    } else {
      _box.put('x', value.dx);
      _box.put('y', value.dy);
    }
  }

  static String? get countExcelPath => _box.get('countExcelPath') as String?;
  static set countExcelPath(String? value) {
    if (value == null) {
      _box.delete('countExcelPath');
    } else {
      _box.put('countExcelPath', value);
    }
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
    WindowModel.position = await windowManager.getPosition();
    WindowModel.size = await windowManager.getSize();
  }

  @override
  Future<void> onWindowResized([int? windowId]) async {
    WindowModel.size = await windowManager.getSize();
  }

  @override
  void onWindowFocus([int? windowId]) {
    // Make sure to call once.
    setState(() {});
  }

  @override
  void onWindowMaximize([int? windowId]) {
    WindowModel.isMaximized = true;
  }

  @override
  void onWindowUnmaximize([int? windowId]) {
    WindowModel.isMaximized = false;
  }
}

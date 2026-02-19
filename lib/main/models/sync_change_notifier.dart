import 'dart:async';

import 'package:flutter/foundation.dart';

import '../repositories/sync_runtime.dart';

abstract class SyncChangeNotifier extends ChangeNotifier {
  SyncChangeNotifier({SyncRuntime? syncRuntime})
    : _syncRuntime = syncRuntime ?? SyncRuntime();

  final SyncRuntime _syncRuntime;

  void initializeSync({
    required Future<void> Function() fetchInitial,
    required Future<void> Function() listenForChanges,
  }) {
    unawaited(() async {
      await fetchInitial();
      await listenForChanges();
    }());
  }

  void registerReconnectCallback(Future<void> Function() callback) {
    _syncRuntime.registerReconnectCallback(this, callback);
  }

  Future<void> unregisterReconnectCallbacks() {
    return _syncRuntime.unregisterReconnectCallback(this);
  }

  @protected
  void logSyncError(String message, Object error) {
    SyncRuntime.logError(message, error);
  }
}

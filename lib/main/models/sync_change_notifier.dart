import 'dart:async';

import 'package:flutter/foundation.dart';

import '../repositories/sync_runtime.dart';

abstract class LocalSyncChangeNotifier extends ChangeNotifier {
  LocalSyncChangeNotifier({this.disableSync = false});

  final bool disableSync;

  void initializeSync({
    required Future<void> Function() fetchInitial,
    required Future<void> Function() listenForChanges,
  }) {
    if (disableSync) return;
    unawaited(() async {
      await fetchInitial();
      await listenForChanges();
    }());
  }

  void registerReconnectCallback(Future<void> Function() callback) {
    SyncRuntime.registerReconnectCallback(this, callback);
  }

  Future<void> unregisterReconnectCallbacks() {
    return SyncRuntime.unregisterReconnectCallback(this);
  }

  @protected
  void logSyncError(String message, Object error) {
    SyncRuntime.logError(message, error);
  }
}

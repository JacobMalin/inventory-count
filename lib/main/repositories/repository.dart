import 'dart:async';

import 'sync_runtime.dart';

class SyncRepository {
  SyncRepository({this.disableSync = false});

  final bool disableSync;

  void initializeSync({
    required Function fetchInitial,
    required Function listenForChanges,
  }) {
    if (disableSync) return;
    unawaited(() async {
      await fetchInitial();
      await listenForChanges();
    }());
  }

  Future<void> registerReconnectCallback(
    Future<void> Function() callback,
  ) async {
    await SyncRuntime.registerReconnectCallback(this, callback);
  }

  Future<void> unregisterReconnectCallbacks() {
    return SyncRuntime.unregisterReconnectCallback(this);
  }

  void logSyncError(String message, Object error) {
    SyncRuntime.logError(message, error);
  }
}

class LocalRepository {}

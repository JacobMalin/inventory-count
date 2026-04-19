import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:semaphore/semaphore.dart';

class SyncRuntime {
  static final Stream<InternetConnectionStatus> onStatusChange =
      InternetConnectionChecker.instance.onStatusChange;

  static StreamSubscription<InternetConnectionStatus>? _sharedSubscription;
  static final Map<Object, Future<void> Function()> _reconnectCallbacks = {};
  static final LocalSemaphore callbacksLock = LocalSemaphore(1);

  static void logError(String message, Object error) {
    if (kDebugMode) print('$message: $error');
  }

  static Future<void> registerReconnectCallback(
    Object owner,
    Future<void> Function() onConnected,
  ) async {
    try {
      await callbacksLock.acquire();
      _reconnectCallbacks[owner] = onConnected;
    } finally {
      callbacksLock.release();
    }

    // Start listening if this is the first callback
    if (_sharedSubscription == null && _reconnectCallbacks.isNotEmpty) {
      _startListening();
    }
  }

  static Future<void> unregisterReconnectCallback(Object owner) async {
    try {
      await callbacksLock.acquire();
      _reconnectCallbacks.remove(owner);
    } finally {
      callbacksLock.release();
    }

    // Stop listening if no more callbacks
    if (_reconnectCallbacks.isEmpty) {
      await _stopListening();
    }
  }

  static void _startListening() {
    _sharedSubscription ??= onStatusChange.listen(
      (status) async {
        if (status != InternetConnectionStatus.connected) return;

        // Call all registered callbacks
        try {
          await callbacksLock.acquire();
          for (final Future<void> Function() callback
              in _reconnectCallbacks.values) {
            try {
              await callback();
            } on Exception catch (e) {
              logError('Error in reconnect callback', e);
            }
          }
        } finally {
          callbacksLock.release();
        }
      },
      onError: (e) {
        logError('Connectivity listener error', e);
      },
    );
  }

  static Future<void> _stopListening() async {
    await _sharedSubscription?.cancel();
    _sharedSubscription = null;
  }
}

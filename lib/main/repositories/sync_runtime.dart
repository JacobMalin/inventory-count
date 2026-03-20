import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

class SyncRuntime {
  static final Stream<InternetConnectionStatus> onStatusChange =
      InternetConnectionChecker.instance.onStatusChange;

  static StreamSubscription<InternetConnectionStatus>? _sharedSubscription;
  static final Map<Object, Future<void> Function()> _reconnectCallbacks = {};

  static void logError(String message, Object error) {
    if (kDebugMode) print('$message: $error');
  }

  static void registerReconnectCallback(
    Object owner,
    Future<void> Function() onConnected,
  ) {
    _reconnectCallbacks[owner] = onConnected;

    // Start listening if this is the first callback
    if (_sharedSubscription == null && _reconnectCallbacks.isNotEmpty) {
      _startListening();
    }
  }

  static Future<void> unregisterReconnectCallback(Object owner) async {
    _reconnectCallbacks.remove(owner);

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
        for (final Future<void> Function() callback
            in _reconnectCallbacks.values) {
          try {
            await callback();
          } on Exception catch (e) {
            logError('Error in reconnect callback', e);
          }
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

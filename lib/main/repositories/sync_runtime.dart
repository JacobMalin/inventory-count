import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

class SyncRuntime {
  factory SyncRuntime() => _instance;

  SyncRuntime._({
    Stream<InternetConnectionStatus>? statusChanges,
    void Function(String message, Object error)? errorLogger,
  }) : _statusChanges =
           statusChanges ?? InternetConnectionChecker.instance.onStatusChange,
       _errorLogger = errorLogger ?? SyncRuntime.logError;

  @visibleForTesting
  factory SyncRuntime.forTest({
    required Stream<InternetConnectionStatus> statusChanges,
    void Function(String message, Object error)? errorLogger,
  }) {
    return SyncRuntime._(
      statusChanges: statusChanges,
      errorLogger: errorLogger,
    );
  }

  static final SyncRuntime _instance = SyncRuntime._();

  final Stream<InternetConnectionStatus> _statusChanges;
  final void Function(String message, Object error) _errorLogger;

  StreamSubscription<InternetConnectionStatus>? _sharedSubscription;
  final Map<Object, Future<void> Function()> _reconnectCallbacks = {};

  static void logError(String message, Object error) {
    if (kDebugMode) {
      print('$message: $error');
    }
  }

  void registerReconnectCallback(
    Object owner,
    Future<void> Function() onConnected,
  ) {
    _reconnectCallbacks[owner] = onConnected;

    // Start listening if this is the first callback
    if (_sharedSubscription == null && _reconnectCallbacks.isNotEmpty) {
      _startListening();
    }
  }

  Future<void> unregisterReconnectCallback(Object owner) async {
    _reconnectCallbacks.remove(owner);

    // Stop listening if no more callbacks
    if (_reconnectCallbacks.isEmpty) {
      await _stopListening();
    }
  }

  void _startListening() {
    _sharedSubscription ??= _statusChanges.listen(
      (status) async {
        if (status != InternetConnectionStatus.connected) return;

        // Call all registered callbacks
        for (final Future<void> Function() callback
            in _reconnectCallbacks.values) {
          try {
            await callback();
          } on Exception catch (e) {
            _errorLogger('Error in reconnect callback', e);
          }
        }
      },
      onError: (e) {
        _errorLogger('Connectivity listener error', e);
      },
    );
  }

  Future<void> _stopListening() async {
    await _sharedSubscription?.cancel();
    _sharedSubscription = null;
  }
}

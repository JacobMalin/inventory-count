import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:inventory_count/main/repositories/sync_runtime.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SyncRuntime', () {
    test('factory returns singleton instance', () {
      final a = SyncRuntime();
      final b = SyncRuntime();

      expect(identical(a, b), isTrue);
    });

    test('register and unregister callback completes', () async {
      final controller = StreamController<InternetConnectionStatus>();
      final runtime = SyncRuntime.forTest(statusChanges: controller.stream);
      final owner = Object();

      runtime.registerReconnectCallback(owner, () async {});
      await runtime.unregisterReconnectCallback(owner);
      await controller.close();
    });

    test('runs callback only when connection becomes connected', () async {
      final controller = StreamController<InternetConnectionStatus>();
      final runtime = SyncRuntime.forTest(statusChanges: controller.stream);
      var invocationCount = 0;

      runtime.registerReconnectCallback(Object(), () async {
        invocationCount += 1;
      });

      controller.add(InternetConnectionStatus.disconnected);
      await Future<void>.delayed(Duration.zero);
      controller.add(InternetConnectionStatus.connected);
      await Future<void>.delayed(Duration.zero);

      expect(invocationCount, 1);
      await controller.close();
    });

    test('logs callback exceptions', () async {
      final controller = StreamController<InternetConnectionStatus>();
      final logs = <String>[];

      SyncRuntime.forTest(
        statusChanges: controller.stream,
        errorLogger: (message, error) => logs.add('$message:$error'),
      ).registerReconnectCallback(Object(), () {
        throw Exception('callback failed');
      });

      controller.add(InternetConnectionStatus.connected);
      await Future<void>.delayed(Duration.zero);

      expect(logs.single.contains('Error in reconnect callback'), isTrue);
      await controller.close();
    });

    test('logs stream listener errors', () async {
      final controller = StreamController<InternetConnectionStatus>();
      final logs = <String>[];
      SyncRuntime.forTest(
        statusChanges: controller.stream,
        errorLogger: (message, error) => logs.add('$message:$error'),
      ).registerReconnectCallback(Object(), () async {});
      controller.addError(Exception('stream failed'));
      await Future<void>.delayed(Duration.zero);

      expect(logs.single.contains('Connectivity listener error'), isTrue);
      await controller.close();
    });

    test('stops receiving events after last owner is unregistered', () async {
      final controller = StreamController<InternetConnectionStatus>();
      final runtime = SyncRuntime.forTest(statusChanges: controller.stream);
      final owner = Object();
      var invocationCount = 0;

      runtime.registerReconnectCallback(owner, () async {
        invocationCount += 1;
      });

      await runtime.unregisterReconnectCallback(owner);

      controller.add(InternetConnectionStatus.connected);
      await Future<void>.delayed(Duration.zero);

      expect(invocationCount, 0);
      await controller.close();
    });

    test('logError can be called', () {
      SyncRuntime.logError('test error', Exception('boom'));
    });
  });
}

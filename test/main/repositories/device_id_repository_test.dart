import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_count/main/repositories/device_id_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const mockDeviceId = 'device-123';

  const channel = MethodChannel('flutter_udid');

  group('FlutterUdidDeviceIdRepository', () {
    test('factory returns singleton instance', () {
      final a = FlutterUdidDeviceIdRepository();
      final b = FlutterUdidDeviceIdRepository();

      expect(identical(a, b), isTrue);
    });

    test('caches device id after first fetch', () async {
      var callCount = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (methodCall) async {
            callCount += 1;
            return mockDeviceId;
          });

      final repository = FlutterUdidDeviceIdRepository();

      final String first = await repository.getDeviceId();
      final String second = await repository.getDeviceId();

      expect(first, mockDeviceId);
      expect(second, mockDeviceId);
      expect(callCount, 1);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
  });
}

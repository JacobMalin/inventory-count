import 'package:flutter_udid/flutter_udid.dart';

class DeviceId {
  factory DeviceId() => _instance;

  DeviceId._();

  static final DeviceId _instance = DeviceId._();

  static String? _cached;

  static Future<String> getDeviceId() async {
    final String? value = _cached;
    if (value != null) {
      return value;
    }

    final String udid = await FlutterUdid.udid;
    _cached = udid;
    return udid;
  }
}

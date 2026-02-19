import 'package:flutter_udid/flutter_udid.dart';

abstract class DeviceIdRepository {
  Future<String> getDeviceId();
}

class FlutterUdidDeviceIdRepository implements DeviceIdRepository {
  factory FlutterUdidDeviceIdRepository() => _instance;

  FlutterUdidDeviceIdRepository._();

  static final FlutterUdidDeviceIdRepository _instance =
      FlutterUdidDeviceIdRepository._();

  String? _cached;

  @override
  Future<String> getDeviceId() async {
    final String? value = _cached;
    if (value != null) {
      return value;
    }

    final String udid = await FlutterUdid.udid;
    _cached = udid;
    return udid;
  }
}

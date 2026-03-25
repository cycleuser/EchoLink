import 'package:flutter_test/flutter_test.dart';
import 'package:echolink/domain/models/models.dart';

void main() {
  group('Device', () {
    test('should create device with default values', () {
      final device = Device(
        id: 'test-id',
        name: 'Test Device',
      );

      expect(device.id, 'test-id');
      expect(device.name, 'Test Device');
      expect(device.platform, DevicePlatform.unknown);
      expect(device.status, DeviceStatus.disconnected);
      expect(device.isConnected, false);
    });

    test('should correctly identify platform', () {
      final androidDevice = Device(
        id: 'android-id',
        name: 'Android',
        platform: DevicePlatform.android,
      );

      final iosDevice = Device(
        id: 'ios-id',
        name: 'iOS',
        platform: DevicePlatform.ios,
      );

      expect(androidDevice.isAndroid, true);
      expect(androidDevice.isIOS, false);
      expect(iosDevice.isIOS, true);
      expect(iosDevice.isAndroid, false);
    });

    test('should serialize to JSON and back', () {
      final device = Device(
        id: 'test-id',
        name: 'Test Device',
        platform: DevicePlatform.android,
        status: DeviceStatus.connected,
        ipAddress: '192.168.1.1',
        port: 50505,
      );

      final json = device.toJson();
      final fromJson = Device.fromJson(json);

      expect(fromJson.id, device.id);
      expect(fromJson.name, device.name);
      expect(fromJson.platform, device.platform);
      expect(fromJson.status, device.status);
      expect(fromJson.ipAddress, device.ipAddress);
      expect(fromJson.port, device.port);
    });

    test('should create copy with updated values', () {
      final device = Device(
        id: 'test-id',
        name: 'Test Device',
      );

      final updated = device.copyWith(
        status: DeviceStatus.connected,
        ipAddress: '192.168.1.1',
      );

      expect(updated.status, DeviceStatus.connected);
      expect(updated.ipAddress, '192.168.1.1');
      expect(updated.id, device.id);
      expect(updated.name, device.name);
    });
  });
}
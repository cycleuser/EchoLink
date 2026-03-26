import 'package:flutter_test/flutter_test.dart';
import 'package:echolink/infrastructure/network/cross_platform_network_service.dart';
import 'package:echolink/domain/models/models.dart';

void main() {
  group('CrossPlatformNetworkService', () {
    test('should be a singleton', () {
      final service1 = CrossPlatformNetworkService();
      final service2 = CrossPlatformNetworkService();
      
      expect(identical(service1, service2), true);
    });

    test('should have correct discovery port', () {
      expect(CrossPlatformNetworkService.discoveryPort, 50505);
    });

    test('should have correct base data port', () {
      expect(CrossPlatformNetworkService.baseDataPort, 50506);
    });

    test('should have correct discovery interval', () {
      expect(CrossPlatformNetworkService.discoveryInterval, const Duration(seconds: 2));
    });

    test('should have correct device timeout', () {
      expect(CrossPlatformNetworkService.deviceTimeout, const Duration(seconds: 20));
    });

    test('should not be initialized by default', () {
      final service = CrossPlatformNetworkService();
      expect(service.isInitialized, false);
    });

    test('should not be discovering by default', () {
      final service = CrossPlatformNetworkService();
      expect(service.isDiscovering, false);
    });

    test('should have empty devices list by default', () {
      final service = CrossPlatformNetworkService();
      expect(service.devices, isEmpty);
    });

    test('should have null connected device by default', () {
      final service = CrossPlatformNetworkService();
      expect(service.currentConnectedDevice, isNull);
    });

    test('should expose streams', () {
      final service = CrossPlatformNetworkService();
      
      expect(service.deviceDiscovered, isA<Stream<Device>>());
      expect(service.messageReceived, isA<Stream<Message>>());
      expect(service.connectionState, isA<Stream<EchoLinkConnectionState>>());
      expect(service.connectedDeviceStream, isA<Stream<Device?>>());
    });
  });
}
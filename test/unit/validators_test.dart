import 'package:flutter_test/flutter_test.dart';
import 'package:echolink/core/utils/validators.dart';

void main() {
  group('Validators', () {
    group('isValidDeviceName', () {
      test('should accept valid device names', () {
        expect(Validators.isValidDeviceName('My Device'), true);
        expect(Validators.isValidDeviceName('Device-123'), true);
        expect(Validators.isValidDeviceName('Test_Device'), true);
      });

      test('should reject invalid device names', () {
        expect(Validators.isValidDeviceName(null), false);
        expect(Validators.isValidDeviceName(''), false);
        expect(Validators.isValidDeviceName('A' * 33), false);
        expect(Validators.isValidDeviceName('Device@123'), false);
      });
    });

    group('isValidMessageContent', () {
      test('should accept valid message content', () {
        expect(Validators.isValidMessageContent('Hello, World!'), true);
        expect(Validators.isValidMessageContent('A' * 10000), true);
      });

      test('should reject invalid message content', () {
        expect(Validators.isValidMessageContent(null), false);
        expect(Validators.isValidMessageContent(''), false);
        expect(Validators.isValidMessageContent('A' * 10001), false);
      });
    });

    group('isValidIpAddress', () {
      test('should accept valid IP addresses', () {
        expect(Validators.isValidIpAddress('192.168.1.1'), true);
        expect(Validators.isValidIpAddress('127.0.0.1'), true);
        expect(Validators.isValidIpAddress('255.255.255.255'), true);
      });

      test('should reject invalid IP addresses', () {
        expect(Validators.isValidIpAddress(null), false);
        expect(Validators.isValidIpAddress(''), false);
        expect(Validators.isValidIpAddress('192.168.1'), false);
        expect(Validators.isValidIpAddress('192.168.1.256'), false);
        expect(Validators.isValidIpAddress('abc.def.ghi.jkl'), false);
      });
    });

    group('isValidPort', () {
      test('should accept valid ports', () {
        expect(Validators.isValidPort(80), true);
        expect(Validators.isValidPort(443), true);
        expect(Validators.isValidPort(50505), true);
        expect(Validators.isValidPort(65535), true);
      });

      test('should reject invalid ports', () {
        expect(Validators.isValidPort(null), false);
        expect(Validators.isValidPort(0), false);
        expect(Validators.isValidPort(-1), false);
        expect(Validators.isValidPort(65536), false);
      });
    });

    group('isValidFileSize', () {
      test('should accept valid file sizes', () {
        expect(Validators.isValidFileSize(1), true);
        expect(Validators.isValidFileSize(1024 * 1024), true);
        expect(Validators.isValidFileSize(1024 * 1024 * 1024), true);
      });

      test('should reject invalid file sizes', () {
        expect(Validators.isValidFileSize(0), false);
        expect(Validators.isValidFileSize(-1), false);
        expect(Validators.isValidFileSize(1024 * 1024 * 1024 + 1), false);
      });
    });
  });
}
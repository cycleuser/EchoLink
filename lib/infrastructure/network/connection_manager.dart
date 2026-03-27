import 'dart:async';
import 'dart:io';
import '../../domain/models/models.dart';
import '../../core/result.dart';
import '../../core/utils/logger.dart';
import 'cross_platform_network_service.dart';

abstract class ConnectionManager {
  Stream<Device> get discoveredDevices;
  Stream<EchoLinkConnectionState> get connectionState;
  Stream<Message> get incomingMessages;
  Stream<String> get debugLog;

  Future<Result<void>> initialize();
  Future<Result<void>> startDiscovery();
  Future<Result<void>> stopDiscovery();
  Future<Result<void>> connect(Device device);
  Future<Result<void>> disconnect([String? deviceId]);
  Future<Result<void>> sendMessage(Message message);
  Future<Result<void>> sendFile(FileTransfer transfer);
  Future<Device> getCurrentDevice();
  Future<void> dispose();
}

class ConnectionManagerImpl implements ConnectionManager {
  final CrossPlatformNetworkService _networkService;

  ConnectionManagerImpl() : _networkService = CrossPlatformNetworkService();

  @override
  Stream<Device> get discoveredDevices => _networkService.deviceDiscovered;

  @override
  Stream<EchoLinkConnectionState> get connectionState => _networkService.connectionState;

  @override
  Stream<Message> get incomingMessages => _networkService.messageReceived;

  @override
  Stream<String> get debugLog => _networkService.debugLog;

  @override
  Future<Result<void>> initialize() async {
    try {
      AppLogger.info('Initializing connection manager');
      
      final deviceName = await _generateDeviceName();
      return _networkService.initialize(deviceName);
    } catch (e) {
      AppLogger.error('Failed to initialize connection manager', e);
      return Failure(e.toString());
    }
  }

  @override
  Future<Result<void>> startDiscovery() => _networkService.startDiscovery();

  @override
  Future<Result<void>> stopDiscovery() => _networkService.stopDiscovery();

  @override
  Future<Result<void>> connect(Device device) => _networkService.connect(device);

  @override
  Future<Result<void>> disconnect([String? deviceId]) => _networkService.disconnect(deviceId);

  @override
  Future<Result<void>> sendMessage(Message message) async {
    return _networkService.sendMessage(message.content, message.receiverId);
  }

  @override
  Future<Result<void>> sendFile(FileTransfer transfer) async {
    return _networkService.sendMessage(
      '[FILE] ${transfer.fileName} (${transfer.fileSize} bytes)',
      transfer.receiverId,
    );
  }

  @override
  Future<Device> getCurrentDevice() async {
    return _networkService.getCurrentDevice();
  }

  @override
  Future<void> dispose() async {
    await _networkService.dispose();
  }

  Future<String> _generateDeviceName() async {
    String platform = 'Device';
    
    if (Platform.isAndroid) {
      platform = 'Android';
    } else if (Platform.isIOS) {
      platform = 'iOS';
    } else if (Platform.isMacOS) {
      platform = 'macOS';
    }

    final suffix = DateTime.now().millisecondsSinceEpoch % 10000;
    return 'EchoLink-$platform-$suffix';
  }
}
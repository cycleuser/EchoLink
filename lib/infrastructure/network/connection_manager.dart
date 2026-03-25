import 'dart:async';
import 'dart:io';
import '../../domain/models/models.dart';
import '../../domain/repositories/repositories.dart';
import '../../core/result.dart';
import '../../core/utils/logger.dart';

abstract class ConnectionManager {
  Stream<Device> get discoveredDevices;
  Stream<ConnectionState> get connectionState;
  Stream<Message> get incomingMessages;
  Stream<FileTransfer> get fileTransfers;

  Future<Result<void>> initialize();
  Future<Result<void>> startDiscovery();
  Future<Result<void>> stopDiscovery();
  Future<Result<void>> connect(Device device);
  Future<Result<void>> disconnect();
  Future<Result<void>> sendMessage(Message message);
  Future<Result<void>> sendFile(FileTransfer transfer);
  Future<Device> getCurrentDevice();
  Future<void> dispose();
}

class ConnectionManagerImpl implements ConnectionManager {
  final _discoveredDevicesController = StreamController<Device>.broadcast();
  final _connectionStateController = StreamController<ConnectionState>.broadcast();
  final _incomingMessagesController = StreamController<Message>.broadcast();
  final _fileTransfersController = StreamController<FileTransfer>.broadcast();

  Device? _currentDevice;
  Device? _connectedDevice;
  ConnectionState _currentState = ConnectionState.disconnected;
  bool _isDiscovering = false;

  @override
  Stream<Device> get discoveredDevices => _discoveredDevicesController.stream;

  @override
  Stream<ConnectionState> get connectionState => _connectionStateController.stream;

  @override
  Stream<Message> get incomingMessages => _incomingMessagesController.stream;

  @override
  Stream<FileTransfer> get fileTransfers => _fileTransfersController.stream;

  @override
  Future<Result<void>> initialize() async {
    try {
      AppLogger.info('Initializing connection manager');
      
      _currentDevice = await _detectCurrentDevice();
      
      AppLogger.info('Current device: ${_currentDevice?.name}');
      return const Success(null);
    } catch (e) {
      AppLogger.error('Failed to initialize connection manager', e);
      return Failure(e.toString());
    }
  }

  @override
  Future<Result<void>> startDiscovery() async {
    if (_isDiscovering) {
      return const Success(null);
    }

    try {
      AppLogger.info('Starting device discovery');
      _isDiscovering = true;
      _updateState(ConnectionState.discovering);
      
      return const Success(null);
    } catch (e) {
      AppLogger.error('Failed to start discovery', e);
      return Failure(e.toString());
    }
  }

  @override
  Future<Result<void>> stopDiscovery() async {
    if (!_isDiscovering) {
      return const Success(null);
    }

    try {
      AppLogger.info('Stopping device discovery');
      _isDiscovering = false;
      
      if (_currentState == ConnectionState.discovering) {
        _updateState(ConnectionState.disconnected);
      }
      
      return const Success(null);
    } catch (e) {
      AppLogger.error('Failed to stop discovery', e);
      return Failure(e.toString());
    }
  }

  @override
  Future<Result<void>> connect(Device device) async {
    try {
      AppLogger.info('Connecting to device: ${device.name}');
      _updateState(ConnectionState.connecting);

      await Future.delayed(const Duration(seconds: 2));

      _connectedDevice = device.copyWith(status: DeviceStatus.connected);
      _updateState(ConnectionState.connected);

      AppLogger.info('Connected to: ${device.name}');
      return const Success(null);
    } on TimeoutException {
      _updateState(ConnectionState.error);
      return Failure('Connection timeout');
    } catch (e) {
      AppLogger.error('Failed to connect', e);
      _updateState(ConnectionState.error);
      return Failure(e.toString());
    }
  }

  @override
  Future<Result<void>> disconnect() async {
    try {
      AppLogger.info('Disconnecting from device');
      
      _connectedDevice = null;
      _updateState(ConnectionState.disconnected);
      
      return const Success(null);
    } catch (e) {
      AppLogger.error('Failed to disconnect', e);
      return Failure(e.toString());
    }
  }

  @override
  Future<Result<void>> sendMessage(Message message) async {
    if (_connectedDevice == null) {
      return Failure('No device connected');
    }

    try {
      AppLogger.debug('Sending message: ${message.id}');
      
      return const Success(null);
    } catch (e) {
      AppLogger.error('Failed to send message', e);
      return Failure(e.toString());
    }
  }

  @override
  Future<Result<void>> sendFile(FileTransfer transfer) async {
    if (_connectedDevice == null) {
      return Failure('No device connected');
    }

    try {
      AppLogger.debug('Sending file: ${transfer.fileName}');
      
      return const Success(null);
    } catch (e) {
      AppLogger.error('Failed to send file', e);
      return Failure(e.toString());
    }
  }

  @override
  Future<Device> getCurrentDevice() async {
    if (_currentDevice == null) {
      _currentDevice = await _detectCurrentDevice();
    }
    return _currentDevice!;
  }

  @override
  Future<void> dispose() async {
    await _discoveredDevicesController.close();
    await _connectionStateController.close();
    await _incomingMessagesController.close();
    await _fileTransfersController.close();
  }

  void _updateState(ConnectionState newState) {
    _currentState = newState;
    _connectionStateController.add(newState);
  }

  Future<Device> _detectCurrentDevice() async {
    String deviceName = 'EchoLink Device';
    
    if (Platform.isAndroid) {
      deviceName = 'Android Device';
    } else if (Platform.isIOS) {
      deviceName = 'iOS Device';
    }

    return Device(
      id: _generateDeviceId(),
      name: deviceName,
      platform: Platform.isAndroid
          ? DevicePlatform.android
          : Platform.isIOS
              ? DevicePlatform.ios
              : DevicePlatform.unknown,
      status: DeviceStatus.connected,
    );
  }

  String _generateDeviceId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  void _onDeviceDiscovered(Device device) {
    _discoveredDevicesController.add(device);
  }

  void _onMessageReceived(Message message) {
    _incomingMessagesController.add(message);
  }

  void _onFileTransferUpdate(FileTransfer transfer) {
    _fileTransfersController.add(transfer);
  }
}
import 'dart:async';
import 'dart:io';
import '../../../../domain/models/models.dart';
import '../../../../core/result.dart';
import '../../../../core/exceptions.dart';
import '../../../../core/constants.dart';
import '../../../../core/utils/logger.dart';

class WifiDirectService {
  static final WifiDirectService _instance = WifiDirectService._internal();
  factory WifiDirectService() => _instance;
  WifiDirectService._internal();

  final _peersController = StreamController<List<Device>>.broadcast();
  final _connectionController = StreamController<Device?>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  bool _isInitialized = false;
  bool _isDiscovering = false;
  Device? _connectedDevice;
  List<Device> _discoveredPeers = [];

  Stream<List<Device>> get peers => _peersController.stream;
  Stream<Device?> get connection => _connectionController.stream;
  Stream<String> get errors => _errorController.stream;

  bool get isInitialized => _isInitialized;
  bool get isDiscovering => _isDiscovering;
  Device? get connectedDevice => _connectedDevice;

  Future<Result<void>> initialize() async {
    if (!Platform.isAndroid) {
      return Failure('Wi-Fi Direct is only available on Android');
    }

    try {
      AppLogger.info('Initializing Wi-Fi Direct service');
      
      _isInitialized = true;
      return const Success(null);
    } catch (e) {
      AppLogger.error('Failed to initialize Wi-Fi Direct', e);
      return Failure(e.toString());
    }
  }

  Future<Result<void>> startDiscovery() async {
    if (!_isInitialized) {
      return Failure('Service not initialized');
    }

    if (_isDiscovering) {
      return const Success(null);
    }

    try {
      AppLogger.info('Starting Wi-Fi P2P discovery');
      _isDiscovering = true;
      
      _peersController.add([]);

      return const Success(null);
    } catch (e) {
      AppLogger.error('Failed to start discovery', e);
      return Failure(e.toString());
    }
  }

  Future<Result<void>> stopDiscovery() async {
    if (!_isDiscovering) {
      return const Success(null);
    }

    try {
      AppLogger.info('Stopping Wi-Fi P2P discovery');
      _isDiscovering = false;
      
      return const Success(null);
    } catch (e) {
      AppLogger.error('Failed to stop discovery', e);
      return Failure(e.toString());
    }
  }

  Future<Result<void>> connect(Device device) async {
    if (!_isInitialized) {
      return Failure('Service not initialized');
    }

    try {
      AppLogger.info('Connecting to device: ${device.name}');
      
      await Future.delayed(const Duration(seconds: 2));

      _connectedDevice = device.copyWith(
        status: DeviceStatus.connected,
        connectionType: ConnectionType.wifiDirect,
      );
      _connectionController.add(_connectedDevice);

      return const Success(null);
    } on TimeoutException {
      return Failure('Connection timeout');
    } catch (e) {
      AppLogger.error('Failed to connect', e);
      return Failure(e.toString());
    }
  }

  Future<Result<void>> disconnect() async {
    try {
      AppLogger.info('Disconnecting from Wi-Fi P2P');
      
      _connectedDevice = null;
      _connectionController.add(null);
      
      return const Success(null);
    } catch (e) {
      AppLogger.error('Failed to disconnect', e);
      return Failure(e.toString());
    }
  }

  Future<Result<Device>> createGroup({String? groupName}) async {
    if (!_isInitialized) {
      return Failure('Service not initialized');
    }

    try {
      AppLogger.info('Creating Wi-Fi P2P group');
      
      final groupOwner = Device(
        id: _generateDeviceId(),
        name: groupName ?? 'EchoLink Group',
        platform: DevicePlatform.android,
        status: DeviceStatus.connected,
        connectionType: ConnectionType.wifiDirect,
        ipAddress: '192.168.49.1',
        port: AppConstants.defaultPort,
      );

      _connectedDevice = groupOwner;
      _connectionController.add(groupOwner);

      return Success(groupOwner);
    } catch (e) {
      AppLogger.error('Failed to create group', e);
      return Failure(e.toString());
    }
  }

  Future<Result<void>> removeGroup() async {
    try {
      AppLogger.info('Removing Wi-Fi P2P group');
      
      _connectedDevice = null;
      _connectionController.add(null);
      
      return const Success(null);
    } catch (e) {
      AppLogger.error('Failed to remove group', e);
      return Failure(e.toString());
    }
  }

  Future<Result<String?>> getGroupOwnerAddress() async {
    if (_connectedDevice == null) {
      return const Success(null);
    }
    
    return Success(_connectedDevice!.ipAddress);
  }

  void _onPeerDiscovered(Device device) {
    final index = _discoveredPeers.indexWhere((p) => p.id == device.id);
    
    if (index >= 0) {
      _discoveredPeers[index] = device;
    } else {
      _discoveredPeers.add(device);
    }
    
    _peersController.add(List.from(_discoveredPeers));
  }

  void _onPeerLost(String deviceId) {
    _discoveredPeers.removeWhere((p) => p.id == deviceId);
    _peersController.add(List.from(_discoveredPeers));
  }

  String _generateDeviceId() {
    return 'android_${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<void> dispose() async {
    await _peersController.close();
    await _connectionController.close();
    await _errorController.close();
    _isInitialized = false;
    _isDiscovering = false;
  }
}
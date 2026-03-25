import 'dart:async';
import 'dart:io';
import '../../../../domain/models/models.dart';
import '../../../../core/result.dart';
import '../../../../core/constants.dart';
import '../../../../core/utils/logger.dart';

class MultipeerService {
  static final MultipeerService _instance = MultipeerService._internal();
  factory MultipeerService() => _instance;
  MultipeerService._internal();

  final _peersController = StreamController<List<Device>>.broadcast();
  final _connectionController = StreamController<Device?>.broadcast();
  final _dataReceivedController = StreamController<Map<String, dynamic>>.broadcast();

  bool _isInitialized = false;
  bool _isAdvertising = false;
  bool _isBrowsing = false;
  Device? _connectedDevice;
  List<Device> _discoveredPeers = [];
  String _deviceName = 'EchoLink iOS';

  Stream<List<Device>> get peers => _peersController.stream;
  Stream<Device?> get connection => _connectionController.stream;
  Stream<Map<String, dynamic>> get dataReceived => _dataReceivedController.stream;

  bool get isInitialized => _isInitialized;
  bool get isAdvertising => _isAdvertising;
  bool get isBrowsing => _isBrowsing;
  Device? get connectedDevice => _connectedDevice;

  Future<Result<void>> initialize({String? deviceName}) async {
    if (!Platform.isIOS && !Platform.isMacOS) {
      return Failure('Multipeer Connectivity is only available on iOS/macOS');
    }

    try {
      AppLogger.info('Initializing Multipeer Connectivity');
      
      if (deviceName != null) {
        _deviceName = deviceName;
      }
      
      _isInitialized = true;
      return const Success(null);
    } catch (e) {
      AppLogger.error('Failed to initialize Multipeer', e);
      return Failure(e.toString());
    }
  }

  Future<Result<void>> startAdvertising() async {
    if (!_isInitialized) {
      return Failure('Service not initialized');
    }

    if (_isAdvertising) {
      return const Success(null);
    }

    try {
      AppLogger.info('Starting advertising');
      _isAdvertising = true;
      
      return const Success(null);
    } catch (e) {
      AppLogger.error('Failed to start advertising', e);
      return Failure(e.toString());
    }
  }

  Future<Result<void>> stopAdvertising() async {
    if (!_isAdvertising) {
      return const Success(null);
    }

    try {
      AppLogger.info('Stopping advertising');
      _isAdvertising = false;
      
      return const Success(null);
    } catch (e) {
      AppLogger.error('Failed to stop advertising', e);
      return Failure(e.toString());
    }
  }

  Future<Result<void>> startBrowsing() async {
    if (!_isInitialized) {
      return Failure('Service not initialized');
    }

    if (_isBrowsing) {
      return const Success(null);
    }

    try {
      AppLogger.info('Starting browsing for peers');
      _isBrowsing = true;
      _discoveredPeers = [];
      _peersController.add([]);
      
      return const Success(null);
    } catch (e) {
      AppLogger.error('Failed to start browsing', e);
      return Failure(e.toString());
    }
  }

  Future<Result<void>> stopBrowsing() async {
    if (!_isBrowsing) {
      return const Success(null);
    }

    try {
      AppLogger.info('Stopping browsing');
      _isBrowsing = false;
      
      return const Success(null);
    } catch (e) {
      AppLogger.error('Failed to stop browsing', e);
      return Failure(e.toString());
    }
  }

  Future<Result<void>> invitePeer(Device device) async {
    if (!_isInitialized) {
      return Failure('Service not initialized');
    }

    try {
      AppLogger.info('Inviting peer: ${device.name}');
      
      await Future.delayed(const Duration(seconds: 2));

      _connectedDevice = device.copyWith(
        status: DeviceStatus.connected,
        connectionType: ConnectionType.multipeer,
      );
      _connectionController.add(_connectedDevice);

      return const Success(null);
    } catch (e) {
      AppLogger.error('Failed to invite peer', e);
      return Failure(e.toString());
    }
  }

  Future<Result<void>> acceptInvitation() async {
    if (!_isInitialized) {
      return Failure('Service not initialized');
    }

    try {
      AppLogger.info('Accepting invitation');
      
      return const Success(null);
    } catch (e) {
      AppLogger.error('Failed to accept invitation', e);
      return Failure(e.toString());
    }
  }

  Future<Result<void>> disconnect() async {
    try {
      AppLogger.info('Disconnecting from peer');
      
      _connectedDevice = null;
      _connectionController.add(null);
      
      return const Success(null);
    } catch (e) {
      AppLogger.error('Failed to disconnect', e);
      return Failure(e.toString());
    }
  }

  Future<Result<void>> sendData(Map<String, dynamic> data) async {
    if (_connectedDevice == null) {
      return Failure('No device connected');
    }

    try {
      AppLogger.debug('Sending data to peer');
      
      return const Success(null);
    } catch (e) {
      AppLogger.error('Failed to send data', e);
      return Failure(e.toString());
    }
  }

  void _onPeerFound(Device device) {
    final index = _discoveredPeers.indexWhere((p) => p.id == device.id);
    
    if (index < 0) {
      _discoveredPeers.add(device);
      _peersController.add(List.from(_discoveredPeers));
    }
  }

  void _onPeerLost(String deviceId) {
    _discoveredPeers.removeWhere((p) => p.id == deviceId);
    _peersController.add(List.from(_discoveredPeers));
  }

  void _onDataReceived(Map<String, dynamic> data) {
    _dataReceivedController.add(data);
  }

  Device getCurrentDevice() {
    return Device(
      id: 'ios_${DateTime.now().millisecondsSinceEpoch}',
      name: _deviceName,
      platform: DevicePlatform.ios,
      status: DeviceStatus.connected,
    );
  }

  Future<void> dispose() async {
    await _peersController.close();
    await _connectionController.close();
    await _dataReceivedController.close();
    _isInitialized = false;
    _isAdvertising = false;
    _isBrowsing = false;
  }
}
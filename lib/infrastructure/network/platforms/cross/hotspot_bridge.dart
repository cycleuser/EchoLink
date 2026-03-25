import 'dart:async';
import 'dart:io';
import '../../../../domain/models/models.dart';
import '../../../../core/result.dart';
import '../../../../core/constants.dart';
import '../../../../core/utils/logger.dart';
import '../android/hotspot_service.dart';

class HotspotBridge {
  static final HotspotBridge _instance = HotspotBridge._internal();
  factory HotspotBridge() => _instance;
  HotspotBridge._internal();

  final _connectionController = StreamController<Device?>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  final HotspotService _hotspotService = HotspotService();

  bool _isInitialized = false;
  Device? _connectedDevice;
  ServerSocket? _serverSocket;
  Socket? _clientSocket;
  bool _isServer = false;

  Stream<Device?> get connection => _connectionController.stream;
  Stream<String> get errors => _errorController.stream;

  bool get isInitialized => _isInitialized;
  bool get isServer => _isServer;
  Device? get connectedDevice => _connectedDevice;

  Future<Result<void>> initialize() async {
    try {
      AppLogger.info('Initializing hotspot bridge');
      
      await _hotspotService.initialize();
      _isInitialized = true;
      
      return const Success(null);
    } catch (e) {
      AppLogger.error('Failed to initialize hotspot bridge', e);
      return Failure(e.toString());
    }
  }

  Future<Result<HotspotInfo>> startAsHost({
    String? ssid,
    String? password,
  }) async {
    if (!_isInitialized) {
      return Failure('Bridge not initialized');
    }

    try {
      AppLogger.info('Starting as hotspot host');
      _isServer = true;

      final result = await _hotspotService.startHotspot(
        ssid: ssid,
        password: password,
      );

      if (result.isFailure) {
        return Failure(result.error);
      }

      final info = result.data;
      
      await _startServer(info.port);

      return Success(info);
    } catch (e) {
      AppLogger.error('Failed to start as host', e);
      return Failure(e.toString());
    }
  }

  Future<Result<void>> joinAsClient({
    required String ssid,
    required String password,
    required String hostIp,
    required int port,
  }) async {
    if (!_isInitialized) {
      return Failure('Bridge not initialized');
    }

    try {
      AppLogger.info('Joining as client to $ssid');

      _isServer = false;

      await Future.delayed(const Duration(seconds: 2));

      final socket = await Socket.connect(
        hostIp,
        port,
        timeout: const Duration(seconds: 10),
      );

      _clientSocket = socket;
      
      _connectedDevice = Device(
        id: 'host_$hostIp',
        name: 'Host Device',
        ipAddress: hostIp,
        port: port,
        status: DeviceStatus.connected,
        connectionType: ConnectionType.hotspot,
      );

      _connectionController.add(_connectedDevice);

      _listenToSocket(socket);

      return const Success(null);
    } catch (e) {
      AppLogger.error('Failed to join as client', e);
      return Failure(e.toString());
    }
  }

  Future<Result<void>> disconnect() async {
    try {
      AppLogger.info('Disconnecting hotspot bridge');

      _clientSocket?.close();
      _clientSocket = null;

      await _serverSocket?.close();
      _serverSocket = null;

      if (_isServer) {
        await _hotspotService.stopHotspot();
      }

      _connectedDevice = null;
      _isServer = false;
      
      _connectionController.add(null);

      return const Success(null);
    } catch (e) {
      AppLogger.error('Failed to disconnect', e);
      return Failure(e.toString());
    }
  }

  Future<void> _startServer(int port) async {
    _serverSocket = await ServerSocket.bind(
      InternetAddress.anyIPv4,
      port,
    );

    _serverSocket!.listen((client) {
      _handleClientConnection(client);
    });
  }

  void _handleClientConnection(Socket client) {
    AppLogger.info('Client connected: ${client.remoteAddress.address}');
    
    _clientSocket = client;
    
    _connectedDevice = Device(
      id: 'client_${client.remoteAddress.address}',
      name: 'Client Device',
      ipAddress: client.remoteAddress.address,
      status: DeviceStatus.connected,
      connectionType: ConnectionType.hotspot,
    );
    
    _connectionController.add(_connectedDevice);
    
    _listenToSocket(client);
  }

  void _listenToSocket(Socket socket) {
    socket.listen(
      (data) {
        _onDataReceived(data);
      },
      onError: (error) {
        AppLogger.error('Socket error', error);
        _errorController.add(error.toString());
      },
      onDone: () {
        AppLogger.info('Socket closed');
        _handleDisconnection();
      },
    );
  }

  void _onDataReceived(List<int> data) {
    // Handle received data
  }

  void _handleDisconnection() {
    _connectedDevice = null;
    _clientSocket = null;
    _connectionController.add(null);
  }

  Future<void> sendData(List<int> data) async {
    if (_clientSocket == null) {
      throw Exception('No connection established');
    }
    
    _clientSocket!.add(data);
  }

  Future<void> dispose() async {
    await disconnect();
    await _connectionController.close();
    await _errorController.close();
    await _hotspotService.dispose();
    _isInitialized = false;
  }
}
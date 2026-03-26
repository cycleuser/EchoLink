import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../../domain/models/models.dart';
import '../../core/result.dart';
import '../../core/constants.dart';
import '../../core/utils/logger.dart';

class CrossPlatformNetworkService {
  static final CrossPlatformNetworkService _instance = CrossPlatformNetworkService._internal();
  factory CrossPlatformNetworkService() => _instance;
  CrossPlatformNetworkService._internal();

  static const int discoveryPort = 50505;
  static const int baseDataPort = 50506;
  static const String multicastGroup = '239.255.0.1';
  static const Duration discoveryInterval = Duration(seconds: 2);
  static const Duration deviceTimeout = Duration(seconds: 15);

  final _devicesController = StreamController<Device>.broadcast();
  final _messagesController = StreamController<Message>.broadcast();
  final _connectionStateController = StreamController<ConnectionState>.broadcast();
  final _connectedDeviceController = StreamController<Device?>.broadcast();

  RawDatagramSocket? _broadcastSocket;
  RawDatagramSocket? _multicastSocket;
  ServerSocket? _dataServer;
  Socket? _dataSocket;

  Timer? _broadcastTimer;
  Timer? _cleanupTimer;

  String _deviceId = '';
  String _deviceName = '';
  String _localAddress = '';
  int _dataPort = 0;
  bool _isInitialized = false;
  bool _isDiscovering = false;
  Device? _connectedDevice;
  final Map<String, Device> _discoveredDevices = {};

  Stream<Device> get deviceDiscovered => _devicesController.stream;
  Stream<Message> get messageReceived => _messagesController.stream;
  Stream<ConnectionState> get connectionState => _connectionStateController.stream;
  Stream<Device?> get connectedDeviceStream => _connectedDeviceController.stream;

  bool get isInitialized => _isInitialized;
  bool get isDiscovering => _isDiscovering;
  Device? get currentConnectedDevice => _connectedDevice;
  String get localAddress => _localAddress;
  int get dataPort => _dataPort;
  List<Device> get devices => _discoveredDevices.values.toList();

  Future<Result<void>> initialize(String deviceName) async {
    if (_isInitialized) {
      return const Success(null);
    }

    try {
      _deviceId = _generateDeviceId();
      _deviceName = deviceName;

      await _detectNetworkInterface();
      await _startDataServer();
      await _startDiscoveryListeners();

      _startCleanupTimer();

      _isInitialized = true;
      AppLogger.info('CrossPlatformNetwork initialized: $_deviceName at $_localAddress:$_dataPort');

      return const Success(null);
    } catch (e) {
      AppLogger.error('Failed to initialize network service', e);
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
      _isDiscovering = true;
      _discoveredDevices.clear();
      _connectionStateController.add(ConnectionState.discovering);

      _broadcastTimer?.cancel();
      _broadcastTimer = Timer.periodic(discoveryInterval, (_) {
        _broadcastPresence();
      });

      _broadcastPresence();

      AppLogger.info('Discovery started');
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
      _broadcastTimer?.cancel();
      _broadcastTimer = null;
      _isDiscovering = false;

      if (_connectedDevice == null) {
        _connectionStateController.add(ConnectionState.disconnected);
      }

      AppLogger.info('Discovery stopped');
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
      _connectionStateController.add(ConnectionState.connecting);
      AppLogger.info('Connecting to ${device.name} at ${device.ipAddress}:${device.port}');

      _dataSocket?.destroy();
      _dataSocket = null;

      _dataSocket = await Socket.connect(
        device.ipAddress!,
        device.port!,
        timeout: const Duration(seconds: 10),
      );

      _sendHandshake(_dataSocket!);
      _listenToSocket(_dataSocket!);

      _connectedDevice = device.copyWith(
        status: DeviceStatus.connected,
        connectionType: ConnectionType.wifiDirect,
      );

      _connectionStateController.add(ConnectionState.connected);
      _connectedDeviceController.add(_connectedDevice);

      AppLogger.info('Connected to ${device.name}');
      return const Success(null);
    } on SocketException catch (e) {
      AppLogger.error('Connection failed', e);
      _connectionStateController.add(ConnectionState.error);
      return Failure('Connection failed: ${e.message}');
    } catch (e) {
      AppLogger.error('Connection failed', e);
      _connectionStateController.add(ConnectionState.error);
      return Failure(e.toString());
    }
  }

  Future<Result<void>> disconnect() async {
    try {
      _dataSocket?.destroy();
      _dataSocket = null;
      _connectedDevice = null;

      _connectionStateController.add(ConnectionState.disconnected);
      _connectedDeviceController.add(null);

      AppLogger.info('Disconnected');
      return const Success(null);
    } catch (e) {
      AppLogger.error('Failed to disconnect', e);
      return Failure(e.toString());
    }
  }

  Future<Result<void>> sendMessage(String content) async {
    if (_dataSocket == null) {
      return Failure('No connection established');
    }

    if (content.isEmpty) {
      return const Success(null);
    }

    try {
      final message = Message(
        id: _generateMessageId(),
        senderId: _deviceId,
        senderName: _deviceName,
        content: content,
        timestamp: DateTime.now(),
        status: MessageStatus.sending,
      );

      final data = jsonEncode({
        'type': 'message',
        'id': message.id,
        'senderId': message.senderId,
        'senderName': message.senderName,
        'content': message.content,
        'timestamp': message.timestamp.toIso8601String(),
      }) + '\n';

      _dataSocket!.write(data);

      final sentMessage = message.copyWith(status: MessageStatus.sent);
      _messagesController.add(sentMessage);

      AppLogger.debug('Message sent: ${message.id}');
      return const Success(null);
    } catch (e) {
      AppLogger.error('Failed to send message', e);
      return Failure(e.toString());
    }
  }

  Device getCurrentDevice() {
    return Device(
      id: _deviceId,
      name: _deviceName,
      platform: _getPlatform(),
      ipAddress: _localAddress,
      port: _dataPort,
      status: _connectedDevice != null ? DeviceStatus.connected : DeviceStatus.disconnected,
      connectionType: ConnectionType.wifiDirect,
      lastSeen: DateTime.now(),
    );
  }

  Future<void> dispose() async {
    _broadcastTimer?.cancel();
    _cleanupTimer?.cancel();

    _broadcastSocket?.close();
    _multicastSocket?.close();
    await _dataServer?.close();
    _dataSocket?.destroy();

    await _devicesController.close();
    await _messagesController.close();
    await _connectionStateController.close();
    await _connectedDeviceController.close();

    _isInitialized = false;
    _isDiscovering = false;
    _connectedDevice = null;
    _discoveredDevices.clear();
  }

  Future<void> _detectNetworkInterface() async {
    try {
      final interfaces = await NetworkInterface.list();
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 &&
              !addr.isLoopback &&
              !addr.address.startsWith('169.254.')) {
            _localAddress = addr.address;
            AppLogger.info('Network interface: ${interface.name} - $_localAddress');
            return;
          }
        }
      }
    } catch (e) {
      AppLogger.error('Failed to detect network interface', e);
    }
    _localAddress = '127.0.0.1';
  }

  Future<void> _startDataServer() async {
    for (int offset = 0; offset < 100; offset++) {
      try {
        final port = baseDataPort + offset;
        _dataServer = await ServerSocket.bind(InternetAddress.anyIPv4, port);
        _dataPort = port;

        _dataServer!.listen((socket) {
          _handleIncomingConnection(socket);
        });

        AppLogger.info('Data server started on port $port');
        return;
      } catch (e) {
        continue;
      }
    }
    throw Exception('Failed to start data server: no available port');
  }

  Future<void> _startDiscoveryListeners() async {
    try {
      _broadcastSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        discoveryPort,
      );
      _broadcastSocket!.broadcastEnabled = true;

      _broadcastSocket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _broadcastSocket!.receive();
          if (datagram != null) {
            _handleDiscoveryPacket(datagram);
          }
        }
      });

      AppLogger.info('Discovery listener started on port $discoveryPort');
    } catch (e) {
      AppLogger.error('Failed to start discovery listener', e);
      rethrow;
    }
  }

  void _broadcastPresence() {
    if (_dataPort == 0) return;

    final data = jsonEncode({
      'type': 'announce',
      'id': _deviceId,
      'name': _deviceName,
      'platform': _getPlatformString(),
      'address': _localAddress,
      'port': _dataPort,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    final bytes = utf8.encode(data);

    try {
      final broadcastAddr = _getBroadcastAddress();
      if (broadcastAddr != null) {
        _broadcastSocket?.send(bytes, InternetAddress(broadcastAddr), discoveryPort);
      }
      _broadcastSocket?.send(bytes, InternetAddress('255.255.255.255'), discoveryPort);
    } catch (e) {
      AppLogger.error('Failed to broadcast presence', e);
    }
  }

  void _handleDiscoveryPacket(Datagram datagram) {
    try {
      final data = utf8.decode(datagram.data);
      final json = jsonDecode(data) as Map<String, dynamic>;

      final senderId = json['id'] as String;
      if (senderId == _deviceId) return;

      final packetType = json['type'] as String? ?? 'announce';

      final deviceAddress = json['address'] as String? ?? datagram.address.address;
      final devicePort = json['port'] as int? ?? baseDataPort;

      final device = Device(
        id: senderId,
        name: json['name'] as String? ?? 'Unknown',
        platform: _parsePlatform(json['platform'] as String?),
        ipAddress: deviceAddress,
        port: devicePort,
        status: DeviceStatus.disconnected,
        connectionType: ConnectionType.wifiDirect,
        lastSeen: DateTime.now(),
      );

      final isNew = !_discoveredDevices.containsKey(device.id);
      _discoveredDevices[device.id] = device;

      if (isNew) {
        AppLogger.info('Discovered: ${device.name} (${device.platform}) at $deviceAddress:$devicePort');
      }

      if (!_devicesController.isClosed) {
        _devicesController.add(device);
      }
    } catch (e) {
      // Ignore malformed packets
    }
  }

  void _handleIncomingConnection(Socket socket) {
    AppLogger.info('Incoming connection from ${socket.remoteAddress.address}');

    _dataSocket?.destroy();
    _dataSocket = socket;

    _listenToSocket(socket);

    _sendHandshake(socket);
  }

  void _sendHandshake(Socket socket) {
    final handshake = jsonEncode({
      'type': 'handshake',
      'id': _deviceId,
      'name': _deviceName,
      'platform': _getPlatformString(),
      'address': _localAddress,
      'port': _dataPort,
    }) + '\n';

    socket.write(handshake);
  }

  void _listenToSocket(Socket socket) {
    String buffer = '';

    socket.listen(
      (data) {
        buffer += utf8.decode(data);

        while (buffer.contains('\n')) {
          final idx = buffer.indexOf('\n');
          final line = buffer.substring(0, idx);
          buffer = buffer.substring(idx + 1);

          _handleSocketData(line);
        }
      },
      onError: (error) {
        AppLogger.error('Socket error', error);
        _handleDisconnection();
      },
      onDone: () {
        AppLogger.info('Socket closed');
        _handleDisconnection();
      },
    );
  }

  void _handleSocketData(String line) {
    try {
      final json = jsonDecode(line) as Map<String, dynamic>;
      final type = json['type'] as String?;

      switch (type) {
        case 'handshake':
          _handleHandshake(json);
          break;
        case 'message':
          _handleMessage(json);
          break;
      }
    } catch (e) {
      AppLogger.error('Failed to parse socket data', e);
    }
  }

  void _handleHandshake(Map<String, dynamic> json) {
    final senderId = json['id'] as String;
    final senderName = json['name'] as String? ?? 'Unknown';

    _connectedDevice = Device(
      id: senderId,
      name: senderName,
      platform: _parsePlatform(json['platform'] as String?),
      ipAddress: json['address'] as String?,
      port: json['port'] as int?,
      status: DeviceStatus.connected,
      connectionType: ConnectionType.wifiDirect,
    );

    _connectionStateController.add(ConnectionState.connected);
    _connectedDeviceController.add(_connectedDevice);

    AppLogger.info('Handshake completed with $senderName');
  }

  void _handleMessage(Map<String, dynamic> json) {
    final message = Message(
      id: json['id'] as String,
      senderId: json['senderId'] as String,
      senderName: json['senderName'] as String,
      content: json['content'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      status: MessageStatus.received,
    );

    _messagesController.add(message);
    AppLogger.debug('Message received: ${message.id}');
  }

  void _handleDisconnection() {
    _connectedDevice = null;
    _dataSocket = null;

    _connectionStateController.add(ConnectionState.disconnected);
    _connectedDeviceController.add(null);
  }

  void _startCleanupTimer() {
    _cleanupTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _cleanupOldDevices();
    });
  }

  void _cleanupOldDevices() {
    final now = DateTime.now();
    _discoveredDevices.removeWhere((id, device) {
      final isOld = device.lastSeen != null &&
          now.difference(device.lastSeen!) > deviceTimeout;
      if (isOld) {
        AppLogger.debug('Device removed: ${device.name}');
      }
      return isOld;
    });
  }

  String? _getBroadcastAddress() {
    final parts = _localAddress.split('.');
    if (parts.length == 4) {
      parts[3] = '255';
      return parts.join('.');
    }
    return null;
  }

  String _generateDeviceId() {
    return '${_getPlatformString().toLowerCase()}_${DateTime.now().millisecondsSinceEpoch}';
  }

  String _generateMessageId() {
    return 'msg_${DateTime.now().millisecondsSinceEpoch}';
  }

  DevicePlatform _getPlatform() {
    if (Platform.isAndroid) return DevicePlatform.android;
    if (Platform.isIOS) return DevicePlatform.ios;
    if (Platform.isMacOS) return DevicePlatform.ios;
    return DevicePlatform.unknown;
  }

  String _getPlatformString() {
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isMacOS) return 'macOS';
    return 'Unknown';
  }

  DevicePlatform _parsePlatform(String? platform) {
    switch (platform?.toLowerCase()) {
      case 'android':
        return DevicePlatform.android;
      case 'ios':
      case 'macos':
        return DevicePlatform.ios;
      default:
        return DevicePlatform.unknown;
    }
  }
}
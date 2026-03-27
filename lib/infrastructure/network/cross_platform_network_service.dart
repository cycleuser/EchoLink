import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../../domain/models/models.dart';
import '../../core/result.dart';
import '../../core/utils/logger.dart';

class PeerConnection {
  final Device device;
  final Socket socket;
  final int localPort;
  Timer? heartbeatTimer;
  DateTime? lastHeartbeat;
  String buffer = '';

  PeerConnection({
    required this.device,
    required this.socket,
    required this.localPort,
  });

  void dispose() {
    heartbeatTimer?.cancel();
    socket.destroy();
  }
}

class CrossPlatformNetworkService {
  static final CrossPlatformNetworkService _instance =
      CrossPlatformNetworkService._internal();
  factory CrossPlatformNetworkService() => _instance;
  CrossPlatformNetworkService._internal();

  static const int discoveryPort = 50505;
  static const int baseDataPort = 50506;
  static const Duration heartbeatInterval = Duration(seconds: 5);
  static const Duration heartbeatTimeout = Duration(seconds: 20);
  static const String androidHostAddress = '10.0.2.2';
  static const String multicastGroup = '239.255.255.250';

  final _devicesController = StreamController<Device>.broadcast();
  final _messagesController = StreamController<Message>.broadcast();
  final _debugLogController = StreamController<String>.broadcast();
  final _connectionRequestController = StreamController<Device>.broadcast();

  RawDatagramSocket? _discoverySocket;
  RawDatagramSocket? _multicastSocket;
  ServerSocket? _serverSocket;
  final Map<String, PeerConnection> _connections = {};
  final Map<String, Device> _discoveredDevices = {};
  final List<String> _localAddresses = [];
  String _localSubnet = '';
  int _serverPort = 0;
  String _deviceId = '';
  String _deviceName = '';
  bool _isInitialized = false;
  bool _isDiscovering = false;
  bool _allowAutoConnect = false;
  bool _isAndroidEmulator = false;
  Timer? _discoveryTimer;
  Timer? _scanTimer;
  int _scanOffset = 0;

  Stream<Device> get deviceDiscovered => _devicesController.stream;
  Stream<Message> get messageReceived => _messagesController.stream;
  Stream<String> get debugLog => _debugLogController.stream;
  Stream<Device> get connectionRequest => _connectionRequestController.stream;

  final _connectionStateController =
      StreamController<EchoLinkConnectionState>.broadcast();
  Stream<EchoLinkConnectionState> get connectionState =>
      _connectionStateController.stream;

  Socket? _pendingConnectionSocket;
  Device? _pendingConnectionDevice;

  bool get isInitialized => _isInitialized;
  bool get isDiscovering => _isDiscovering;
  List<Device> get connectedDevices =>
      _connections.values.map((c) => c.device).toList();
  List<Device> get discoveredDevices => _discoveredDevices.values.toList();
  List<String> get localAddresses => List.unmodifiable(_localAddresses);
  int get serverPort => _serverPort;
  bool get allowAutoConnect => _allowAutoConnect;

  Device? get currentConnectedDevice =>
      _connections.isNotEmpty ? _connections.values.first.device : null;

  Stream<List<Device>> get connectedDevicesStream {
    return Stream.periodic(const Duration(seconds: 1), (_) => connectedDevices);
  }

  void setAllowAutoConnect(bool value) {
    _allowAutoConnect = value;
    _log('Auto-connect ${value ? "enabled" : "disabled"}');
  }

  void acceptConnection() {
    if (_pendingConnectionSocket != null && _pendingConnectionDevice != null) {
      final socket = _pendingConnectionSocket!;
      final device = _pendingConnectionDevice!;

      final connection = PeerConnection(
        device: device,
        socket: socket,
        localPort: _serverPort,
      );
      connection.lastHeartbeat = DateTime.now();

      _connections[device.id] = connection;
      _startHeartbeat(connection);

      _sendHandshakeResponse(socket, {});

      if (!_connectionStateController.isClosed) {
        _connectionStateController.add(EchoLinkConnectionState.connected);
      }

      _log('Accepted connection: ${device.name}');
    }
    _pendingConnectionSocket = null;
    _pendingConnectionDevice = null;
  }

  void rejectConnection() {
    if (_pendingConnectionSocket != null) {
      _pendingConnectionSocket!.destroy();
      _log('Rejected connection request');
    }
    _pendingConnectionSocket = null;
    _pendingConnectionDevice = null;
  }

  void _log(String message) {
    AppLogger.info(message);
    if (!_debugLogController.isClosed) {
      _debugLogController.add(message);
    }
  }

  Future<Result<void>> initialize([String? deviceName]) async {
    if (_isInitialized) return const Success(null);

    try {
      _log('Initializing network service...');

      _deviceId =
          '${_getPlatformString().toLowerCase()}_${DateTime.now().millisecondsSinceEpoch}';
      _deviceName = deviceName ?? '${_getPlatformString()} Device';

      await _detectNetworkInterfaces();

      if (Platform.isAndroid) {
        _isAndroidEmulator = _localAddresses.any((addr) =>
            addr.startsWith('10.0.2.') || addr.startsWith('10.0.15.'));
      }

      await _startServer();
      await _startDiscoverySocket();

      _isInitialized = true;
      _log('Initialized: $_deviceName');
      _log('Addresses: $_localAddresses');
      _log('Server port: $_serverPort');

      return const Success(null);
    } catch (e) {
      AppLogger.error('Init failed', e);
      return Failure(e.toString());
    }
  }

  Future<void> _detectNetworkInterfaces() async {
    _localAddresses.clear();

    try {
      final interfaces = await NetworkInterface.list();

      _log('Total interfaces found: ${interfaces.length}');

      final wifiAddresses = <String>[];
      final otherAddresses = <String>[];

      for (final interface in interfaces) {
        _log('Interface: ${interface.name}');
        for (final addr in interface.addresses) {
          _log(
              '  ${addr.address} (IPv${addr.type == InternetAddressType.IPv4 ? 4 : 6}, loopback: ${addr.isLoopback})');

          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            final address = addr.address;

            if (_isValidLocalAddress(address)) {
              final isWifi = _isWifiInterface(interface.name);
              final isPreferred = address.startsWith('192.168.');

              if (isWifi || isPreferred) {
                if (!wifiAddresses.contains(address)) {
                  wifiAddresses.add(address);
                }
                _log('  -> WIFI/PREFERRED: $address (${interface.name})');
              } else {
                if (!otherAddresses.contains(address)) {
                  otherAddresses.add(address);
                }
                _log('  -> OTHER: $address (${interface.name})');
              }
            } else {
              _log('  -> SKIPPED: $address');
            }
          }
        }
      }

      if (wifiAddresses.isNotEmpty) {
        _localAddresses.addAll(wifiAddresses);
        _log('Using Wi-Fi addresses: $wifiAddresses');
      } else if (otherAddresses.isNotEmpty) {
        final preferred =
            otherAddresses.where((a) => a.startsWith('192.168.')).toList();
        if (preferred.isNotEmpty) {
          _localAddresses.addAll(preferred);
          _log('Using preferred addresses: $preferred');
        } else {
          _localAddresses.addAll(otherAddresses);
          _log('Using other addresses: $otherAddresses');
        }
      }

      if (_localAddresses.isNotEmpty) {
        final parts = _localAddresses.first.split('.');
        if (parts.length == 4) {
          _localSubnet = '${parts[0]}.${parts[1]}.${parts[2]}';
        }
      }
    } catch (e) {
      _log('Interface detection error: $e');
      AppLogger.error('Interface detection failed', e);
    }

    if (_localAddresses.isEmpty) {
      _log('WARNING: No valid addresses found!');
      if (Platform.isAndroid) {
        _localAddresses.add('10.0.2.15');
        _localSubnet = '10.0.2';
      }
    }

    _log('Final local addresses: $_localAddresses');
    _log('Subnet: $_localSubnet');
  }

  bool _isWifiInterface(String name) {
    final lowerName = name.toLowerCase();
    return lowerName.contains('wifi') ||
        lowerName.contains('wlan') ||
        lowerName.contains('wi-fi') ||
        lowerName.contains('en0') ||
        lowerName.contains('en1') ||
        lowerName == 'en0' ||
        lowerName == 'wlan0' ||
        lowerName == 'wlan1';
  }

  bool _isValidLocalAddress(String address) {
    if (address.isEmpty) return false;
    if (address.startsWith('127.')) return false;
    if (address.startsWith('0.')) return false;
    if (address.startsWith('169.254.')) return false;
    if (address.startsWith('198.18.')) return false;
    if (address.startsWith('224.') || address.startsWith('239.')) return false;

    if (address.startsWith('10.185.')) return false;
    if (address.startsWith('10.186.')) return false;
    if (address.startsWith('10.187.')) return false;

    final parts = address.split('.');
    if (parts.length != 4) return false;

    final first = int.tryParse(parts[0]) ?? 0;
    final second = int.tryParse(parts[1]) ?? 0;

    if (first == 10) return true;
    if (first == 172 && second >= 16 && second <= 31) return true;
    if (first == 192 && second == 168) return true;

    return false;
  }

  Future<void> _startServer() async {
    for (int offset = 0; offset < 100; offset++) {
      try {
        final port = baseDataPort + offset;
        _serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, port);
        _serverPort = port;

        _serverSocket!.listen(_handleIncomingConnection);
        _log('Server listening on port $port');
        return;
      } catch (e) {
        continue;
      }
    }
    throw Exception('No available port');
  }

  Future<void> _startDiscoverySocket() async {
    try {
      _discoverySocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        discoveryPort,
      );
      _discoverySocket!.broadcastEnabled = true;

      _discoverySocket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _discoverySocket!.receive();
          if (datagram != null) {
            _handleDiscoveryPacket(datagram);
          }
        }
      });

      _log('Discovery socket ready on port $discoveryPort');

      try {
        _multicastSocket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv4,
          discoveryPort + 1,
        );
        _multicastSocket!.joinMulticast(InternetAddress(multicastGroup));
        _multicastSocket!.listen((event) {
          if (event == RawSocketEvent.read) {
            final datagram = _multicastSocket!.receive();
            if (datagram != null) {
              _handleDiscoveryPacket(datagram);
            }
          }
        });
        _log('Multicast socket joined $multicastGroup:${discoveryPort + 1}');
      } catch (e) {
        _log('Multicast not available: $e');
      }
    } catch (e) {
      _log('Discovery socket failed: $e');
      AppLogger.error('Discovery socket failed', e);
    }
  }

  void _handleIncomingConnection(Socket socket) {
    _log('Incoming: ${socket.remoteAddress.address}');

    String buffer = '';

    socket.listen(
      (data) {
        buffer += utf8.decode(data);

        while (buffer.contains('\n')) {
          final idx = buffer.indexOf('\n');
          final line = buffer.substring(0, idx);
          buffer = buffer.substring(idx + 1);

          try {
            final json = jsonDecode(line) as Map<String, dynamic>;
            _handlePacket(json, socket);
          } catch (e) {
            // Ignore
          }
        }
      },
      onError: (e) {
        _log('Connection error: $e');
        socket.destroy();
      },
      onDone: () {
        _log('Connection closed');
        _removeConnection(socket);
      },
    );
  }

  void _handlePacket(Map<String, dynamic> json, Socket socket) {
    final type = json['type'] as String?;
    final senderId = json['id'] as String?;

    switch (type) {
      case 'handshake':
        _handleHandshake(json, socket);
        break;
      case 'message':
        _handleMessage(json);
        break;
      case 'heartbeat':
        if (senderId != null && _connections.containsKey(senderId)) {
          _connections[senderId]!.lastHeartbeat = DateTime.now();
        }
        break;
      case 'announce':
      case 'probe':
        if (senderId != null && senderId != _deviceId) {
          _handleDeviceAnnounce(json);
          _sendHandshakeResponse(socket, json);
        }
        break;
    }
  }

  void _handleHandshake(Map<String, dynamic> json, Socket socket) {
    final senderId = json['id'] as String;
    final senderName = json['name'] as String? ?? 'Unknown';

    if (_connections.containsKey(senderId)) {
      _log('Already connected to $senderName');
      return;
    }

    final device = Device(
      id: senderId,
      name: senderName,
      platform: _parsePlatform(json['platform'] as String?),
      ipAddress: (json['addresses'] as List?)?.first as String? ??
          socket.remoteAddress.address,
      port: json['port'] as int?,
      status: DeviceStatus.connected,
      connectionType: ConnectionType.wifiDirect,
    );

    if (_allowAutoConnect) {
      final connection = PeerConnection(
        device: device,
        socket: socket,
        localPort: _serverPort,
      );
      connection.lastHeartbeat = DateTime.now();

      _connections[senderId] = connection;
      _startHeartbeat(connection);

      _log('Auto-accepted: ${device.name} (${device.platform})');

      if (!_devicesController.isClosed) {
        _devicesController.add(device.copyWith(status: DeviceStatus.connected));
      }
      if (!_connectionStateController.isClosed) {
        _connectionStateController.add(EchoLinkConnectionState.connected);
      }

      _sendHandshakeResponse(socket, json);
    } else {
      _pendingConnectionSocket = socket;
      _pendingConnectionDevice = device;

      if (!_connectionRequestController.isClosed) {
        _connectionRequestController.add(device);
      }

      _log('Pending connection request: ${device.name}');
    }
  }

  void _sendHandshakeResponse(Socket socket, Map<String, dynamic> request) {
    final response = jsonEncode({
          'type': 'handshake_ack',
          'id': _deviceId,
          'name': _deviceName,
          'platform': _getPlatformString(),
          'addresses': _localAddresses,
          'port': _serverPort,
        }) +
        '\n';
    socket.write(response);
  }

  void _handleDeviceAnnounce(Map<String, dynamic> json) {
    final senderId = json['id'] as String;
    if (senderId == _deviceId) return;

    final addresses = json['addresses'] as List?;
    final device = Device(
      id: senderId,
      name: json['name'] as String? ?? 'Unknown',
      platform: _parsePlatform(json['platform'] as String?),
      ipAddress: addresses?.first as String?,
      port: json['port'] as int?,
      status: _connections.containsKey(senderId)
          ? DeviceStatus.connected
          : DeviceStatus.disconnected,
      connectionType: ConnectionType.wifiDirect,
      lastSeen: DateTime.now(),
    );

    _discoveredDevices[senderId] = device;

    if (!_devicesController.isClosed) {
      _devicesController.add(device);
    }
  }

  void _handleMessage(Map<String, dynamic> json) {
    final senderId = json['senderId'] as String;

    String? receiverId = json['receiverId'] as String?;
    if (receiverId == null) {
      receiverId = _deviceId;
    }

    final message = Message(
      id: json['id'] as String,
      senderId: senderId,
      senderName: json['senderName'] as String,
      content: json['content'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      status: MessageStatus.received,
      receiverId: receiverId,
    );

    _log('Received message from ${message.senderName}: ${message.content}');

    if (!_messagesController.isClosed) {
      _messagesController.add(message);
    }
  }

  void _startHeartbeat(PeerConnection connection) {
    connection.heartbeatTimer?.cancel();

    connection.heartbeatTimer = Timer.periodic(heartbeatInterval, (_) {
      try {
        final heartbeat = jsonEncode({
              'type': 'heartbeat',
              'id': _deviceId,
              'timestamp': DateTime.now().millisecondsSinceEpoch,
            }) +
            '\n';
        connection.socket.write(heartbeat);
      } catch (e) {
        _log('Heartbeat failed: $e');
        _disconnectDevice(connection.device.id);
      }
    });

    Timer.periodic(heartbeatInterval, (timer) {
      if (!_connections.containsKey(connection.device.id)) {
        timer.cancel();
        return;
      }

      final conn = _connections[connection.device.id]!;
      if (conn.lastHeartbeat != null) {
        final elapsed = DateTime.now().difference(conn.lastHeartbeat!);
        if (elapsed > heartbeatTimeout) {
          _log('Heartbeat timeout: ${connection.device.name}');
          _disconnectDevice(connection.device.id);
          timer.cancel();
        }
      }
    });
  }

  void _removeConnection(Socket socket) {
    String? deviceId;
    for (final entry in _connections.entries) {
      if (entry.value.socket == socket) {
        deviceId = entry.key;
        break;
      }
    }

    if (deviceId != null) {
      _disconnectDevice(deviceId);
    }
  }

  void _disconnectDevice(String deviceId) {
    final connection = _connections.remove(deviceId);
    if (connection != null) {
      connection.dispose();
      _log('Disconnected: ${connection.device.name}');

      if (!_connectionStateController.isClosed) {
        if (_connections.isEmpty) {
          _connectionStateController.add(EchoLinkConnectionState.disconnected);
        }
      }
    }
  }

  Future<Result<void>> startDiscovery() async {
    if (!_isInitialized) return Failure('Not initialized');
    if (_isDiscovering) return const Success(null);

    _isDiscovering = true;
    _discoveredDevices.clear();
    _scanOffset = 1;

    _discoveryTimer?.cancel();
    _discoveryTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _broadcastPresence();
    });

    _scanTimer?.cancel();
    _scanTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      _scanNext();
    });

    _broadcastPresence();

    _log('Discovery started, local addresses: $_localAddresses');
    _log('Scanning subnet: $_localSubnet');

    _scanLocalSubnet();

    return const Success(null);
  }

  Future<Result<void>> stopDiscovery() async {
    if (!_isDiscovering) return const Success(null);

    _discoveryTimer?.cancel();
    _scanTimer?.cancel();
    _isDiscovering = false;

    _log('Discovery stopped');
    return const Success(null);
  }

  void _broadcastPresence() {
    if (_discoverySocket == null || _serverPort == 0) {
      _log('Cannot broadcast: socket=$_discoverySocket, port=$_serverPort');
      return;
    }

    final data = jsonEncode({
      'type': 'announce',
      'id': _deviceId,
      'name': _deviceName,
      'platform': _getPlatformString(),
      'addresses': _localAddresses,
      'port': _serverPort,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    final bytes = utf8.encode(data);

    try {
      _discoverySocket!
          .send(bytes, InternetAddress('255.255.255.255'), discoveryPort);
      _log('Broadcast to 255.255.255.255:$discoveryPort');
    } catch (e) {
      _log('Broadcast failed: $e');
    }

    if (_multicastSocket != null) {
      try {
        _multicastSocket!
            .send(bytes, InternetAddress(multicastGroup), discoveryPort + 1);
        _log('Multicast to $multicastGroup:${discoveryPort + 1}');
      } catch (e) {
        _log('Multicast failed: $e');
      }
    }

    for (final addr in _localAddresses) {
      final parts = addr.split('.');
      if (parts.length == 4) {
        parts[3] = '255';
        final broadcast = parts.join('.');
        try {
          _discoverySocket!
              .send(bytes, InternetAddress(broadcast), discoveryPort);
        } catch (e) {}
      }
    }

    if (_isAndroidEmulator) {
      try {
        _discoverySocket!
            .send(bytes, InternetAddress(androidHostAddress), discoveryPort);
      } catch (e) {}
    }
  }

  void _scanNext() {
    if (_localSubnet.isEmpty) return;

    for (int i = 0; i < 5; i++) {
      final ip = '$_localSubnet.$_scanOffset';
      _scanOffset = (_scanOffset + 1) % 256;
      if (_scanOffset == 0) _scanOffset = 1;

      if (_localAddresses.contains(ip)) continue;

      for (int portOffset = 0; portOffset < 10; portOffset++) {
        final port = baseDataPort + portOffset;
        if (port != _serverPort) {
          _probeDevice(ip, port);
        }
      }
    }
  }

  void _scanLocalSubnet() {
    _log('Scanning subnet $_localSubnet.*');

    for (int i = 1; i < 255; i++) {
      final ip = '$_localSubnet.$i';
      if (_localAddresses.contains(ip)) continue;

      for (int portOffset = 0; portOffset < 10; portOffset++) {
        final port = baseDataPort + portOffset;
        if (port != _serverPort) {
          _probeDevice(ip, port);
        }
      }
    }
  }

  void _probeDevice(String ip, int port) {
    Socket.connect(ip, port, timeout: const Duration(milliseconds: 200))
        .then((socket) {
      _log('Connected to $ip:$port, sending probe');
      final probe = jsonEncode({
            'type': 'probe',
            'id': _deviceId,
            'name': _deviceName,
            'platform': _getPlatformString(),
            'addresses': _localAddresses,
            'port': _serverPort,
          }) +
          '\n';
      socket.write(probe);

      Timer(const Duration(milliseconds: 100), () {
        try {
          socket.destroy();
        } catch (e) {}
      });
    }).catchError((e) {});
  }

  void _handleDiscoveryPacket(Datagram datagram) {
    try {
      final data = utf8.decode(datagram.data);
      final json = jsonDecode(data) as Map<String, dynamic>;

      final senderId = json['id'] as String;
      if (senderId == _deviceId) return;

      _handleDeviceAnnounce(json);
    } catch (e) {}
  }

  Future<Result<void>> connect(Device device) async {
    if (!_isInitialized) return Failure('Not initialized');
    if (_connections.containsKey(device.id)) {
      return const Success(null);
    }

    final address = device.ipAddress;
    final port = device.port ?? baseDataPort;

    if (address == null) return Failure('No address');

    try {
      _log('Connecting to ${device.name} at $address:$port');

      final socket = await Socket.connect(
        address,
        port,
        timeout: const Duration(seconds: 5),
      );

      final connection = PeerConnection(
        device: device.copyWith(status: DeviceStatus.connected),
        socket: socket,
        localPort: _serverPort,
      );
      connection.lastHeartbeat = DateTime.now();

      String buffer = '';
      socket.listen(
        (data) {
          buffer += utf8.decode(data);
          while (buffer.contains('\n')) {
            final idx = buffer.indexOf('\n');
            final line = buffer.substring(0, idx);
            buffer = buffer.substring(idx + 1);
            try {
              final json = jsonDecode(line) as Map<String, dynamic>;
              _handlePacket(json, socket);
            } catch (e) {}
          }
        },
        onError: (e) => _disconnectDevice(device.id),
        onDone: () => _disconnectDevice(device.id),
      );

      final handshake = jsonEncode({
            'type': 'handshake',
            'id': _deviceId,
            'name': _deviceName,
            'platform': _getPlatformString(),
            'addresses': _localAddresses,
            'port': _serverPort,
          }) +
          '\n';
      socket.write(handshake);

      _connections[device.id] = connection;
      _startHeartbeat(connection);

      if (!_connectionStateController.isClosed) {
        _connectionStateController.add(EchoLinkConnectionState.connected);
      }

      _log('Connected: ${device.name}');
      return const Success(null);
    } catch (e) {
      _log('Connect failed: $e');
      return Failure(e.toString());
    }
  }

  Future<Result<void>> disconnect([String? deviceId]) async {
    if (deviceId != null) {
      _disconnectDevice(deviceId);
    } else {
      for (final id in _connections.keys.toList()) {
        _disconnectDevice(id);
      }
    }
    return const Success(null);
  }

  Future<Result<void>> sendMessage(String content, [String? deviceId]) async {
    if (content.isEmpty) return const Success(null);

    final targets = deviceId != null
        ? [_connections[deviceId]]
        : _connections.values.toList();

    if (targets.isEmpty || targets.first == null) {
      return Failure('No connection');
    }

    final targetDevice = deviceId != null && _connections.containsKey(deviceId)
        ? _connections[deviceId]!.device
        : null;

    final message = Message(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      senderId: _deviceId,
      senderName: _deviceName,
      content: content,
      timestamp: DateTime.now(),
      status: MessageStatus.sending,
      receiverId: targetDevice?.id,
    );

    final data = jsonEncode({
          'type': 'message',
          'id': message.id,
          'senderId': message.senderId,
          'senderName': message.senderName,
          'content': message.content,
          'timestamp': message.timestamp.toIso8601String(),
          'receiverId': message.receiverId,
        }) +
        '\n';

    for (final conn in targets) {
      if (conn != null) {
        try {
          conn.socket.write(data);
        } catch (e) {
          _log('Send failed: $e');
        }
      }
    }

    return const Success(null);
  }

  Device getCurrentDevice() {
    return Device(
      id: _deviceId,
      name: _deviceName,
      platform: _getPlatform(),
      ipAddress:
          _localAddresses.isNotEmpty ? _localAddresses.first : '127.0.0.1',
      port: _serverPort,
      status: _connections.isNotEmpty
          ? DeviceStatus.connected
          : DeviceStatus.disconnected,
      connectionType: ConnectionType.wifiDirect,
      lastSeen: DateTime.now(),
    );
  }

  DevicePlatform _getPlatform() {
    if (Platform.isAndroid) return DevicePlatform.android;
    if (Platform.isIOS) return DevicePlatform.ios;
    if (Platform.isMacOS) return DevicePlatform.macos;
    return DevicePlatform.unknown;
  }

  String _getPlatformString() {
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isMacOS) return 'macOS';
    return 'Unknown';
  }

  DevicePlatform _parsePlatform(String? s) {
    switch (s?.toLowerCase()) {
      case 'android':
        return DevicePlatform.android;
      case 'ios':
        return DevicePlatform.ios;
      case 'macos':
        return DevicePlatform.macos;
      default:
        return DevicePlatform.unknown;
    }
  }

  Future<void> dispose() async {
    _discoveryTimer?.cancel();
    _scanTimer?.cancel();

    for (final conn in _connections.values) {
      conn.dispose();
    }
    _connections.clear();

    _discoverySocket?.close();
    await _serverSocket?.close();

    await _devicesController.close();
    await _messagesController.close();
    await _debugLogController.close();
    await _connectionRequestController.close();
    await _connectionStateController.close();

    _isInitialized = false;
    _isDiscovering = false;
  }
}

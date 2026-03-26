import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../../domain/models/models.dart';
import '../../core/result.dart';
import '../../core/utils/logger.dart';

class CrossPlatformNetworkService {
  static final CrossPlatformNetworkService _instance = CrossPlatformNetworkService._internal();
  factory CrossPlatformNetworkService() => _instance;
  CrossPlatformNetworkService._internal();

  static const int discoveryPort = 50505;
  static const int baseDataPort = 50506;
  static const Duration discoveryInterval = Duration(seconds: 1);
  static const Duration deviceTimeout = Duration(seconds: 30);
  static const String androidHostAddress = '10.0.2.2';

  final _devicesController = StreamController<Device>.broadcast();
  final _messagesController = StreamController<Message>.broadcast();
  final _connectionStateController = StreamController<EchoLinkConnectionState>.broadcast();
  final _connectedDeviceController = StreamController<Device?>.broadcast();
  final _debugLogController = StreamController<String>.broadcast();

  RawDatagramSocket? _broadcastSocket;
  ServerSocket? _dataServer;
  Socket? _dataSocket;

  Timer? _broadcastTimer;
  Timer? _cleanupTimer;
  Timer? _scanTimer;

  String _deviceId = '';
  String _deviceName = '';
  final List<String> _localAddresses = [];
  String _localSubnet = '';
  int _dataPort = 0;
  bool _isInitialized = false;
  bool _isDiscovering = false;
  Device? _connectedDevice;
  final Map<String, Device> _discoveredDevices = {};
  bool _isAndroidEmulator = false;
  int _scanOffset = 0;

  Stream<Device> get deviceDiscovered => _devicesController.stream;
  Stream<Message> get messageReceived => _messagesController.stream;
  Stream<EchoLinkConnectionState> get connectionState => _connectionStateController.stream;
  Stream<Device?> get connectedDeviceStream => _connectedDeviceController.stream;
  Stream<String> get debugLog => _debugLogController.stream;

  bool get isInitialized => _isInitialized;
  bool get isDiscovering => _isDiscovering;
  Device? get currentConnectedDevice => _connectedDevice;
  List<String> get localAddresses => List.unmodifiable(_localAddresses);
  int get dataPort => _dataPort;
  List<Device> get devices => _discoveredDevices.values.toList();

  void _log(String message) {
    AppLogger.info(message);
    if (!_debugLogController.isClosed) {
      _debugLogController.add(message);
    }
  }

  Future<Result<void>> initialize(String deviceName) async {
    if (_isInitialized) {
      return const Success(null);
    }

    try {
      _log('Initializing network service...');
      
      _deviceId = _generateDeviceId();
      _deviceName = deviceName;

      await _detectAllNetworkInterfaces();

      if (Platform.isAndroid) {
        _isAndroidEmulator = _localAddresses.any((addr) => 
          addr.startsWith('10.0.2.') || addr.startsWith('10.0.15.'));
      }

      await _startDataServer();
      await _startDiscoverySocket();

      _startCleanupTimer();

      _isInitialized = true;
      _log('Network initialized: $_deviceName');
      _log('Local addresses: $_localAddresses');
      _log('Data port: $_dataPort');
      _log('Subnet: $_localSubnet');

      return const Success(null);
    } catch (e) {
      AppLogger.error('Failed to initialize network service', e);
      return Failure(e.toString());
    }
  }

  Future<void> _detectAllNetworkInterfaces() async {
    _localAddresses.clear();
    
    try {
      final interfaces = await NetworkInterface.list();
      
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 &&
              !addr.isLoopback &&
              !addr.address.startsWith('169.254.')) {
            _localAddresses.add(addr.address);
            
            final parts = addr.address.split('.');
            if (parts.length == 4) {
              _localSubnet = '${parts[0]}.${parts[1]}.${parts[2]}';
            }
            
            _log('Found interface: ${interface.name} - ${addr.address}');
          }
        }
      }
    } catch (e) {
      AppLogger.error('Failed to detect network interfaces', e);
    }
    
    if (_localAddresses.isEmpty) {
      if (Platform.isAndroid) {
        _localAddresses.add('10.0.2.15');
        _localSubnet = '10.0.2';
      } else {
        _localAddresses.add('127.0.0.1');
        _localSubnet = '127.0.0';
      }
      _log('No network interfaces found, using fallback');
    }
  }

  Future<void> _startDiscoverySocket() async {
    try {
      _broadcastSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        discoveryPort,
      );
      _broadcastSocket!.broadcastEnabled = true;
      _broadcastSocket!.multicastLoopback = true;
      
      _broadcastSocket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _broadcastSocket!.receive();
          if (datagram != null) {
            _handleDiscoveryPacket(datagram);
          }
        }
      });

      _log('Discovery socket started on port $discoveryPort');
    } catch (e) {
      AppLogger.error('Failed to start discovery socket', e);
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
      _connectionStateController.add(EchoLinkConnectionState.discovering);
      _scanOffset = 0;

      _broadcastTimer?.cancel();
      _broadcastTimer = Timer.periodic(discoveryInterval, (_) {
        _broadcastPresence();
      });

      _scanTimer?.cancel();
      _scanTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
        _scanNextIPs();
      });

      _broadcastPresence();
      _scanLocalSubnetImmediate();

      _log('Discovery started');
      return const Success(null);
    } catch (e) {
      AppLogger.error('Failed to start discovery', e);
      _isDiscovering = false;
      return Failure(e.toString());
    }
  }

  void _scanNextIPs() {
    if (_localSubnet.isEmpty) return;
    
    final portsToScan = List.generate(5, (i) => baseDataPort + i);
    
    for (int i = 0; i < 5; i++) {
      final ipToScan = '$_localSubnet.$_scanOffset';
      _scanOffset = (_scanOffset + 1) % 256;
      
      if (ipToScan == _localAddresses.first) continue;
      
      for (final port in portsToScan) {
        if (port == _dataPort) continue;
        _probePort(ipToScan, port);
      }
    }
  }

  void _scanLocalSubnetImmediate() {
    final portsToScan = List.generate(10, (i) => baseDataPort + i);
    
    for (int i = 1; i < 50; i++) {
      final ipToScan = '$_localSubnet.$i';
      if (_localAddresses.contains(ipToScan)) continue;
      
      for (final port in portsToScan) {
        if (port == _dataPort) continue;
        _probePort(ipToScan, port);
      }
    }
    
    for (final addr in _localAddresses) {
      for (final port in portsToScan) {
        if (port == _dataPort) continue;
        _probePort(addr, port);
      }
    }
    
    if (!Platform.isIOS) {
      for (final port in portsToScan) {
        if (port == _dataPort) continue;
        _probePort('127.0.0.1', port);
      }
    }
  }

  Future<void> _probePort(String address, int port) async {
    try {
      final socket = await Socket.connect(
        address,
        port,
        timeout: const Duration(milliseconds: 200),
      );
      
      _log('TCP probe success: $address:$port');

      final probe = jsonEncode({
        'type': 'probe',
        'id': _deviceId,
        'name': _deviceName,
        'platform': _getPlatformString(),
        'addresses': _localAddresses,
        'port': _dataPort,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      }) + '\n';
      
      socket.write(probe);

      String buffer = '';
      socket.listen((data) {
        buffer += utf8.decode(data);
        
        while (buffer.contains('\n')) {
          final idx = buffer.indexOf('\n');
          final line = buffer.substring(0, idx);
          buffer = buffer.substring(idx + 1);
          
          try {
            final response = jsonDecode(line) as Map<String, dynamic>;
            if (response['type'] == 'handshake') {
              final device = Device(
                id: response['id'] as String,
                name: response['name'] as String? ?? 'Unknown',
                platform: _parsePlatform(response['platform'] as String?),
                ipAddress: address,
                port: port,
                status: DeviceStatus.disconnected,
                connectionType: ConnectionType.wifiDirect,
                lastSeen: DateTime.now(),
              );
              
              if (device.id != _deviceId) {
                final isNew = !_discoveredDevices.containsKey(device.id);
                _discoveredDevices[device.id] = device;
                
                if (isNew) {
                  _log('Discovered via TCP: ${device.name} at $address:$port');
                }
                
                if (!_devicesController.isClosed) {
                  _devicesController.add(device);
                }
              }
            }
          } catch (e) {
            // Ignore
          }
        }
      });

      Future.delayed(const Duration(milliseconds: 150), () {
        socket.destroy();
      });
    } catch (e) {
      // Port not available
    }
  }

  Future<Result<void>> stopDiscovery() async {
    if (!_isDiscovering) {
      return const Success(null);
    }

    try {
      _broadcastTimer?.cancel();
      _broadcastTimer = null;
      _scanTimer?.cancel();
      _scanTimer = null;
      _isDiscovering = false;

      if (_connectedDevice == null) {
        _connectionStateController.add(EchoLinkConnectionState.disconnected);
      }

      _log('Discovery stopped');
      return const Success(null);
    } catch (e) {
      AppLogger.error('Failed to stop discovery', e);
      return Failure(e.toString());
    }
  }

  void _broadcastPresence() {
    if (_dataPort == 0 || _broadcastSocket == null) return;

    final data = jsonEncode({
      'type': 'announce',
      'id': _deviceId,
      'name': _deviceName,
      'platform': _getPlatformString(),
      'addresses': _localAddresses,
      'port': _dataPort,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    final bytes = utf8.encode(data);

    try {
      _broadcastSocket!.send(bytes, InternetAddress('255.255.255.255'), discoveryPort);
    } catch (e) {
      // Ignore
    }

    for (final addr in _localAddresses) {
      final parts = addr.split('.');
      if (parts.length == 4) {
        parts[3] = '255';
        final broadcastAddr = parts.join('.');
        try {
          _broadcastSocket!.send(bytes, InternetAddress(broadcastAddr), discoveryPort);
        } catch (e) {
          // Ignore
        }
      }
    }

    if (_isAndroidEmulator) {
      try {
        _broadcastSocket!.send(bytes, InternetAddress(androidHostAddress), discoveryPort);
      } catch (e) {
        // Ignore
      }
    }
  }

  void _handleDiscoveryPacket(Datagram datagram) {
    try {
      final data = utf8.decode(datagram.data);
      final json = jsonDecode(data) as Map<String, dynamic>;

      final senderId = json['id'] as String;
      if (senderId == _deviceId) return;

      final packetType = json['type'] as String? ?? 'announce';

      if (packetType == 'probe') {
        _sendProbeResponse(datagram.address.address);
      }

      List<String> deviceAddresses = [];
      if (json['addresses'] != null) {
        deviceAddresses = List<String>.from(json['addresses']);
      } else {
        deviceAddresses = [datagram.address.address];
      }

      final devicePort = json['port'] as int? ?? baseDataPort;

      final device = Device(
        id: senderId,
        name: json['name'] as String? ?? 'Unknown',
        platform: _parsePlatform(json['platform'] as String?),
        ipAddress: deviceAddresses.first,
        port: devicePort,
        status: DeviceStatus.disconnected,
        connectionType: ConnectionType.wifiDirect,
        lastSeen: DateTime.now(),
      );

      final isNew = !_discoveredDevices.containsKey(device.id);
      _discoveredDevices[device.id] = device;

      if (isNew) {
        _log('Discovered via UDP: ${device.name} (${device.platform}) at ${deviceAddresses.first}:$devicePort');
      }

      if (!_devicesController.isClosed) {
        _devicesController.add(device);
      }
    } catch (e) {
      // Ignore malformed packets
    }
  }

  void _sendProbeResponse(String targetAddress) {
    if (_dataPort == 0 || _broadcastSocket == null) return;

    try {
      final responseData = jsonEncode({
        'type': 'announce',
        'id': _deviceId,
        'name': _deviceName,
        'platform': _getPlatformString(),
        'addresses': _localAddresses,
        'port': _dataPort,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      final bytes = utf8.encode(responseData);
      
      _broadcastSocket!.send(bytes, InternetAddress(targetAddress), discoveryPort);
    } catch (e) {
      // Ignore
    }
  }

  Future<Result<void>> connect(Device device) async {
    if (!_isInitialized) {
      return Failure('Service not initialized');
    }

    try {
      _connectionStateController.add(EchoLinkConnectionState.connecting);
      
      String targetAddress = device.ipAddress ?? '';
      int targetPort = device.port ?? baseDataPort;

      if (_isAndroidEmulator && device.platform != DevicePlatform.android) {
        _log('Android emulator connecting to host, trying $androidHostAddress');
        final success = await _tryConnect(androidHostAddress, targetPort, device);
        if (success) return const Success(null);
      }

      _log('Connecting to ${device.name} at $targetAddress:$targetPort');
      
      _dataSocket?.destroy();
      _dataSocket = null;

      _dataSocket = await Socket.connect(
        targetAddress,
        targetPort,
        timeout: const Duration(seconds: 5),
      );

      _sendHandshake(_dataSocket!);
      _listenToSocket(_dataSocket!);

      _connectedDevice = device.copyWith(
        status: DeviceStatus.connected,
        connectionType: ConnectionType.wifiDirect,
      );

      _connectionStateController.add(EchoLinkConnectionState.connected);
      _connectedDeviceController.add(_connectedDevice);

      _log('Connected to ${device.name}');
      return const Success(null);
    } on SocketException catch (e) {
      AppLogger.error('Connection failed', e);
      _connectionStateController.add(EchoLinkConnectionState.error);
      return Failure('Connection failed: ${e.message}');
    } catch (e) {
      AppLogger.error('Connection failed', e);
      _connectionStateController.add(EchoLinkConnectionState.error);
      return Failure(e.toString());
    }
  }

  Future<bool> _tryConnect(String address, int port, Device device) async {
    try {
      final socket = await Socket.connect(
        address,
        port,
        timeout: const Duration(seconds: 3),
      );

      _dataSocket?.destroy();
      _dataSocket = socket;

      _sendHandshake(socket);
      _listenToSocket(socket);

      _connectedDevice = device.copyWith(
        status: DeviceStatus.connected,
        ipAddress: address,
        connectionType: ConnectionType.wifiDirect,
      );

      _connectionStateController.add(EchoLinkConnectionState.connected);
      _connectedDeviceController.add(_connectedDevice);

      _log('Connected to ${device.name} via $address');
      return true;
    } catch (e) {
      AppLogger.debug('Failed to connect to $address: $e');
      return false;
    }
  }

  Future<Result<void>> disconnect() async {
    try {
      _dataSocket?.destroy();
      _dataSocket = null;
      _connectedDevice = null;

      _connectionStateController.add(EchoLinkConnectionState.disconnected);
      _connectedDeviceController.add(null);

      _log('Disconnected');
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

      _log('Message sent: ${message.content}');
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
      ipAddress: _localAddresses.isNotEmpty ? _localAddresses.first : '127.0.0.1',
      port: _dataPort,
      status: _connectedDevice != null ? DeviceStatus.connected : DeviceStatus.disconnected,
      connectionType: ConnectionType.wifiDirect,
      lastSeen: DateTime.now(),
    );
  }

  Future<void> dispose() async {
    _broadcastTimer?.cancel();
    _cleanupTimer?.cancel();
    _scanTimer?.cancel();

    _broadcastSocket?.close();
    await _dataServer?.close();
    _dataSocket?.destroy();

    await _devicesController.close();
    await _messagesController.close();
    await _connectionStateController.close();
    await _connectedDeviceController.close();
    await _debugLogController.close();

    _isInitialized = false;
    _isDiscovering = false;
    _connectedDevice = null;
    _discoveredDevices.clear();
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

        _log('Data server started on port $port');
        return;
      } catch (e) {
        continue;
      }
    }
    throw Exception('Failed to start data server: no available port');
  }

  void _handleIncomingConnection(Socket socket) {
    _log('Incoming connection from ${socket.remoteAddress.address}');

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
      'addresses': _localAddresses,
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
        _log('Socket closed');
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
        case 'probe':
          _handleProbeResponse(json);
          break;
      }
    } catch (e) {
      AppLogger.error('Failed to parse socket data', e);
    }
  }

  void _handleProbeResponse(Map<String, dynamic> json) {
    final senderId = json['id'] as String;
    if (senderId == _deviceId) return;

    final device = Device(
      id: senderId,
      name: json['name'] as String? ?? 'Unknown',
      platform: _parsePlatform(json['platform'] as String?),
      ipAddress: json['addresses'] != null 
          ? (json['addresses'] as List).first as String?
          : null,
      port: json['port'] as int?,
      status: DeviceStatus.disconnected,
      connectionType: ConnectionType.wifiDirect,
      lastSeen: DateTime.now(),
    );

    final isNew = !_discoveredDevices.containsKey(device.id);
    _discoveredDevices[device.id] = device;

    if (isNew) {
      _log('Discovered via probe response: ${device.name}');
    }

    if (!_devicesController.isClosed) {
      _devicesController.add(device);
    }
  }

  void _handleHandshake(Map<String, dynamic> json) {
    final senderId = json['id'] as String;
    final senderName = json['name'] as String? ?? 'Unknown';

    _connectedDevice = Device(
      id: senderId,
      name: senderName,
      platform: _parsePlatform(json['platform'] as String?),
      ipAddress: json['addresses'] != null 
          ? (json['addresses'] as List).first as String?
          : json['address'] as String?,
      port: json['port'] as int?,
      status: DeviceStatus.connected,
      connectionType: ConnectionType.wifiDirect,
    );

    _connectionStateController.add(EchoLinkConnectionState.connected);
    _connectedDeviceController.add(_connectedDevice);

    _log('Handshake completed with $senderName');
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
    _log('Message received: ${message.content}');
  }

  void _handleDisconnection() {
    _connectedDevice = null;
    _dataSocket = null;

    _connectionStateController.add(EchoLinkConnectionState.disconnected);
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
        _log('Device removed: ${device.name}');
      }
      return isOld;
    });
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
    if (Platform.isMacOS) return DevicePlatform.macos;
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
        return DevicePlatform.ios;
      case 'macos':
        return DevicePlatform.macos;
      default:
        return DevicePlatform.unknown;
    }
  }
}
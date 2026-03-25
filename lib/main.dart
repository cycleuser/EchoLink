import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

void main() {
  runApp(const ProviderScope(child: EchoLinkApp()));
}

class EchoLinkApp extends StatelessWidget {
  const EchoLinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EchoLink',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2196F3)),
        useMaterial3: true,
      ),
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class Device {
  final String id;
  final String name;
  final String platform;
  final String address;
  final int port;
  final DateTime lastSeen;

  const Device({
    required this.id,
    required this.name,
    required this.platform,
    this.address = '',
    this.port = 0,
    required this.lastSeen,
  });

  Device copyWith({String? address, int? port, DateTime? lastSeen}) {
    return Device(
      id: id,
      name: name,
      platform: platform,
      address: address ?? this.address,
      port: port ?? this.port,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }
}

class Message {
  final String id;
  final String senderId;
  final String senderName;
  final String content;
  final DateTime timestamp;
  final bool isMe;

  const Message({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.timestamp,
    required this.isMe,
  });
}

class ConnectionInfo {
  final Device device;
  final Socket socket;
  final String buffer;

  ConnectionInfo({
    required this.device,
    required this.socket,
    this.buffer = '',
  });

  ConnectionInfo copyWith({String? buffer}) {
    return ConnectionInfo(
      device: device,
      socket: socket,
      buffer: buffer ?? this.buffer,
    );
  }
}

class P2PNetworkService {
  static const int discoveryPort = 50505;
  static const int baseMessagePort = 50506;
  static const String multicastGroupAddr = '239.255.0.1';

  int _messagePort = 0;
  String _localAddress = '';

  RawDatagramSocket? _sendSocket;
  RawDatagramSocket? _receiveSocket;
  ServerSocket? _messageServer;
  
  Socket? _clientSocket;
  ConnectionInfo? _activeConnection;
  
  Timer? _broadcastTimer;
  Timer? _cleanupTimer;

  final _uuid = const Uuid();
  String _deviceId = '';
  String _deviceName = '';
  String _platform = 'Unknown';

  final _devicesController = StreamController<Device>.broadcast();
  final _messagesController = StreamController<Message>.broadcast();
  final _connectionStateController = StreamController<bool>.broadcast();
  final _connectedDeviceController = StreamController<Device?>.broadcast();
  final _logController = StreamController<String>.broadcast();

  final Map<String, Device> _discoveredDevices = {};

  Stream<Device> get deviceDiscovered => _devicesController.stream;
  Stream<Message> get messageReceived => _messagesController.stream;
  Stream<bool> get connectionStateChanged => _connectionStateController.stream;
  Stream<Device?> get connectedDeviceChanged => _connectedDeviceController.stream;
  Stream<String> get logs => _logController.stream;

  String get deviceId => _deviceId;
  String get deviceName => _deviceName;
  String get platform => _platform;
  bool get isConnected => _activeConnection != null;

  Future<void> initialize(String deviceName) async {
    _deviceId = _uuid.v4();
    _deviceName = deviceName;

    if (Platform.isAndroid) {
      _platform = 'Android';
    } else if (Platform.isIOS) {
      _platform = 'iOS';
    } else if (Platform.isMacOS) {
      _platform = 'macOS';
    }

    _log('Initializing P2P Network...');
    _log('Device ID: $_deviceId');
    _log('Device Name: $_deviceName');
    _log('Platform: $_platform');

    await _detectNetworkInterface();
    await _startDiscovery();
    await _startMessageServer();

    _log('Local: $_localAddress, Discovery: $discoveryPort, Message: $_messagePort');

    _cleanupTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _cleanupOldDevices();
    });

    _log('P2P Network ready');
  }

  void _log(String message) {
    debugPrint('[EchoLink] $message');
    if (!_logController.isClosed) {
      _logController.add(message);
    }
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
            _log('Network: ${interface.name} - $_localAddress');
            return;
          }
        }
      }
    } catch (e) {
      _log('Network detection error: $e');
    }
    _localAddress = '127.0.0.1';
  }

  Future<void> _startDiscovery() async {
    try {
      _sendSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _log('Send socket on port ${_sendSocket!.port}');

      _receiveSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, discoveryPort);
      final multicastAddr = InternetAddress(multicastGroupAddr);
      _receiveSocket!.joinMulticast(multicastAddr);
      _receiveSocket!.multicastLoopback = true;

      _receiveSocket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _receiveSocket!.receive();
          if (datagram != null) {
            _handleDiscoveryPacket(datagram);
          }
        }
      });

      _broadcastTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        _broadcastPresence();
      });

      _log('Discovery on multicast $multicastGroupAddr:$discoveryPort');
    } catch (e) {
      _log('Discovery error: $e');
      await _startDiscoveryAlternative();
    }
  }

  Future<void> _startDiscoveryAlternative() async {
    for (int offset = 1; offset <= 10; offset++) {
      try {
        final port = discoveryPort + offset;
        _receiveSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, port);
        final multicastAddr = InternetAddress(multicastGroupAddr);
        _receiveSocket!.joinMulticast(multicastAddr);
        _receiveSocket!.multicastLoopback = true;

        _receiveSocket!.listen((event) {
          if (event == RawSocketEvent.read) {
            final datagram = _receiveSocket!.receive();
            if (datagram != null) {
              _handleDiscoveryPacket(datagram);
            }
          }
        });

        _broadcastTimer = Timer.periodic(const Duration(seconds: 2), (_) {
          _broadcastPresence();
        });

        _log('Discovery on alternative port $port');
        return;
      } catch (e) {
        continue;
      }
    }
    _log('Failed to start discovery');
  }

  void _handleDiscoveryPacket(Datagram datagram) {
    try {
      final data = utf8.decode(datagram.data);
      final json = jsonDecode(data) as Map<String, dynamic>;

      final senderId = json['id'] as String;
      if (senderId == _deviceId) return;

      final deviceAddress = json['address'] as String? ?? datagram.address.address;
      final device = Device(
        id: senderId,
        name: json['name'] as String,
        platform: json['platform'] as String,
        address: deviceAddress,
        port: json['port'] as int? ?? baseMessagePort,
        lastSeen: DateTime.now(),
      );

      final isNew = !_discoveredDevices.containsKey(device.id);
      _discoveredDevices[device.id] = device;

      if (isNew) {
        _log('Found: ${device.name} (${device.platform}) at ${device.address}:${device.port}');
      }

      if (!_devicesController.isClosed) {
        _devicesController.add(device);
      }
    } catch (e) {
      // Ignore malformed packets
    }
  }

  void _broadcastPresence() {
    if (_sendSocket == null || _messagePort == 0) return;

    try {
      final data = jsonEncode({
        'id': _deviceId,
        'name': _deviceName,
        'platform': _platform,
        'address': _localAddress,
        'port': _messagePort,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      final bytes = utf8.encode(data);
      final multicastAddr = InternetAddress(multicastGroupAddr);
      _sendSocket!.send(bytes, multicastAddr, discoveryPort);
    } catch (e) {
      _log('Broadcast error: $e');
    }
  }

  void _cleanupOldDevices() {
    final now = DateTime.now();
    final timeout = const Duration(seconds: 15);

    _discoveredDevices.removeWhere((id, device) {
      final isOld = now.difference(device.lastSeen) > timeout;
      if (isOld) {
        _log('Device timeout: ${device.name}');
      }
      return isOld;
    });
  }

  Future<void> _startMessageServer() async {
    for (int offset = 0; offset < 100; offset++) {
      try {
        final port = baseMessagePort + offset;

        _messageServer = await ServerSocket.bind(InternetAddress.anyIPv4, port);
        _messagePort = port;

        _messageServer!.listen((socket) {
          _handleIncomingConnection(socket);
        });

        _log('Message server on port $port');
        return;
      } catch (e) {
        continue;
      }
    }

    _log('Failed to start message server');
  }

  void _handleIncomingConnection(Socket socket) {
    _log('Incoming from ${socket.remoteAddress.address}');
    
    String buffer = '';
    bool handshakeDone = false;

    socket.listen(
      (data) {
        buffer += utf8.decode(data);

        while (buffer.contains('\n')) {
          final idx = buffer.indexOf('\n');
          final line = buffer.substring(0, idx);
          buffer = buffer.substring(idx + 1);

          try {
            final json = jsonDecode(line) as Map<String, dynamic>;

            if (json['type'] == 'handshake' && !handshakeDone) {
              handshakeDone = true;
              final senderId = json['id'] as String;
              final device = _discoveredDevices[senderId] ?? Device(
                id: senderId,
                name: json['name'] as String,
                platform: json['platform'] as String,
                address: socket.remoteAddress.address,
                port: 0,
                lastSeen: DateTime.now(),
              );
              
              _activeConnection = ConnectionInfo(device: device, socket: socket, buffer: buffer);
              
              _log('Handshake from ${device.name}');
              
              if (!_connectionStateController.isClosed) {
                _connectionStateController.add(true);
              }
              if (!_connectedDeviceController.isClosed) {
                _connectedDeviceController.add(device);
              }
              continue;
            }

            if (json['type'] == 'message') {
              final msg = Message(
                id: json['id'] as String,
                senderId: json['senderId'] as String,
                senderName: json['senderName'] as String,
                content: json['content'] as String,
                timestamp: DateTime.parse(json['timestamp'] as String),
                isMe: false,
              );
              
              if (!_messagesController.isClosed) {
                _messagesController.add(msg);
              }
              _log('Recv: ${msg.content}');
            }
          } catch (e) {
            _log('Parse error: $e');
          }
        }
      },
      onError: (error) {
        _log('Socket error: $error');
        _disconnect();
      },
      onDone: () {
        _log('Socket closed');
        _disconnect();
      },
    );
  }

  void _disconnect() {
    _activeConnection = null;
    if (!_connectionStateController.isClosed) {
      _connectionStateController.add(false);
    }
    if (!_connectedDeviceController.isClosed) {
      _connectedDeviceController.add(null);
    }
  }

  Future<bool> connectToDevice(Device device) async {
    try {
      _log('Connecting to ${device.name} at ${device.address}:${device.port}...');

      await _clientSocket?.close();
      _clientSocket = null;

      _clientSocket = await Socket.connect(
        device.address,
        device.port,
        timeout: const Duration(seconds: 5),
      );

      final handshake = jsonEncode({
        'type': 'handshake',
        'id': _deviceId,
        'name': _deviceName,
        'platform': _platform,
      }) + '\n';
      _clientSocket!.add(utf8.encode(handshake));

      String buffer = '';

      _clientSocket!.listen(
        (data) {
          buffer += utf8.decode(data);

          while (buffer.contains('\n')) {
            final idx = buffer.indexOf('\n');
            final line = buffer.substring(0, idx);
            buffer = buffer.substring(idx + 1);

            try {
              final json = jsonDecode(line) as Map<String, dynamic>;

              if (json['type'] == 'message') {
                final msg = Message(
                  id: json['id'] as String,
                  senderId: json['senderId'] as String,
                  senderName: json['senderName'] as String,
                  content: json['content'] as String,
                  timestamp: DateTime.parse(json['timestamp'] as String),
                  isMe: false,
                );
                if (!_messagesController.isClosed) {
                  _messagesController.add(msg);
                }
              }
            } catch (e) {
              // Ignore
            }
          }
        },
        onError: (error) {
          _log('Connection error: $error');
          _disconnect();
        },
        onDone: () {
          _log('Disconnected');
          _disconnect();
        },
      );

      _activeConnection = ConnectionInfo(device: device, socket: _clientSocket!);
      
      if (!_connectionStateController.isClosed) {
        _connectionStateController.add(true);
      }
      if (!_connectedDeviceController.isClosed) {
        _connectedDeviceController.add(device);
      }
      
      _log('Connected to ${device.name}');
      return true;
    } catch (e) {
      _log('Connect error: $e');
      return false;
    }
  }

  void sendMessage(String content) {
    final conn = _activeConnection;
    if (conn == null) {
      _log('Not connected');
      return;
    }

    final msg = Message(
      id: _uuid.v4(),
      senderId: _deviceId,
      senderName: _deviceName,
      content: content,
      timestamp: DateTime.now(),
      isMe: true,
    );

    try {
      final data = utf8.encode(jsonEncode({
        'type': 'message',
        'id': msg.id,
        'senderId': msg.senderId,
        'senderName': msg.senderName,
        'content': msg.content,
        'timestamp': msg.timestamp.toIso8601String(),
      }) + '\n');

      conn.socket.add(data);
      
      if (!_messagesController.isClosed) {
        _messagesController.add(msg);
      }
      _log('Sent: $content');
    } catch (e) {
      _log('Send error: $e');
      _disconnect();
    }
  }

  void disconnect() {
    _clientSocket?.close();
    _clientSocket = null;
    _disconnect();
  }

  List<Device> getDiscoveredDevices() {
    return _discoveredDevices.values.toList();
  }

  Future<void> dispose() async {
    _broadcastTimer?.cancel();
    _cleanupTimer?.cancel();
    _sendSocket?.close();
    _receiveSocket?.close();
    _messageServer?.close();
    _clientSocket?.close();
    
    await _devicesController.close();
    await _messagesController.close();
    await _connectionStateController.close();
    await _connectedDeviceController.close();
    await _logController.close();
  }
}

final networkServiceProvider = Provider<P2PNetworkService>((ref) {
  return P2PNetworkService();
});

class DevicesNotifier extends StateNotifier<List<Device>> {
  final P2PNetworkService _network;
  StreamSubscription? _sub;

  DevicesNotifier(this._network) : super([]) {
    _sub = _network.deviceDiscovered.listen((device) {
      final idx = state.indexWhere((d) => d.id == device.id);
      if (idx >= 0) {
        state = [...state]..[idx] = device;
      } else {
        state = [...state, device];
      }
    });
  }

  void refresh() {
    state = _network.getDiscoveredDevices();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final devicesProvider = StateNotifierProvider<DevicesNotifier, List<Device>>((ref) {
  return DevicesNotifier(ref.watch(networkServiceProvider));
});

class MessagesNotifier extends StateNotifier<List<Message>> {
  final P2PNetworkService _network;
  StreamSubscription? _sub;

  MessagesNotifier(this._network) : super([]) {
    _sub = _network.messageReceived.listen((msg) {
      state = [...state, msg];
    });
  }

  void send(String content) {
    _network.sendMessage(content);
  }

  void clear() {
    state = [];
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final messagesProvider = StateNotifierProvider<MessagesNotifier, List<Message>>((ref) {
  return MessagesNotifier(ref.watch(networkServiceProvider));
});

class ConnectionNotifier extends StateNotifier<Device?> {
  final P2PNetworkService _network;
  StreamSubscription? _sub;

  ConnectionNotifier(this._network) : super(null) {
    _sub = _network.connectedDeviceChanged.listen((device) {
      state = device;
    });
  }

  Future<bool> connect(Device device) async {
    return await _network.connectToDevice(device);
  }

  void disconnect() {
    _network.disconnect();
    state = null;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final connectionProvider = StateNotifierProvider<ConnectionNotifier, Device?>((ref) {
  return ConnectionNotifier(ref.watch(networkServiceProvider));
});

class LogsNotifier extends StateNotifier<List<String>> {
  final P2PNetworkService _network;
  StreamSubscription? _sub;

  LogsNotifier(this._network) : super([]) {
    _sub = _network.logs.listen((log) {
      state = [...state, log];
      if (state.length > 100) {
        state = state.sublist(state.length - 100);
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final logsProvider = StateNotifierProvider<LogsNotifier, List<String>>((ref) {
  return LogsNotifier(ref.watch(networkServiceProvider));
});

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int _currentIndex = 0;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initNetwork();
  }

  Future<void> _initNetwork() async {
    final network = ref.read(networkServiceProvider);
    final random = Random().nextInt(9000) + 1000;
    final deviceName = '${network.platform}-$random';

    await network.initialize(deviceName);

    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          DevicesPage(isReady: _isInitialized),
          ChatPage(isReady: _isInitialized),
          const TransferPage(),
          SettingsPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.devices_outlined),
            selectedIcon: Icon(Icons.devices),
            label: 'Devices',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Chat',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder),
            label: 'Transfer',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class DevicesPage extends ConsumerWidget {
  final bool isReady;

  const DevicesPage({super.key, required this.isReady});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(devicesProvider);
    final connectedDevice = ref.watch(connectionProvider);
    final network = ref.read(networkServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('EchoLink'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: isReady
                ? () => ref.read(devicesProvider.notifier).refresh()
                : null,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStatusBar(isReady, network),
          if (connectedDevice != null)
            _buildConnectedBanner(context, connectedDevice, ref),
          Expanded(
            child: !isReady
                ? const Center(child: CircularProgressIndicator())
                : devices.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: devices.length,
                        itemBuilder: (context, index) {
                          final device = devices[index];
                          return _buildDeviceCard(context, ref, device, connectedDevice);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar(bool isReady, P2PNetworkService network) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: isReady ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
      child: Row(
        children: [
          Icon(
            isReady ? Icons.check_circle : Icons.pending,
            color: isReady ? Colors.green : Colors.orange,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            isReady ? '${network.deviceName} - Ready' : 'Starting...',
            style: TextStyle(
              color: isReady ? Colors.green : Colors.orange,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectedBanner(BuildContext context, Device device, WidgetRef ref) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Row(
        children: [
          const Icon(Icons.wifi, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Connected to ${device.name}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          TextButton(
            onPressed: () => ref.read(connectionProvider.notifier).disconnect(),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_find, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('Searching for devices...', style: TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildDeviceCard(BuildContext context, WidgetRef ref, Device device, Device? connected) {
    final isConnected = connected?.id == device.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            device.platform == 'iOS'
                ? Icons.phone_iphone
                : device.platform == 'Android'
                    ? Icons.phone_android
                    : Icons.computer,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(device.name),
        subtitle: Text('${device.platform} • ${device.address}'),
        trailing: isConnected
            ? const Icon(Icons.check_circle, color: Colors.green)
            : ElevatedButton(
                onPressed: () async {
                  final success = await ref.read(connectionProvider.notifier).connect(device);
                  if (success && context.mounted) {
                    ref.read(messagesProvider.notifier).clear();
                  }
                },
                child: const Text('Connect'),
              ),
      ),
    );
  }
}

class ChatPage extends ConsumerStatefulWidget {
  final bool isReady;

  const ChatPage({super.key, required this.isReady});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    ref.read(messagesProvider.notifier).send(text);
    _messageController.clear();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final connectedDevice = ref.watch(connectionProvider);
    final messages = ref.watch(messagesProvider);

    return Scaffold(
      appBar: AppBar(
        title: connectedDevice != null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(connectedDevice.name),
                  Text(
                    '${connectedDevice.platform} • ${connectedDevice.address}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              )
            : const Text('Chat'),
      ),
      body: connectedDevice == null
          ? _buildEmptyState()
          : Column(
              children: [
                Expanded(
                  child: messages.isEmpty
                      ? _buildEmptyMessages()
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            return _buildMessageBubble(messages[index]);
                          },
                        ),
                ),
                _buildMessageInput(connectedDevice),
              ],
            ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('No device connected', style: TextStyle(fontSize: 16)),
          SizedBox(height: 8),
          Text('Connect to a device from the Devices tab', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildEmptyMessages() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('Start the conversation', style: TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Message msg) {
    return Align(
      alignment: msg.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: msg.isMe
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!msg.isMe)
              Text(
                msg.senderName,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            Text(
              msg.content,
              style: TextStyle(
                color: msg.isMe
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput(Device device) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              focusNode: _focusNode,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: _sendMessage,
            icon: const Icon(Icons.send),
          ),
        ],
      ),
    );
  }
}

class TransferPage extends ConsumerWidget {
  const TransferPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('File Transfer')),
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('File transfer coming soon', style: TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final network = ref.read(networkServiceProvider);
    final logs = ref.watch(logsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.devices),
            title: const Text('Device Name'),
            subtitle: Text(network.deviceName),
          ),
          ListTile(
            leading: const Icon(Icons.fingerprint),
            title: const Text('Device ID'),
            subtitle: Text(network.deviceId, style: const TextStyle(fontSize: 12)),
          ),
          ListTile(
            leading: const Icon(Icons.phone_android),
            title: const Text('Platform'),
            subtitle: Text(network.platform),
          ),
          const Divider(),
          ExpansionTile(
            leading: const Icon(Icons.article),
            title: const Text('Logs'),
            children: [
              Container(
                height: 300,
                padding: const EdgeInsets.all(8),
                child: ListView.builder(
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    return Text(
                      logs[index],
                      style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
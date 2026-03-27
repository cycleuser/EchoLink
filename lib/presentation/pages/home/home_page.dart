import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';
import '../../../domain/models/models.dart';
import '../../../infrastructure/network/cross_platform_network_service.dart';
import '../chat/chat_page.dart';
import '../transfer/transfer_page.dart';
import '../settings/settings_page.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int _currentIndex = 0;
  bool _isInitialized = false;
  String _initError = '';
  bool _isDiscovering = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      final result = await ref.read(connectionStateProvider.notifier).initialize();
      
      if (mounted) {
        setState(() {
          _isInitialized = result.isSuccess;
          if (!result.isSuccess) {
            result.when(
              success: (_) {},
              failure: (message, {exception}) {
                _initError = message;
              },
            );
          }
        });
        
        if (_isInitialized) {
          _listenForConnectionRequests();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _initError = e.toString();
        });
      }
    }
  }

  void _listenForConnectionRequests() {
    CrossPlatformNetworkService().connectionRequest.listen((device) {
      if (mounted) {
        _showConnectionRequestDialog(device);
      }
    });
  }

  void _showConnectionRequestDialog(Device device) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Connection Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getPlatformIcon(device.platform),
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              device.name,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'wants to connect to your device',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              CrossPlatformNetworkService().rejectConnection();
            },
            child: const Text('Reject'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              CrossPlatformNetworkService().acceptConnection();
            },
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return _buildLoadingScreen();
    }

    final connectionState = ref.watch(connectionStateProvider);
    final discoveredDevices = ref.watch(discoveredDevicesProvider);
    final currentDevice = ref.watch(currentDeviceProvider);
    final connectedDevice = ref.watch(connectedDeviceProvider);

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildDevicesPage(connectionState, discoveredDevices, currentDevice, connectedDevice),
          const ChatPage(),
          const TransferPage(),
          const SettingsPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
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

  Widget _buildLoadingScreen() {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              Text(
                'EchoLink',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Initializing network...',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              if (_initError.isNotEmpty) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _initError,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _initializeApp,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDevicesPage(
    EchoLinkConnectionState connectionState,
    List<Device> discoveredDevices,
    Device? currentDevice,
    Device? connectedDevice,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EchoLink'),
        actions: [
          if (_isDiscovering)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: _startDiscovery,
              tooltip: 'Scan for devices',
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildThisDeviceCard(currentDevice),
          const SizedBox(height: 16),
          _buildConnectedDeviceCard(connectedDevice, connectionState),
          const SizedBox(height: 16),
          _buildDiscoveredDevicesSection(discoveredDevices, connectionState, connectedDevice),
        ],
      ),
      floatingActionButton: _isDiscovering
          ? null
          : FloatingActionButton.extended(
              onPressed: _startDiscovery,
              icon: const Icon(Icons.search),
              label: const Text('Scan'),
            ),
    );
  }

  Widget _buildThisDeviceCard(Device? device) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This Device',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _getPlatformIcon(device?.platform),
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device?.name ?? 'Unknown',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        device != null ? '${device.ipAddress}:${device.port}' : 'Not available',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectedDeviceCard(Device? connectedDevice, EchoLinkConnectionState connectionState) {
    final isConnected = connectionState == EchoLinkConnectionState.connected;
    
    return Card(
      color: isConnected 
          ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
          : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Connected Device',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(connectionState).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: _getStatusColor(connectionState),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _getStatusText(connectionState),
                        style: TextStyle(
                          color: _getStatusColor(connectionState),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (isConnected && connectedDevice != null) ...[
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _getPlatformIcon(connectedDevice.platform),
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          connectedDevice.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          '${connectedDevice.ipAddress}:${connectedDevice.port}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.link_off),
                    onPressed: () => _disconnect(),
                    tooltip: 'Disconnect',
                  ),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  Icon(
                    Icons.link_off,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    connectionState == EchoLinkConnectionState.connecting
                        ? 'Connecting...'
                        : 'No device connected',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDiscoveredDevicesSection(
    List<Device> devices,
    EchoLinkConnectionState connectionState,
    Device? connectedDevice,
  ) {
    final availableDevices = devices.where((d) => 
      connectedDevice == null || d.id != connectedDevice.id
    ).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Nearby Devices',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const Spacer(),
            if (availableDevices.isNotEmpty)
              Text(
                '${availableDevices.length} found',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (availableDevices.isEmpty) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.devices_other,
                      size: 48,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _isDiscovering ? 'Scanning...' : 'No devices found',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    if (!_isDiscovering) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Tap "Scan" to search for nearby devices',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ] else ...[
          ...availableDevices.map((device) => _buildDeviceCard(
            device,
            connectionState == EchoLinkConnectionState.connecting,
          )),
        ],
      ],
    );
  }

  Widget _buildDeviceCard(Device device, bool isConnecting) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getPlatformIcon(device.platform),
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        title: Text(device.name),
        subtitle: Text(
          '${device.ipAddress}:${device.port}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontFamily: 'monospace',
          ),
        ),
        trailing: isConnecting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : ElevatedButton(
                onPressed: () => _connectToDevice(device),
                child: const Text('Connect'),
              ),
      ),
    );
  }

  Future<void> _startDiscovery() async {
    if (_isDiscovering) return;
    
    setState(() => _isDiscovering = true);
    
    await ref.read(connectionStateProvider.notifier).startDiscovery();
    
    await Future.delayed(const Duration(seconds: 10));
    
    if (mounted) {
      await ref.read(connectionStateProvider.notifier).stopDiscovery();
      setState(() => _isDiscovering = false);
    }
  }

  Future<void> _connectToDevice(Device device) async {
    final result = await ref.read(connectionStateProvider.notifier).connect(device);
    
    if (!mounted) return;
    
    result.when(
      success: (_) {
        _showToast('Connected to ${device.name}', isSuccess: true);
      },
      failure: (message, {exception}) {
        _showToast('Failed: $message', isSuccess: false);
      },
    );
  }

  void _showToast(String message, {required bool isSuccess}) {
    final overlay = Overlay.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    
    final entry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 60,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 200),
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                alignment: Alignment.topRight,
                child: Opacity(
                  opacity: value,
                  child: child,
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isSuccess ? Colors.green : colorScheme.error,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isSuccess ? Icons.check_circle : Icons.error,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 2), entry.remove);
  }

  Future<void> _disconnect() async {
    await ref.read(connectionStateProvider.notifier).disconnect();
  }

  String _getStatusText(EchoLinkConnectionState state) {
    switch (state) {
      case EchoLinkConnectionState.connected:
        return 'Connected';
      case EchoLinkConnectionState.connecting:
        return 'Connecting';
      case EchoLinkConnectionState.discovering:
        return 'Scanning';
      case EchoLinkConnectionState.disconnected:
        return 'Disconnected';
      case EchoLinkConnectionState.error:
        return 'Error';
    }
  }

  Color _getStatusColor(EchoLinkConnectionState state) {
    switch (state) {
      case EchoLinkConnectionState.connected:
        return Colors.green;
      case EchoLinkConnectionState.connecting:
      case EchoLinkConnectionState.discovering:
        return Colors.orange;
      case EchoLinkConnectionState.disconnected:
        return Theme.of(context).colorScheme.outline;
      case EchoLinkConnectionState.error:
        return Theme.of(context).colorScheme.error;
    }
  }

  IconData _getPlatformIcon(DevicePlatform? platform) {
    switch (platform) {
      case DevicePlatform.android:
        return Icons.phone_android;
      case DevicePlatform.ios:
        return Icons.phone_iphone;
      case DevicePlatform.macos:
        return Icons.computer;
      default:
        return Icons.devices;
    }
  }
}
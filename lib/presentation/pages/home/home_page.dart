import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';
import '../../../domain/models/models.dart';
import '../chat/chat_page.dart';
import '../transfer/transfer_page.dart';
import '../settings/settings_page.dart';
import '../../widgets/device_card.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int _currentIndex = 0;
  bool _isInitialized = false;
  String _initError = '';

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
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) _startDiscovery();
          });
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

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return _buildLoadingScreen();
    }

    final connectionState = ref.watch(connectionStateProvider);
    final discoveredDevices = ref.watch(discoveredDevicesProvider);
    final currentDevice = ref.watch(currentDeviceProvider);

    if (discoveredDevices.isNotEmpty && connectionState == EchoLinkConnectionState.disconnected) {
      final autoConnectEnabled = ref.read(autoConnectEnabledProvider);
      if (autoConnectEnabled) {
        Future.microtask(() => _autoConnect(discoveredDevices.first));
      }
    }

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildDevicesPage(connectionState, discoveredDevices, currentDevice),
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
                  child: Column(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _initError,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
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
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EchoLink'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _startDiscovery,
            tooltip: 'Refresh',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'settings') {
                setState(() => _currentIndex = 3);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'settings',
                child: ListTile(
                  leading: Icon(Icons.settings),
                  title: Text('Settings'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _buildCurrentDeviceCard(currentDevice, connectionState),
          _buildConnectionBanner(connectionState),
          Expanded(
            child: _buildDeviceList(discoveredDevices, connectionState),
          ),
        ],
      ),
      floatingActionButton: connectionState != EchoLinkConnectionState.discovering
          ? FloatingActionButton.extended(
              onPressed: _startDiscovery,
              icon: const Icon(Icons.search),
              label: const Text('Discover'),
            )
          : FloatingActionButton.extended(
              onPressed: () => ref.read(connectionStateProvider.notifier).stopDiscovery(),
              icon: const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              label: const Text('Scanning...'),
            ),
    );
  }

  Widget _buildCurrentDeviceCard(Device? device, EchoLinkConnectionState connectionState) {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getPlatformIcon(device?.platform),
                  size: 28,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'This Device',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      device?.name ?? 'Unknown',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      device != null ? '${device.ipAddress}:${device.port}' : 'Not connected',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getStatusColor(connectionState).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
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
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionBanner(EchoLinkConnectionState connectionState) {
    if (connectionState != EchoLinkConnectionState.connected) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.link, color: Colors.green, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Connected - Go to Chat tab to send messages',
              style: TextStyle(color: Colors.green[700]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceList(
    List<Device> devices,
    EchoLinkConnectionState connectionState,
  ) {
    if (connectionState == EchoLinkConnectionState.discovering && devices.isEmpty) {
      return _buildScanningView();
    }

    if (devices.isEmpty) {
      return _buildEmptyView();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(
            'Nearby Devices (${devices.length})',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: devices.length,
            itemBuilder: (context, index) {
              final device = devices[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: DeviceCard(
                  device: device,
                  onTap: () => _connectToDevice(device),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildScanningView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            'Scanning for devices...',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Make sure other devices are running EchoLink',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.devices_other,
                size: 48,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No devices found',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Make sure both devices are on the same WiFi network\nand running EchoLink',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _startDiscovery,
              icon: const Icon(Icons.search),
              label: const Text('Scan Again'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startDiscovery() async {
    await ref.read(connectionStateProvider.notifier).startDiscovery();
    await Future.delayed(const Duration(seconds: 15));
    if (mounted) {
      await ref.read(connectionStateProvider.notifier).stopDiscovery();
    }
  }

  Future<void> _autoConnect(Device device) async {
    await _connectToDevice(device);
  }

  Future<void> _connectToDevice(Device device) async {
    final result = await ref.read(connectionStateProvider.notifier).connect(device);
    
    if (!mounted) return;
    
    String message = '';
    NotificationType type = NotificationType.success;
    
    result.when(
      success: (_) {
        message = 'Connected to ${device.name}';
        type = NotificationType.success;
      },
      failure: (msg, {exception}) {
        message = 'Failed to connect: $msg';
        type = NotificationType.error;
      },
    );
    
    _showTopNotification(context, message, type);
  }

  void _showTopNotification(BuildContext context, String message, NotificationType type) {
    final overlay = Overlay.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    
    Color bgColor;
    Color fgColor;
    IconData icon;
    
    switch (type) {
      case NotificationType.success:
        bgColor = Colors.green;
        fgColor = Colors.white;
        icon = Icons.check_circle;
        break;
      case NotificationType.error:
        bgColor = colorScheme.error;
        fgColor = colorScheme.onError;
        icon = Icons.error;
        break;
    }

    final entry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(icon, color: fgColor, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(color: fgColor),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 3), entry.remove);
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
        return 'Offline';
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

enum NotificationType { success, error }
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';
import '../chat/chat_page.dart';
import '../transfer/transfer_page.dart';
import '../settings/settings_page.dart';
import '../widgets/device_card.dart';
import '../widgets/connection_status.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await ref.read(connectionStateProvider.notifier).initialize();
  }

  @override
  Widget build(BuildContext context) {
    final connectionState = ref.watch(connectionStateProvider);
    final discoveredDevices = ref.watch(discoveredDevicesProvider);

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildHomeContent(connectionState, discoveredDevices),
          const ChatPage(),
          const TransferPage(),
          const SettingsPage(),
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

  Widget _buildHomeContent(
    ConnectionState connectionState,
    List<Device> discoveredDevices,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EchoLink'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _startDiscovery,
          ),
        ],
      ),
      body: Column(
        children: [
          ConnectionStatusWidget(state: connectionState),
          Expanded(
            child: _buildDeviceList(discoveredDevices, connectionState),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _startDiscovery,
        icon: const Icon(Icons.search),
        label: const Text('Discover Devices'),
      ),
    );
  }

  Widget _buildDeviceList(
    List<Device> devices,
    ConnectionState connectionState,
  ) {
    if (connectionState == ConnectionState.discovering) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Searching for nearby devices...'),
          ],
        ),
      );
    }

    if (devices.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.devices_other,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No devices found',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap "Discover Devices" to search',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: devices.length,
      itemBuilder: (context, index) {
        final device = devices[index];
        return DeviceCard(
          device: device,
          onTap: () => _connectToDevice(device),
        );
      },
    );
  }

  Future<void> _startDiscovery() async {
    await ref.read(connectionStateProvider.notifier).startDiscovery();
    
    await Future.delayed(const Duration(seconds: 5));
    
    await ref.read(connectionStateProvider.notifier).stopDiscovery();
  }

  Future<void> _connectToDevice(Device device) async {
    final result = await ref.read(connectionStateProvider.notifier).connect(device);
    
    if (!mounted) return;
    
    result.when(
      success: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connected to ${device.name}'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      },
      failure: (message, {exception}) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to connect: $message'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      },
    );
  }
}
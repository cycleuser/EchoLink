import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';
import '../../../domain/models/models.dart';
import '../../../infrastructure/network/cross_platform_network_service.dart';
import '../../widgets/toast_helper.dart';
import '../conversation/conversation_page.dart';
import '../settings/settings_page.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  bool _isInitialized = false;
  String _initError = '';
  bool _isDiscovering = false;
  StreamSubscription<Message>? _messageSubscription;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    try {
      final result =
          await ref.read(connectionStateProvider.notifier).initialize();

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
          _listenForMessages();
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

  void _listenForMessages() {
    _messageSubscription =
        CrossPlatformNetworkService().messageReceived.listen((message) {
      if (mounted) {
        ref.read(messageStoreProvider.notifier).addMessage(message);
        _showMessageNotification(message);
      }
    });
  }

  void _showMessageNotification(Message message) {
    final overlay = Overlay.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 60,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 300),
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
            child: GestureDetector(
              onTap: () {
                entry.remove();
                final devices = CrossPlatformNetworkService().connectedDevices;
                final device =
                    devices.where((d) => d.id == message.senderId).firstOrNull;
                if (device != null) {
                  _openConversation(device);
                }
              },
              child: Container(
                width: 280,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
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
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.message,
                        size: 20,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            message.senderName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            message.content.length > 30
                                ? '${message.content.substring(0, 30)}...'
                                : message.content,
                            style: TextStyle(
                              color: colorScheme.outline,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 3), entry.remove);
  }

  void _showConnectionRequestDialog(Device device) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('连接请求'),
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
              '想要连接到您的设备',
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
            child: const Text('拒绝'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              CrossPlatformNetworkService().acceptConnection();
            },
            child: const Text('接受'),
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

    final discoveredDevices = ref.watch(discoveredDevicesProvider);
    final connectedDevices = ref.watch(connectedDevicesNotifierProvider);
    final currentDevice = ref.watch(currentDeviceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('EchoLink'),
        actions: [
          IconButton(
            icon: Icon(_isDiscovering ? Icons.stop : Icons.refresh),
            onPressed: _isDiscovering ? _stopDiscovery : _startDiscovery,
            tooltip: _isDiscovering ? '停止扫描' : '扫描设备',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ),
          ),
        ],
      ),
      body: _buildContactsList(
          discoveredDevices, connectedDevices, currentDevice),
      floatingActionButton: _isDiscovering
          ? FloatingActionButton.extended(
              onPressed: _stopDiscovery,
              icon: const Icon(Icons.stop),
              label: const Text('停止扫描'),
              backgroundColor: Theme.of(context).colorScheme.error,
            )
          : FloatingActionButton.extended(
              onPressed: _startDiscovery,
              icon: const Icon(Icons.search),
              label: const Text('扫描设备'),
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
                '正在初始化网络...',
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
                  label: const Text('重试'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactsList(
    List<Device> discoveredDevices,
    List<Device> connectedDevices,
    Device? currentDevice,
  ) {
    final allContacts = <Device>[...connectedDevices];

    for (final device in discoveredDevices) {
      if (!allContacts.any((d) => d.id == device.id)) {
        allContacts.add(device);
      }
    }

    return ListView(
      children: [
        if (currentDevice != null) _buildMyDeviceSection(currentDevice),
        if (connectedDevices.isNotEmpty) ...[
          _buildSectionHeader(
              '已连接 (${connectedDevices.length})', Icons.link, Colors.green),
          ...connectedDevices
              .map((d) => _buildContactTile(d, isConnected: true)),
          const Divider(height: 32),
        ],
        if (_isDiscovering)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 12),
                Text('正在扫描附近设备...'),
              ],
            ),
          ),
        if (discoveredDevices
            .where((d) => !connectedDevices.any((c) => c.id == d.id))
            .isNotEmpty) ...[
          _buildSectionHeader(
              '附近设备', Icons.near_me, Theme.of(context).colorScheme.primary),
          ...discoveredDevices
              .where((d) => !connectedDevices.any((c) => c.id == d.id))
              .map((d) => _buildContactTile(d, isConnected: false)),
        ],
        if (allContacts.isEmpty && !_isDiscovering) _buildEmptyState(),
      ],
    );
  }

  Widget _buildMyDeviceSection(Device device) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getPlatformIcon(device.platform),
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '我的设备',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  device.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${device.ipAddress}:${device.port}',
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
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactTile(Device device, {required bool isConnected}) {
    final unreadCount =
        isConnected ? ref.watch(unreadCountProvider(device.id)) : 0;
    final lastMessage = isConnected
        ? ref.watch(deviceMessagesProvider(device.id)).lastOrNull
        : null;

    return ListTile(
      leading: Stack(
        children: [
          CircleAvatar(
            backgroundColor: isConnected
                ? Colors.green.withOpacity(0.2)
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Icon(
              _getPlatformIcon(device.platform),
              color: isConnected
                  ? Colors.green
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
          if (isConnected)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Theme.of(context).colorScheme.surface, width: 2),
                ),
              ),
            ),
        ],
      ),
      title: Row(
        children: [
          Text(
            device.name,
            style: TextStyle(
              fontWeight: isConnected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          if (unreadCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.error,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(
        lastMessage != null
            ? lastMessage.content.length > 20
                ? '${lastMessage.content.substring(0, 20)}...'
                : lastMessage.content
            : (isConnected
                ? '已连接 · ${device.ipAddress}'
                : device.ipAddress ?? '未知地址'),
        style: Theme.of(context).textTheme.bodySmall,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: isConnected
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (lastMessage != null)
                  Text(
                    _formatTime(lastMessage.timestamp),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                IconButton(
                  icon: const Icon(Icons.link_off),
                  onPressed: () => _disconnectDevice(device.id),
                  tooltip: '断开连接',
                ),
              ],
            )
          : TextButton(
              onPressed: () => _connectToDevice(device),
              child: const Text('连接'),
            ),
      onTap: isConnected ? () => _openConversation(device) : null,
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    if (now.year == time.year &&
        now.month == time.month &&
        now.day == time.day) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
    return '${time.month}/${time.day}';
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 80,
            color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
          ),
          const SizedBox(height: 24),
          Text(
            '暂无设备',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击下方按钮扫描附近设备',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ],
      ),
    );
  }

  Future<void> _startDiscovery() async {
    setState(() => _isDiscovering = true);
    await ref.read(connectionStateProvider.notifier).startDiscovery();
  }

  Future<void> _stopDiscovery() async {
    await ref.read(connectionStateProvider.notifier).stopDiscovery();
    setState(() => _isDiscovering = false);
  }

  Future<void> _connectToDevice(Device device) async {
    _showToast('正在连接 ${device.name}...');
    final result =
        await ref.read(connectionStateProvider.notifier).connect(device);

    if (!mounted) return;

    result.when(
      success: (_) {
        _showToast('已连接到 ${device.name}', isSuccess: true);
      },
      failure: (message, {exception}) {
        _showToast('连接失败: $message', isSuccess: false);
      },
    );
  }

  void _disconnectDevice(String deviceId) {
    ref.read(connectionStateProvider.notifier).disconnect(deviceId);
    _showToast('已断开连接');
  }

  void _openConversation(Device device) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ConversationPage(device: device),
      ),
    );
  }

  void _showToast(String message, {bool isSuccess = true}) {
    ToastHelper.show(
      context,
      message: message,
      type: isSuccess ? ToastType.success : ToastType.error,
    );
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

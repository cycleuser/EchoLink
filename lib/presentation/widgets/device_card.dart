import 'package:flutter/material.dart';
import '../../../domain/models/models.dart';

class DeviceCard extends StatelessWidget {
  final Device device;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const DeviceCard({
    super.key,
    required this.device,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _buildDeviceIcon(context),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.displayName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getDeviceSubtitle(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                  ],
                ),
              ),
              _buildStatusBadge(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceIcon(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        _getPlatformIcon(),
        color: Theme.of(context).colorScheme.onPrimaryContainer,
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context) {
    Color badgeColor;
    String statusText;

    switch (device.status) {
      case DeviceStatus.connected:
        badgeColor = Theme.of(context).colorScheme.primary;
        statusText = 'Connected';
      case DeviceStatus.connecting:
        badgeColor = Theme.of(context).colorScheme.secondary;
        statusText = 'Connecting';
      case DeviceStatus.discovering:
        badgeColor = Theme.of(context).colorScheme.tertiary;
        statusText = 'Visible';
      case DeviceStatus.disconnected:
        badgeColor = Theme.of(context).colorScheme.outline;
        statusText = 'Available';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: badgeColor.withOpacity(0.3)),
      ),
      child: Text(
        statusText,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: badgeColor,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  IconData _getPlatformIcon() {
    switch (device.platform) {
      case DevicePlatform.android:
        return Icons.phone_android;
      case DevicePlatform.ios:
        return Icons.phone_iphone;
      case DevicePlatform.unknown:
        return Icons.devices;
    }
  }

  String _getDeviceSubtitle() {
    final parts = <String>[];

    if (device.platform == DevicePlatform.android) {
      parts.add('Android');
    } else if (device.platform == DevicePlatform.ios) {
      parts.add('iOS');
    }

    if (device.connectionType != null) {
      parts.add(_getConnectionTypeText(device.connectionType!));
    }

    return parts.isEmpty ? 'Unknown device' : parts.join(' • ');
  }

  String _getConnectionTypeText(ConnectionType type) {
    switch (type) {
      case ConnectionType.wifiDirect:
        return 'Wi-Fi Direct';
      case ConnectionType.multipeer:
        return 'Multipeer';
      case ConnectionType.hotspot:
        return 'Hotspot';
      case ConnectionType.wifiAware:
        return 'Wi-Fi Aware';
    }
  }
}
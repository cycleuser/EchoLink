import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';
import '../../../domain/models/models.dart';
import '../../../infrastructure/network/cross_platform_network_service.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _notificationsEnabled = true;

  @override
  Widget build(BuildContext context) {
    final currentDevice = ref.watch(currentDeviceProvider);
    final themeMode = ref.watch(themeModeProvider);
    final allowAutoConnect = ref.watch(allowAutoConnectProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          _buildDeviceSection(currentDevice),
          const SizedBox(height: 8),
          _buildConnectionSection(allowAutoConnect),
          const SizedBox(height: 8),
          _buildAppearanceSection(themeMode),
          const SizedBox(height: 8),
          _buildAboutSection(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildDeviceSection(Device? device) {
    return _buildSection(
      title: 'This Device',
      icon: Icons.devices,
      children: [
        ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getPlatformIcon(device?.platform),
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          title: Text(device?.name ?? 'Unknown'),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_getPlatformName(device?.platform)),
              if (device != null)
                Text(
                  '${device.ipAddress}:${device.port}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
            ],
          ),
          isThreeLine: device != null,
        ),
      ],
    );
  }

  Widget _buildConnectionSection(bool allowAutoConnect) {
    return _buildSection(
      title: 'Connection',
      icon: Icons.link,
      children: [
        SwitchListTile(
          title: const Text('Allow Auto Connect'),
          subtitle: Text(
            allowAutoConnect 
                ? 'Others can connect without approval'
                : 'Others need your approval to connect',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: allowAutoConnect 
                  ? Colors.green 
                  : Theme.of(context).colorScheme.outline,
            ),
          ),
          value: allowAutoConnect,
          onChanged: (value) {
            ref.read(allowAutoConnectProvider.notifier).state = value;
            CrossPlatformNetworkService().setAllowAutoConnect(value);
          },
        ),
        ListTile(
          leading: Icon(
            allowAutoConnect ? Icons.lock_open : Icons.lock,
            color: allowAutoConnect ? Colors.green : Colors.orange,
          ),
          title: Text(
            allowAutoConnect ? 'Open Mode' : 'Protected Mode',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          subtitle: Text(
            allowAutoConnect
                ? 'Any nearby device can connect automatically'
                : 'You will be asked to approve connection requests',
          ),
        ),
        SwitchListTile(
          title: const Text('Notifications'),
          subtitle: const Text('Show alerts for new messages'),
          value: _notificationsEnabled,
          onChanged: (value) => setState(() => _notificationsEnabled = value),
        ),
      ],
    );
  }

  Widget _buildAppearanceSection(ThemeMode themeMode) {
    return _buildSection(
      title: 'Appearance',
      icon: Icons.palette,
      children: [
        SegmentedButton<ThemeMode>(
          segments: const [
            ButtonSegment(
              value: ThemeMode.system,
              label: Text('System'),
              icon: Icon(Icons.settings_suggest),
            ),
            ButtonSegment(
              value: ThemeMode.light,
              label: Text('Light'),
              icon: Icon(Icons.light_mode),
            ),
            ButtonSegment(
              value: ThemeMode.dark,
              label: Text('Dark'),
              icon: Icon(Icons.dark_mode),
            ),
          ],
          selected: {themeMode},
          onSelectionChanged: (Set<ThemeMode> selection) {
            ref.read(themeModeProvider.notifier).setThemeMode(selection.first);
          },
        ),
      ],
    );
  }

  Widget _buildAboutSection() {
    return _buildSection(
      title: 'About',
      icon: Icons.info_outline,
      children: [
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text('Version'),
          subtitle: const Text('1.0.0'),
          trailing: Text(
            'Build ${DateTime.now().year}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        ListTile(
          leading: const Icon(Icons.code),
          title: const Text('Open Source'),
          subtitle: const Text('GPLv3 License'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showLicenseDialog(),
        ),
        ListTile(
          leading: const Icon(Icons.privacy_tip_outlined),
          title: const Text('Privacy Policy'),
          subtitle: const Text('No data collected'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showPrivacyDialog(),
        ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 16, bottom: 8),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Card(
            margin: EdgeInsets.zero,
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  void _showLicenseDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Open Source License'),
        content: const SingleChildScrollView(
          child: Text(
            'EchoLink is open source software released under the GNU General Public License v3.0.\n\n'
            'You are free to use, modify, and distribute this software under the terms of the GPL v3 license.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showPrivacyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: const SingleChildScrollView(
          child: Text(
            'EchoLink Privacy Policy\n\n'
            '• No data is collected or transmitted to external servers\n'
            '• All communication happens directly between your devices\n'
            '• Your messages and files stay on your local network\n'
            '• No analytics, tracking, or advertising\n\n'
            'Your privacy is our priority.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
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

  String _getPlatformName(DevicePlatform? platform) {
    switch (platform) {
      case DevicePlatform.android:
        return 'Android';
      case DevicePlatform.ios:
        return 'iOS';
      case DevicePlatform.macos:
        return 'macOS';
      default:
        return 'Unknown Platform';
    }
  }
}
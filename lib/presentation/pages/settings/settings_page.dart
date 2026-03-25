import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';
import '../../../domain/models/models.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _deviceNameController = TextEditingController();
  bool _notificationsEnabled = true;
  bool _autoDiscovery = true;
  String _themeMode = 'system';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _deviceNameController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    _deviceNameController.text = 'EchoLink Device';
  }

  @override
  Widget build(BuildContext context) {
    final currentDevice = ref.watch(currentDeviceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          _buildProfileSection(currentDevice),
          const Divider(),
          _buildNetworkSection(),
          const Divider(),
          _buildAppearanceSection(),
          const Divider(),
          _buildAboutSection(),
        ],
      ),
    );
  }

  Widget _buildProfileSection(currentDevice) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Device',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _deviceNameController,
            decoration: const InputDecoration(
              labelText: 'Device Name',
              prefixIcon: Icon(Icons.devices),
            ),
            onSubmitted: (_) => _saveDeviceName(),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.person),
            ),
            title: Text(currentDevice?.name ?? 'Unknown'),
            subtitle: Text(
              currentDevice?.platform == DevicePlatform.android
                  ? 'Android Device'
                  : currentDevice?.platform == DevicePlatform.ios
                      ? 'iOS Device'
                      : 'Unknown Platform',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNetworkSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Network',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          SwitchListTile(
            title: const Text('Auto Discovery'),
            subtitle: const Text('Automatically discover nearby devices'),
            value: _autoDiscovery,
            onChanged: (value) {
              setState(() {
                _autoDiscovery = value;
              });
            },
          ),
          SwitchListTile(
            title: const Text('Notifications'),
            subtitle: const Text('Show notifications for new messages'),
            value: _notificationsEnabled,
            onChanged: (value) {
              setState(() {
                _notificationsEnabled = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAppearanceSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Appearance',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          RadioListTile<String>(
            title: const Text('System Default'),
            value: 'system',
            groupValue: _themeMode,
            onChanged: (value) {
              setState(() {
                _themeMode = value!;
              });
            },
          ),
          RadioListTile<String>(
            title: const Text('Light'),
            value: 'light',
            groupValue: _themeMode,
            onChanged: (value) {
              setState(() {
                _themeMode = value!;
              });
            },
          ),
          RadioListTile<String>(
            title: const Text('Dark'),
            value: 'dark',
            groupValue: _themeMode,
            onChanged: (value) {
              setState(() {
                _themeMode = value!;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'About',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Version'),
            subtitle: const Text('1.0.0'),
          ),
          ListTile(
            leading: const Icon(Icons.code),
            title: const Text('Open Source'),
            subtitle: const Text('GPLv3 License'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () {},
          ),
        ],
      ),
    );
  }

  void _saveDeviceName() {
    final name = _deviceNameController.text.trim();
    if (name.isEmpty) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Device name saved')),
    );
  }
}
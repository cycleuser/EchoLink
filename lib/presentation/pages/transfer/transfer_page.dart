import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';

class TransferPage extends ConsumerWidget {
  const TransferPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionState = ref.watch(connectionStateProvider);
    final transferState = ref.watch(transferProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('File Transfer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {},
          ),
        ],
      ),
      body: connectionState.isConnected
          ? _buildTransferContent(context, ref, transferState)
          : _buildEmptyState(context),
      floatingActionButton: connectionState.isConnected
          ? FloatingActionButton.extended(
              onPressed: () => _pickFile(context, ref),
              icon: const Icon(Icons.attach_file),
              label: const Text('Send File'),
            )
          : null,
    );
  }

  Widget _buildTransferContent(
    BuildContext context,
    WidgetRef ref,
    TransferState transferState,
  ) {
    if (transferState.transfers.isEmpty) {
      return _buildNoTransfers(context);
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        if (transferState.activeTransfers.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Active Transfers',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ),
          ...transferState.activeTransfers.map(
            (transfer) => TransferProgressWidget(
              transfer: transfer,
              onPause: () => _pauseTransfer(ref, transfer.id),
              onResume: () => _resumeTransfer(ref, transfer.id),
              onCancel: () => _cancelTransfer(context, ref, transfer.id),
            ),
          ),
        ],
        if (transferState.completedTransfers.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Completed',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ),
          ...transferState.completedTransfers.map(
            (transfer) => TransferProgressWidget(
              transfer: transfer,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildNoTransfers(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.folder_open,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No transfers yet',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Tap "Send File" to start a transfer',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.wifi_off,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No device connected',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Connect to a device to transfer files',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFile(BuildContext context, WidgetRef ref) async {
    try {
      final result = await FilePicker.platform.pickFiles();

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        
        if (file.path != null) {
          final connectionState = ref.read(connectionStateProvider);
          final devices = ref.read(discoveredDevicesProvider);
          final connectedDevice = devices.firstWhere(
            (d) => d.status == DeviceStatus.connected,
            orElse: () => throw Exception('No connected device'),
          );

          await ref.read(transferProvider.notifier).sendFile(
                receiverId: connectedDevice.id,
                filePath: file.path!,
              );

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Sending ${file.name}...'),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send file: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _pauseTransfer(WidgetRef ref, String transferId) async {
    await ref.read(transferProvider.notifier).pauseTransfer(transferId);
  }

  Future<void> _resumeTransfer(WidgetRef ref, String transferId) async {
    await ref.read(transferProvider.notifier).resumeTransfer(transferId);
  }

  Future<void> _cancelTransfer(
    BuildContext context,
    WidgetRef ref,
    String transferId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Transfer'),
        content: const Text('Are you sure you want to cancel this transfer?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(transferProvider.notifier).cancelTransfer(transferId);
    }
  }
}
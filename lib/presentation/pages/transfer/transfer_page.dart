import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';
import '../../../domain/models/models.dart';
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
      body: connectionState == EchoLinkConnectionState.connected
          ? _buildTransferContent(context, ref, transferState)
          : _buildEmptyState(context),
      floatingActionButton: connectionState == EchoLinkConnectionState.connected
          ? FloatingActionButton.extended(
              onPressed: () => _sendTestFile(context, ref),
              icon: const Icon(Icons.attach_file),
              label: const Text('Send Test File'),
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
      return _buildNoTransfers(context, ref);
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
            (transfer) => TransferProgressWidget(transfer: transfer),
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
            (transfer) => TransferProgressWidget(transfer: transfer),
          ),
        ],
      ],
    );
  }

  Widget _buildNoTransfers(BuildContext context, WidgetRef ref) {
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
            'Tap "Send Test File" to test file transfer',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _sendTestFile(context, ref),
            icon: const Icon(Icons.send),
            label: const Text('Send Test File'),
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

  Future<void> _sendTestFile(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(transferProvider.notifier).sendTestFile();

      if (context.mounted) {
        ToastHelper.success(context, 'Test file sent!');
      }
    } catch (e) {
      if (context.mounted) {
        ToastHelper.error(context, 'Failed to send file: $e');
      }
    }
  }
}

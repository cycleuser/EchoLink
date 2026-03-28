import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../providers/providers.dart';
import '../../../domain/models/models.dart';
import '../../widgets/widgets.dart';

class TransferPage extends ConsumerWidget {
  const TransferPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectedDevices = ref.watch(connectedDevicesNotifierProvider);
    final transferState = ref.watch(transferProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('文件传输'),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder),
            onPressed: () => _openReceivedFolder(context),
            tooltip: '打开接收文件夹',
          ),
        ],
      ),
      body: connectedDevices.isEmpty
          ? _buildNoDeviceState(context)
          : _buildTransferContent(
              context, ref, transferState, connectedDevices),
    );
  }

  Widget _buildTransferContent(
    BuildContext context,
    WidgetRef ref,
    TransferState transferState,
    List<Device> connectedDevices,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color:
              Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
          child: Row(
            children: [
              Icon(Icons.devices, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '已连接 ${connectedDevices.length} 台设备',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () =>
                    _pickAndSendFile(context, ref, connectedDevices),
                icon: const Icon(Icons.attach_file),
                label: const Text('发送文件'),
              ),
            ],
          ),
        ),
        Expanded(
          child: transferState.transfers.isEmpty
              ? _buildNoTransfers(context)
              : _buildTransferList(context, transferState),
        ),
      ],
    );
  }

  Widget _buildTransferList(BuildContext context, TransferState transferState) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (transferState.activeTransfers.isNotEmpty) ...[
          Text(
            '传输中',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          const SizedBox(height: 8),
          ...transferState.activeTransfers.map(
            (transfer) => _buildTransferCard(context, transfer),
          ),
          const SizedBox(height: 16),
        ],
        if (transferState.completedTransfers.isNotEmpty) ...[
          Text(
            '已完成',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 8),
          ...transferState.completedTransfers.map(
            (transfer) => _buildTransferCard(context, transfer),
          ),
        ],
      ],
    );
  }

  Widget _buildTransferCard(BuildContext context, FileTransfer transfer) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: transfer.direction == TransferDirection.send
                ? Theme.of(context).colorScheme.primaryContainer
                : Theme.of(context).colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            transfer.direction == TransferDirection.send
                ? Icons.upload
                : Icons.download,
            color: transfer.direction == TransferDirection.send
                ? Theme.of(context).colorScheme.onPrimaryContainer
                : Theme.of(context).colorScheme.onSecondaryContainer,
          ),
        ),
        title: Text(
          transfer.fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(transfer.formattedFileSize),
            if (transfer.isInProgress)
              LinearProgressIndicator(
                value: transfer.progress,
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
          ],
        ),
        trailing: transfer.isCompleted
            ? const Icon(Icons.check_circle, color: Colors.green)
            : transfer.isFailed
                ? const Icon(Icons.error, color: Colors.red)
                : Text('${transfer.progressPercentage.toStringAsFixed(0)}%'),
      ),
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
            '暂无传输记录',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '点击上方「发送文件」按钮',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDeviceState(BuildContext context) {
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
            '未连接设备',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '请先连接设备再进行文件传输',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ],
      ),
    );
  }

  void _pickAndSendFile(
    BuildContext context,
    WidgetRef ref,
    List<Device> devices,
  ) async {
    try {
      final result = await FilePicker.platform.pickFiles();
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.path == null) {
        ToastHelper.error(context, '无法访问文件');
        return;
      }

      final fileSize = await File(file.path!).length();

      for (final device in devices) {
        ToastHelper.info(context, '正在发送到 ${device.name}: ${file.name}');

        await ref.read(transferProvider.notifier).sendFile(
              filePath: file.path!,
              fileName: file.name,
              fileSize: fileSize,
              deviceId: device.id,
            );
      }

      ToastHelper.success(context, '文件已发送');
    } catch (e) {
      ToastHelper.error(context, '发送失败: $e');
    }
  }

  void _openReceivedFolder(BuildContext context) {
    ToastHelper.info(context, '文件保存在应用文档目录的 EchoLink 文件夹中');
  }
}

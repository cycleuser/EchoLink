import 'package:flutter/material.dart';
import '../../../domain/models/models.dart';

class TransferProgressWidget extends StatelessWidget {
  final FileTransfer transfer;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onCancel;

  const TransferProgressWidget({
    super.key,
    required this.transfer,
    this.onPause,
    this.onResume,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildFileIcon(context),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transfer.fileName,
                        style: Theme.of(context).textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${transfer.formattedBytesTransferred} / ${transfer.formattedFileSize}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                      ),
                    ],
                  ),
                ),
                _buildStatusIcon(context),
              ],
            ),
            const SizedBox(height: 12),
            _buildProgressBar(context),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _getStatusText(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _getStatusColor(context),
                        fontWeight: FontWeight.w500,
                      ),
                ),
                if (transfer.isActive) _buildActionButtons(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileIcon(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        _getFileIcon(),
        color: Theme.of(context).colorScheme.onPrimaryContainer,
        size: 24,
      ),
    );
  }

  Widget _buildStatusIcon(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: _getStatusColor(context).withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        _getStatusBadgeIcon(),
        color: _getStatusColor(context),
        size: 18,
      ),
    );
  }

  Widget _buildProgressBar(BuildContext context) {
    return Column(
      children: [
        LinearProgressIndicator(
          value: transfer.progress,
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          valueColor: AlwaysStoppedAnimation<Color>(
            _getStatusColor(context),
          ),
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${transfer.progressPercentage.toStringAsFixed(1)}%',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            if (transfer.estimatedTimeRemaining != null)
              Text(
                _formatDuration(transfer.estimatedTimeRemaining!),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (transfer.isInProgress && onPause != null)
          IconButton(
            icon: const Icon(Icons.pause),
            onPressed: onPause,
            iconSize: 20,
            visualDensity: VisualDensity.compact,
          ),
        if (transfer.isPaused && onResume != null)
          IconButton(
            icon: const Icon(Icons.play_arrow),
            onPressed: onResume,
            iconSize: 20,
            visualDensity: VisualDensity.compact,
          ),
        if (onCancel != null)
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: onCancel,
            iconSize: 20,
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }

  IconData _getFileIcon() {
    if (transfer.isReceiving) {
      return Icons.download;
    }
    return Icons.upload_file;
  }

  IconData _getStatusBadgeIcon() {
    switch (transfer.status) {
      case TransferStatus.pending:
        return Icons.schedule;
      case TransferStatus.preparing:
        return Icons.hourglass_empty;
      case TransferStatus.inProgress:
        return Icons.sync;
      case TransferStatus.paused:
        return Icons.pause;
      case TransferStatus.completed:
        return Icons.check;
      case TransferStatus.failed:
        return Icons.error;
      case TransferStatus.cancelled:
        return Icons.cancel;
    }
  }

  Color _getStatusColor(BuildContext context) {
    switch (transfer.status) {
      case TransferStatus.pending:
      case TransferStatus.preparing:
        return Theme.of(context).colorScheme.tertiary;
      case TransferStatus.inProgress:
        return Theme.of(context).colorScheme.primary;
      case TransferStatus.paused:
        return Theme.of(context).colorScheme.secondary;
      case TransferStatus.completed:
        return Theme.of(context).colorScheme.primary;
      case TransferStatus.failed:
        return Theme.of(context).colorScheme.error;
      case TransferStatus.cancelled:
        return Theme.of(context).colorScheme.outline;
    }
  }

  String _getStatusText() {
    switch (transfer.status) {
      case TransferStatus.pending:
        return 'Waiting...';
      case TransferStatus.preparing:
        return 'Preparing...';
      case TransferStatus.inProgress:
        return transfer.isSending ? 'Sending...' : 'Receiving...';
      case TransferStatus.paused:
        return 'Paused';
      case TransferStatus.completed:
        return 'Completed';
      case TransferStatus.failed:
        return transfer.errorMessage ?? 'Failed';
      case TransferStatus.cancelled:
        return 'Cancelled';
    }
  }

  String _formatDuration(Duration duration) {
    if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m remaining';
    }
    return '${duration.inSeconds}s remaining';
  }
}
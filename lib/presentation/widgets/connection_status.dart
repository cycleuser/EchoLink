import 'package:flutter/material.dart';
import '../../../domain/models/models.dart';

class ConnectionStatusWidget extends StatelessWidget {
  final EchoLinkConnectionState state;

  const ConnectionStatusWidget({
    super.key,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _getBackgroundColor(context),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _getIcon(),
            color: _getForegroundColor(context),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _getTitle(),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: _getForegroundColor(context),
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Text(
                  _getSubtitle(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _getForegroundColor(context).withOpacity(0.8),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getBackgroundColor(BuildContext context) {
    switch (state) {
      case EchoLinkConnectionState.connected:
        return Theme.of(context).colorScheme.primaryContainer;
      case EchoLinkConnectionState.connecting:
        return Theme.of(context).colorScheme.secondaryContainer;
      case EchoLinkConnectionState.discovering:
        return Theme.of(context).colorScheme.tertiaryContainer;
      case EchoLinkConnectionState.disconnected:
        return Theme.of(context).colorScheme.surfaceContainerHighest;
      case EchoLinkConnectionState.error:
        return Theme.of(context).colorScheme.errorContainer;
    }
  }

  Color _getForegroundColor(BuildContext context) {
    switch (state) {
      case EchoLinkConnectionState.connected:
        return Theme.of(context).colorScheme.onPrimaryContainer;
      case EchoLinkConnectionState.connecting:
        return Theme.of(context).colorScheme.onSecondaryContainer;
      case EchoLinkConnectionState.discovering:
        return Theme.of(context).colorScheme.onTertiaryContainer;
      case EchoLinkConnectionState.disconnected:
        return Theme.of(context).colorScheme.onSurfaceVariant;
      case EchoLinkConnectionState.error:
        return Theme.of(context).colorScheme.onErrorContainer;
    }
  }

  IconData _getIcon() {
    switch (state) {
      case EchoLinkConnectionState.connected:
        return Icons.wifi;
      case EchoLinkConnectionState.connecting:
        return Icons.wifi_lock;
      case EchoLinkConnectionState.discovering:
        return Icons.wifi_find;
      case EchoLinkConnectionState.disconnected:
        return Icons.wifi_off;
      case EchoLinkConnectionState.error:
        return Icons.error_outline;
    }
  }

  String _getTitle() {
    switch (state) {
      case EchoLinkConnectionState.connected:
        return 'Connected';
      case EchoLinkConnectionState.connecting:
        return 'Connecting...';
      case EchoLinkConnectionState.discovering:
        return 'Discovering...';
      case EchoLinkConnectionState.disconnected:
        return 'Disconnected';
      case EchoLinkConnectionState.error:
        return 'Connection Error';
    }
  }

  String _getSubtitle() {
    switch (state) {
      case EchoLinkConnectionState.connected:
        return 'Ready to communicate';
      case EchoLinkConnectionState.connecting:
        return 'Please wait';
      case EchoLinkConnectionState.discovering:
        return 'Searching for nearby devices';
      case EchoLinkConnectionState.disconnected:
        return 'Tap discover to find devices';
      case EchoLinkConnectionState.error:
        return 'Please try again';
    }
  }
}
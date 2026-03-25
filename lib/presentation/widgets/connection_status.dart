import 'package:flutter/material.dart';
import '../../providers/providers.dart';

class ConnectionStatusWidget extends StatelessWidget {
  final ConnectionState state;

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
      case ConnectionState.connected:
        return Theme.of(context).colorScheme.primaryContainer;
      case ConnectionState.connecting:
        return Theme.of(context).colorScheme.secondaryContainer;
      case ConnectionState.discovering:
        return Theme.of(context).colorScheme.tertiaryContainer;
      case ConnectionState.disconnected:
        return Theme.of(context).colorScheme.surfaceContainerHighest;
      case ConnectionState.error:
        return Theme.of(context).colorScheme.errorContainer;
    }
  }

  Color _getForegroundColor(BuildContext context) {
    switch (state) {
      case ConnectionState.connected:
        return Theme.of(context).colorScheme.onPrimaryContainer;
      case ConnectionState.connecting:
        return Theme.of(context).colorScheme.onSecondaryContainer;
      case ConnectionState.discovering:
        return Theme.of(context).colorScheme.onTertiaryContainer;
      case ConnectionState.disconnected:
        return Theme.of(context).colorScheme.onSurfaceVariant;
      case ConnectionState.error:
        return Theme.of(context).colorScheme.onErrorContainer;
    }
  }

  IconData _getIcon() {
    switch (state) {
      case ConnectionState.connected:
        return Icons.wifi;
      case ConnectionState.connecting:
        return Icons.wifi_lock;
      case ConnectionState.discovering:
        return Icons.wifi_find;
      case ConnectionState.disconnected:
        return Icons.wifi_off;
      case ConnectionState.error:
        return Icons.error_outline;
    }
  }

  String _getTitle() {
    switch (state) {
      case ConnectionState.connected:
        return 'Connected';
      case ConnectionState.connecting:
        return 'Connecting...';
      case ConnectionState.discovering:
        return 'Discovering...';
      case ConnectionState.disconnected:
        return 'Disconnected';
      case ConnectionState.error:
        return 'Connection Error';
    }
  }

  String _getSubtitle() {
    switch (state) {
      case ConnectionState.connected:
        return 'Ready to communicate';
      case ConnectionState.connecting:
        return 'Please wait';
      case ConnectionState.discovering:
        return 'Searching for nearby devices';
      case ConnectionState.disconnected:
        return 'Tap discover to find devices';
      case ConnectionState.error:
        return 'Please try again';
    }
  }
}
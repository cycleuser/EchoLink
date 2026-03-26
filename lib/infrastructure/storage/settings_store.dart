import '../../domain/models/models.dart';
import '../../core/result.dart';
import '../../core/constants.dart';
import '../../core/utils/logger.dart';

class MessageStore {
  final Map<String, Map<String, dynamic>> _messages = {};

  Future<Result<void>> initialize() async {
    AppLogger.info('Message store initialized');
    return const Success(null);
  }

  Future<Result<void>> saveMessage(Message message) async {
    try {
      final key = '${message.senderId}_${message.id}';
      _messages[key] = message.toJson();
      return const Success(null);
    } catch (e) {
      AppLogger.error('Failed to save message', e);
      return Failure(e.toString());
    }
  }

  Future<Result<List<Message>>> getMessages(String deviceId) async {
    try {
      final messages = <Message>[];

      for (final entry in _messages.entries) {
        if (entry.key.startsWith(deviceId)) {
          messages.add(Message.fromJson(entry.value));
        }
      }

      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return Success(messages);
    } catch (e) {
      AppLogger.error('Failed to get messages', e);
      return Failure(e.toString());
    }
  }

  Future<Result<void>> deleteMessage(String messageId) async {
    try {
      _messages.removeWhere((key, value) => value['id'] == messageId);
      return const Success(null);
    } catch (e) {
      AppLogger.error('Failed to delete message', e);
      return Failure(e.toString());
    }
  }

  Future<Result<void>> clearMessages(String deviceId) async {
    try {
      _messages.removeWhere((key, _) => key.startsWith(deviceId));
      return const Success(null);
    } catch (e) {
      AppLogger.error('Failed to clear messages', e);
      return Failure(e.toString());
    }
  }

  Future<void> dispose() async {
    _messages.clear();
  }
}

class SettingsStore {
  String _deviceName = 'EchoLink Device';
  bool _notificationsEnabled = true;
  final List<String> _lastConnectedDevices = [];

  Future<Result<void>> initialize() async {
    AppLogger.info('Settings store initialized');
    return const Success(null);
  }

  Future<Result<String>> getDeviceName() async {
    return Success(_deviceName);
  }

  Future<Result<void>> setDeviceName(String name) async {
    _deviceName = name;
    return const Success(null);
  }

  Future<Result<bool>> isNotificationsEnabled() async {
    return Success(_notificationsEnabled);
  }

  Future<Result<void>> setNotificationsEnabled(bool enabled) async {
    _notificationsEnabled = enabled;
    return const Success(null);
  }

  Future<Result<List<String>>> getLastConnectedDevices() async {
    return Success(List.from(_lastConnectedDevices));
  }

  Future<Result<void>> addLastConnectedDevice(String deviceId) async {
    _lastConnectedDevices.remove(deviceId);
    _lastConnectedDevices.insert(0, deviceId);
    
    if (_lastConnectedDevices.length > 10) {
      _lastConnectedDevices.removeRange(10, _lastConnectedDevices.length);
    }
    
    return const Success(null);
  }

  Future<void> dispose() async {
    _lastConnectedDevices.clear();
  }
}
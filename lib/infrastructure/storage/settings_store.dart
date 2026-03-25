import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../domain/models/models.dart';
import '../../core/result.dart';
import '../../core/constants.dart';
import '../../core/utils/logger.dart';

class MessageStore {
  static const String _boxName = 'messages';
  Box<dynamic>? _box;

  Future<Result<void>> initialize() async {
    try {
      _box = await Hive.openBox(_boxName);
      AppLogger.info('Message store initialized');
      return const Success(null);
    } catch (e) {
      AppLogger.error('Failed to initialize message store', e);
      return Failure(e.toString());
    }
  }

  Future<Result<void>> saveMessage(Message message) async {
    try {
      final key = '${message.senderId}_${message.id}';
      await _box?.put(key, message.toJson());
      return const Success(null);
    } catch (e) {
      AppLogger.error('Failed to save message', e);
      return Failure(e.toString());
    }
  }

  Future<Result<List<Message>>> getMessages(String deviceId) async {
    try {
      final messages = <Message>[];
      final keys = _box?.keys.toList() ?? [];

      for (final key in keys) {
        if (key.toString().startsWith(deviceId)) {
          final data = _box?.get(key);
          if (data != null) {
            messages.add(Message.fromJson(Map<String, dynamic>.from(data)));
          }
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
      final keys = _box?.keys.toList() ?? [];
      
      for (final key in keys) {
        final data = _box?.get(key);
        if (data != null && data['id'] == messageId) {
          await _box?.delete(key);
          break;
        }
      }
      
      return const Success(null);
    } catch (e) {
      AppLogger.error('Failed to delete message', e);
      return Failure(e.toString());
    }
  }

  Future<Result<void>> clearMessages(String deviceId) async {
    try {
      final keys = _box?.keys.toList() ?? [];
      
      for (final key in keys) {
        if (key.toString().startsWith(deviceId)) {
          await _box?.delete(key);
        }
      }
      
      return const Success(null);
    } catch (e) {
      AppLogger.error('Failed to clear messages', e);
      return Failure(e.toString());
    }
  }

  Future<void> dispose() async {
    await _box?.close();
  }
}

class SettingsStore {
  static const String _boxName = 'settings';
  Box<dynamic>? _box;

  Future<Result<void>> initialize() async {
    try {
      _box = await Hive.openBox(_boxName);
      AppLogger.info('Settings store initialized');
      return const Success(null);
    } catch (e) {
      AppLogger.error('Failed to initialize settings store', e);
      return Failure(e.toString());
    }
  }

  Future<Result<String>> getDeviceName() async {
    try {
      final name = _box?.get(StorageKeys.deviceName, defaultValue: 'EchoLink Device');
      return Success(name as String);
    } catch (e) {
      return Failure(e.toString());
    }
  }

  Future<Result<void>> setDeviceName(String name) async {
    try {
      await _box?.put(StorageKeys.deviceName, name);
      return const Success(null);
    } catch (e) {
      return Failure(e.toString());
    }
  }

  Future<Result<bool>> isNotificationsEnabled() async {
    try {
      final enabled = _box?.get(StorageKeys.notifications, defaultValue: true);
      return Success(enabled as bool);
    } catch (e) {
      return Failure(e.toString());
    }
  }

  Future<Result<void>> setNotificationsEnabled(bool enabled) async {
    try {
      await _box?.put(StorageKeys.notifications, enabled);
      return const Success(null);
    } catch (e) {
      return Failure(e.toString());
    }
  }

  Future<Result<List<String>>> getLastConnectedDevices() async {
    try {
      final devices = _box?.get(StorageKeys.lastConnectedDevices, defaultValue: <String>[]);
      return Success(List<String>.from(devices));
    } catch (e) {
      return Failure(e.toString());
    }
  }

  Future<Result<void>> addLastConnectedDevice(String deviceId) async {
    try {
      final devices = await getLastConnectedDevices();
      
      return devices.when(
        success: (list) async {
          list.remove(deviceId);
          list.insert(0, deviceId);
          
          if (list.length > 10) {
            list.removeRange(10, list.length);
          }
          
          await _box?.put(StorageKeys.lastConnectedDevices, list);
          return const Success(null);
        },
        failure: (message, {exception}) => Failure(message),
      );
    } catch (e) {
      return Failure(e.toString());
    }
  }

  Future<void> dispose() async {
    await _box?.close();
  }
}
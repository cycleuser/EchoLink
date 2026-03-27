import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/models.dart';
import '../../core/result.dart';
import '../../infrastructure/network/cross_platform_network_service.dart';
import '../../core/utils/logger.dart';
import 'connection_provider.dart';

class MessageStore extends StateNotifier<List<Message>> {
  static final MessageStore _instance = MessageStore._internal();
  factory MessageStore() => _instance;
  MessageStore._internal() : super([]);

  final _messageController = StreamController<Message>.broadcast();
  Stream<Message> get onMessage => _messageController.stream;

  void addMessage(Message message) {
    final exists = state.any((m) =>
        m.id == message.id ||
        (m.content == message.content &&
            m.timestamp.difference(message.timestamp).inSeconds.abs() < 2));

    if (!exists) {
      state = [...state, message];
      AppLogger.info('MessageStore: Added message, total: ${state.length}');
      _messageController.add(message);
    }
  }

  List<Message> getMessagesForDevice(String deviceId, String currentDeviceId) {
    final result = state.where((m) {
      final isSentByMe = m.senderId == currentDeviceId;
      if (isSentByMe) {
        return m.receiverId == deviceId || m.receiverId == null;
      } else {
        return m.senderId == deviceId;
      }
    }).toList();
    AppLogger.info(
        'getMessagesForDevice($deviceId): found ${result.length} messages');
    return result;
  }

  void clear() {
    state = [];
  }
}

class ChatState {
  final bool isLoading;
  final String? error;
  final String? selectedDeviceId;

  const ChatState({
    this.isLoading = false,
    this.error,
    this.selectedDeviceId,
  });

  ChatState copyWith({
    bool? isLoading,
    String? error,
    String? selectedDeviceId,
  }) {
    return ChatState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      selectedDeviceId: selectedDeviceId ?? this.selectedDeviceId,
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  final CrossPlatformNetworkService _networkService;
  final MessageStore _messageStore;

  ChatNotifier(this._networkService, this._messageStore)
      : super(const ChatState());

  void selectDevice(String? deviceId) {
    AppLogger.info('Selecting device: $deviceId');
    state = state.copyWith(selectedDeviceId: deviceId);
  }

  Future<Result<void>> sendTextMessage(String content,
      [String? deviceId]) async {
    if (content.isEmpty) {
      return Failure('Message cannot be empty');
    }

    final currentDevice = _networkService.getCurrentDevice();
    final message = Message(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}_${currentDevice.id.hashCode}',
      senderId: currentDevice.id,
      senderName: currentDevice.name,
      content: content,
      timestamp: DateTime.now(),
      status: MessageStatus.sending,
      receiverId: deviceId,
    );

    AppLogger.info('Sending message to $deviceId: $content');
    _messageStore.addMessage(message);

    final result = await _networkService.sendMessage(content, deviceId);

    result.when(
      success: (_) {
        AppLogger.info('Message sent successfully');
      },
      failure: (msg, {exception}) {
        AppLogger.error('Failed to send message: $msg');
      },
    );

    return result;
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

final messageStoreProvider =
    StateNotifierProvider<MessageStore, List<Message>>((ref) {
  return MessageStore();
});

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier(
    CrossPlatformNetworkService(),
    ref.watch(messageStoreProvider.notifier),
  );
});

final deviceMessagesProvider =
    Provider.family<List<Message>, String>((ref, deviceId) {
  final messages = ref.watch(messageStoreProvider);
  final currentDeviceId = CrossPlatformNetworkService().getCurrentDevice().id;

  final result = messages.where((m) {
    final isSentByMe = m.senderId == currentDeviceId;
    if (isSentByMe) {
      return m.receiverId == deviceId || m.receiverId == null;
    } else {
      return m.senderId == deviceId;
    }
  }).toList();

  AppLogger.info(
      'deviceMessagesProvider($deviceId): ${result.length} messages from ${messages.length} total');
  return result;
});

final unreadCountProvider = Provider.family<int, String>((ref, deviceId) {
  final messages = ref.watch(deviceMessagesProvider(deviceId));
  return messages.where((m) => m.senderId == deviceId).length;
});

final selectedDeviceProvider = Provider<Device?>((ref) {
  final selectedId = ref.watch(chatProvider).selectedDeviceId;
  final devices = ref.watch(connectedDevicesNotifierProvider);

  if (selectedId != null) {
    final found = devices.where((d) => d.id == selectedId).firstOrNull;
    if (found != null) return found;
  }

  return devices.isNotEmpty ? devices.first : null;
});

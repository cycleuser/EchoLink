import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/models.dart';
import '../../core/result.dart';
import '../../infrastructure/network/cross_platform_network_service.dart';
import 'connection_provider.dart';

class ChatState {
  final List<Message> messages;
  final bool isLoading;
  final String? error;
  final String? selectedDeviceId;

  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.error,
    this.selectedDeviceId,
  });

  ChatState copyWith({
    List<Message>? messages,
    bool? isLoading,
    String? error,
    String? selectedDeviceId,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      selectedDeviceId: selectedDeviceId ?? this.selectedDeviceId,
    );
  }

  List<Message> get messagesForSelectedDevice {
    if (selectedDeviceId == null) return messages;
    return messages
        .where((m) =>
            m.senderId == selectedDeviceId || m.receiverId == selectedDeviceId)
        .toList();
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  final CrossPlatformNetworkService _networkService;

  ChatNotifier(this._networkService) : super(const ChatState()) {
    _init();
  }

  void _init() {
    _networkService.messageReceived.listen(_onMessageReceived);
  }

  void selectDevice(String? deviceId) {
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

    if (!state.messages.any((m) => m.id == message.id)) {
      state = state.copyWith(messages: [...state.messages, message]);
    }

    final result = await _networkService.sendMessage(content, deviceId);

    result.when(
      success: (_) {
        final updatedMessages = state.messages.map((m) {
          if (m.id == message.id) {
            return m.copyWith(status: MessageStatus.sent);
          }
          return m;
        }).toList();
        state = state.copyWith(messages: updatedMessages);
      },
      failure: (msg, {exception}) {
        final updatedMessages = state.messages.map((m) {
          if (m.id == message.id) {
            return m.copyWith(status: MessageStatus.failed);
          }
          return m;
        }).toList();
        state = state.copyWith(messages: updatedMessages, error: msg);
      },
    );

    return result;
  }

  void _onMessageReceived(Message message) {
    final exists = state.messages.any((m) =>
        m.id == message.id ||
        (m.content == message.content &&
            m.timestamp.difference(message.timestamp).inSeconds.abs() < 2));

    if (!exists) {
      state = state.copyWith(messages: [...state.messages, message]);
    }
  }

  void clear() {
    state = const ChatState();
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier(CrossPlatformNetworkService());
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

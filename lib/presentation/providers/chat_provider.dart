import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/models.dart';
import '../../core/result.dart';
import '../../infrastructure/network/connection_manager.dart';
import '../../infrastructure/network/cross_platform_network_service.dart';
import 'connection_provider.dart';

class ChatState {
  final List<Message> messages;
  final bool isLoading;
  final String? error;

  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.error,
  });

  ChatState copyWith({
    List<Message>? messages,
    bool? isLoading,
    String? error,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
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

  Future<Result<void>> sendTextMessage(String content) async {
    if (content.isEmpty) {
      return Failure('Message cannot be empty');
    }

    final message = Message(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      senderId: _networkService.getCurrentDevice().id,
      senderName: _networkService.getCurrentDevice().name,
      content: content,
      timestamp: DateTime.now(),
      status: MessageStatus.sending,
    );

    state = state.copyWith(
      messages: [...state.messages, message],
    );

    final result = await _networkService.sendMessage(content);

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
        state = state.copyWith(
          messages: updatedMessages,
          error: msg,
        );
      },
    );

    return result;
  }

  void sendHelloMessage() {
    final deviceName = _networkService.getCurrentDevice().name;
    sendTextMessage('Hello from $deviceName!');
  }

  void sendDeviceInfo() {
    final device = _networkService.getCurrentDevice();
    sendTextMessage('Device: ${device.name}, Platform: ${device.platform.name}, Address: ${device.ipAddress}:${device.port}');
  }

  void _onMessageReceived(Message message) {
    state = state.copyWith(
      messages: [...state.messages, message],
    );
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

final connectedDeviceProvider = StateProvider<Device?>((ref) {
  return CrossPlatformNetworkService().currentConnectedDevice;
});
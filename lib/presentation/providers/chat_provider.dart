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

    final result = await _networkService.sendMessage(content);

    result.when(
      success: (_) {
        // Message sent successfully - the network service handles the stream
      },
      failure: (msg, {exception}) {
        state = state.copyWith(error: msg);
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

  void addTestMessage(String content, {bool isMe = true}) {
    final message = Message(
      id: 'test_${DateTime.now().millisecondsSinceEpoch}',
      senderId: isMe ? 'me' : 'other',
      senderName: isMe ? 'Me' : 'Other',
      content: content,
      timestamp: DateTime.now(),
      status: isMe ? MessageStatus.sent : MessageStatus.received,
    );
    state = state.copyWith(
      messages: [...state.messages, message],
    );
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  final connectionManager = ref.watch(connectionManagerProvider) as ConnectionManagerImpl;
  return ChatNotifier(CrossPlatformNetworkService());
});

final connectedDeviceProvider = StateProvider<Device?>((ref) {
  final connectionState = ref.watch(connectionStateProvider);
  if (connectionState == EchoLinkConnectionState.connected) {
    return CrossPlatformNetworkService().currentConnectedDevice;
  }
  return null;
});
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/models.dart';
import '../../domain/repositories/repositories.dart';
import '../../core/result.dart';

class ChatState {
  final List<Message> messages;
  final bool isLoading;
  final String? error;
  final Device? connectedDevice;

  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.error,
    this.connectedDevice,
  });

  ChatState copyWith({
    List<Message>? messages,
    bool? isLoading,
    String? error,
    Device? connectedDevice,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      connectedDevice: connectedDevice ?? this.connectedDevice,
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  final MessageRepository _messageRepository;

  ChatNotifier(this._messageRepository) : super(const ChatState()) {
    _init();
  }

  void _init() {
    _messageRepository.incomingMessages.listen(_onMessageReceived);
    _messageRepository.statusUpdates.listen(_onStatusUpdate);
  }

  void setConnectedDevice(Device? device) {
    state = state.copyWith(connectedDevice: device);
  }

  Future<Result<Message>> sendTextMessage(String content) async {
    if (state.connectedDevice == null) {
      return Failure('No device connected');
    }

    final message = Message.text(
      id: _generateId(),
      senderId: 'current_device',
      senderName: 'Me',
      receiverId: state.connectedDevice!.id,
      content: content,
    );

    state = state.copyWith(
      messages: [...state.messages, message.copyWith(status: MessageStatus.sending)],
    );

    final result = await _messageRepository.sendMessage(message);

    return result.when(
      success: (_) {
        _updateMessageStatus(message.id, MessageStatus.sent);
        return Success(message.copyWith(status: MessageStatus.sent));
      },
      failure: (msg, {exception}) {
        _updateMessageStatus(message.id, MessageStatus.failed);
        return Failure(msg);
      },
    );
  }

  Future<Result<void>> loadHistory(String deviceId) async {
    state = state.copyWith(isLoading: true);

    final result = await _messageRepository.getChatHistory(deviceId);

    return result.when(
      success: (messages) {
        state = state.copyWith(
          messages: messages,
          isLoading: false,
        );
        return const Success(null);
      },
      failure: (msg, {exception}) {
        state = state.copyWith(
          isLoading: false,
          error: msg,
        );
        return Failure(msg);
      },
    );
  }

  void _onMessageReceived(Message message) {
    state = state.copyWith(
      messages: [...state.messages, message.copyWith(status: MessageStatus.delivered)],
    );
  }

  void _onStatusUpdate(MessageStatus status) {
    // Handle status updates
  }

  void _updateMessageStatus(String messageId, MessageStatus status) {
    state = state.copyWith(
      messages: state.messages.map((m) {
        if (m.id == messageId) {
          return m.copyWith(status: status);
        }
        return m;
      }).toList(),
    );
  }

  String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  void clear() {
    state = const ChatState();
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  throw UnimplementedError('MessageRepository provider not implemented');
});
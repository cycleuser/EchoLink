import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';
import '../../../domain/models/models.dart';

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connectionState = ref.watch(connectionStateProvider);
    final chatState = ref.watch(chatProvider);
    final connectedDevice = ref.watch(connectedDeviceProvider);

    return Scaffold(
      appBar: AppBar(
        title: connectedDevice != null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(connectedDevice.name),
                  Text(
                    _getConnectionStatusText(connectionState),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              )
            : const Text('Chat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {},
          ),
        ],
      ),
      body: connectionState == EchoLinkConnectionState.connected
          ? _buildChatContent(chatState)
          : _buildEmptyState(context),
    );
  }

  Widget _buildChatContent(ChatState chatState) {
    return Column(
      children: [
        Expanded(
          child: chatState.messages.isEmpty
              ? _buildEmptyMessages(context)
              : _buildMessageList(chatState.messages),
        ),
        _buildMessageInput(),
      ],
    );
  }

  Widget _buildMessageList(List<Message> messages) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final isMe = message.status == MessageStatus.sent || 
                     message.status == MessageStatus.sending;
        return MessageBubble(
          message: message,
          isMe: isMe,
        );
      },
    );
  }

  Widget _buildEmptyMessages(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No messages yet',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Start the conversation',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.wifi_off,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No device connected',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Connect to a device to start chatting',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: _sendMessage,
            ),
          ),
          const SizedBox(width: 8),
          FloatingActionButton(
            onPressed: () => _sendMessage(_messageController.text),
            child: const Icon(Icons.send),
          ),
        ],
      ),
    );
  }

  void _sendMessage(String content) {
    if (content.trim().isEmpty) return;

    ref.read(chatProvider.notifier).sendTextMessage(content.trim());
    _messageController.clear();

    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _getConnectionStatusText(EchoLinkConnectionState state) {
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
}
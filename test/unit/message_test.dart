import 'package:flutter_test/flutter_test.dart';
import 'package:echolink/domain/models/models.dart';

void main() {
  group('Message', () {
    test('should create text message', () {
      final message = Message.text(
        id: 'msg-1',
        senderId: 'sender-1',
        senderName: 'Sender',
        receiverId: 'receiver-1',
        content: 'Hello, World!',
      );

      expect(message.id, 'msg-1');
      expect(message.type, MessageType.text);
      expect(message.content, 'Hello, World!');
      expect(message.isDirectMessage, true);
      expect(message.isGroupMessage, false);
    });

    test('should create system message', () {
      final message = Message.system(
        id: 'sys-1',
        content: 'User joined',
        groupId: 'group-1',
      );

      expect(message.isSystemMessage, true);
      expect(message.isGroupMessage, true);
      expect(message.status, MessageStatus.delivered);
    });

    test('should correctly identify message status', () {
      final pending = Message(
        id: '1',
        senderId: 's1',
        senderName: 'S',
        content: 'test',
        status: MessageStatus.pending,
        timestamp: DateTime.now(),
      );

      final sent = pending.copyWith(status: MessageStatus.sent);
      final failed = pending.copyWith(status: MessageStatus.failed);

      expect(pending.isPending, true);
      expect(sent.isSent, true);
      expect(failed.isFailed, true);
    });

    test('should serialize to JSON and back', () {
      final message = Message(
        id: 'msg-1',
        senderId: 'sender-1',
        senderName: 'Sender',
        receiverId: 'receiver-1',
        type: MessageType.text,
        content: 'Hello',
        status: MessageStatus.sent,
        timestamp: DateTime(2024, 1, 1, 12, 0),
        metadata: {'key': 'value'},
      );

      final json = message.toJson();
      final fromJson = Message.fromJson(json);

      expect(fromJson.id, message.id);
      expect(fromJson.senderId, message.senderId);
      expect(fromJson.content, message.content);
      expect(fromJson.metadata?['key'], 'value');
    });
  });
}
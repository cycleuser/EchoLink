import '../models/models.dart';
import '../../core/result.dart';

abstract class MessageRepository {
  Stream<Message> get incomingMessages;
  Stream<MessageStatus> get statusUpdates;

  Future<Result<void>> sendMessage(Message message);
  Future<Result<Message>> sendTextMessage({
    required String receiverId,
    required String content,
    String? groupId,
  });
  Future<Result<Message>> sendFileMessage({
    required String receiverId,
    required String filePath,
    String? groupId,
  });
  Future<Result<Message>> sendImageMessage({
    required String receiverId,
    required String imagePath,
    String? groupId,
  });
  Future<Result<List<Message>>> getChatHistory(String deviceId);
  Future<Result<void>> markAsRead(String messageId);
  Future<Result<void>> clearHistory(String deviceId);
  Future<void> dispose();
}
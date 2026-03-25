import '../models/models.dart';
import '../repositories/repositories.dart';
import '../../core/result.dart';

class SendMessage {
  final MessageRepository _repository;

  SendMessage(this._repository);

  Future<Result<Message>> call({
    required String receiverId,
    required String content,
    String? groupId,
  }) {
    return _repository.sendTextMessage(
      receiverId: receiverId,
      content: content,
      groupId: groupId,
    );
  }

  Stream<Message> watchIncoming() => _repository.incomingMessages;
}
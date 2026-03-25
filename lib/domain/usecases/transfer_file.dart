import '../models/models.dart';
import '../repositories/repositories.dart';
import '../../core/result.dart';

class TransferFile {
  final FileRepository _repository;

  TransferFile(this._repository);

  Future<Result<FileTransfer>> call({
    required String receiverId,
    required String filePath,
    String? groupId,
  }) {
    return _repository.sendFile(
      receiverId: receiverId,
      filePath: filePath,
      groupId: groupId,
    );
  }

  Future<Result<void>> pause(String transferId) {
    return _repository.pauseTransfer(transferId);
  }

  Future<Result<void>> resume(String transferId) {
    return _repository.resumeTransfer(transferId);
  }

  Future<Result<void>> cancel(String transferId) {
    return _repository.cancelTransfer(transferId);
  }

  Stream<FileTransfer> watchTransfers() => _repository.transfers;
}
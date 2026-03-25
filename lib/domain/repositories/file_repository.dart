import '../models/models.dart';
import '../../core/result.dart';

abstract class FileRepository {
  Stream<FileTransfer> get transfers;
  Stream<FileTransfer> get activeTransfers;

  Future<Result<FileTransfer>> sendFile({
    required String receiverId,
    required String filePath,
    String? groupId,
  });

  Future<Result<FileTransfer>> receiveFile({
    required String transferId,
    required String savePath,
  });

  Future<Result<void>> pauseTransfer(String transferId);
  Future<Result<void>> resumeTransfer(String transferId);
  Future<Result<void>> cancelTransfer(String transferId);

  Future<Result<List<FileTransfer>>> getTransferHistory();
  Future<Result<void>> clearHistory();

  Future<Result<String>> calculateChecksum(String filePath);
  Future<Result<bool>> verifyChecksum(String filePath, String expectedChecksum);

  Future<void> dispose();
}
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/models.dart';
import '../../core/result.dart';
import '../../infrastructure/network/cross_platform_network_service.dart';
import '../../core/utils/logger.dart';

final networkServiceProvider = Provider<CrossPlatformNetworkService>((ref) {
  return CrossPlatformNetworkService();
});

class TransferState {
  final List<FileTransfer> transfers;
  final bool isLoading;
  final String? error;

  const TransferState({
    this.transfers = const [],
    this.isLoading = false,
    this.error,
  });

  TransferState copyWith({
    List<FileTransfer>? transfers,
    bool? isLoading,
    String? error,
  }) {
    return TransferState(
      transfers: transfers ?? this.transfers,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  List<FileTransfer> get activeTransfers =>
      transfers.where((t) => t.isActive).toList();

  List<FileTransfer> get completedTransfers =>
      transfers.where((t) => t.isCompleted).toList();
}

class TransferNotifier extends StateNotifier<TransferState> {
  final CrossPlatformNetworkService _networkService;

  TransferNotifier(this._networkService) : super(const TransferState()) {
    _listenForFileTransfers();
  }

  void _listenForFileTransfers() {
    _networkService.fileTransfer.listen((transfer) {
      state = state.copyWith(
        transfers: [...state.transfers, transfer],
      );
    });
  }

  Future<Result<void>> sendFile({
    required String filePath,
    required String fileName,
    required int fileSize,
    required String deviceId,
  }) async {
    final transfer = FileTransfer(
      id: 'file_${DateTime.now().millisecondsSinceEpoch}',
      fileName: fileName,
      fileSize: fileSize,
      filePath: filePath,
      senderId: _networkService.getCurrentDevice().id,
      senderName: _networkService.getCurrentDevice().name,
      receiverId: deviceId,
      direction: TransferDirection.send,
      status: TransferStatus.inProgress,
      startTime: DateTime.now(),
    );

    state = state.copyWith(
      transfers: [...state.transfers, transfer],
    );

    try {
      final result = await _networkService.sendFile(
        filePath: filePath,
        fileName: fileName,
        fileSize: fileSize,
        deviceId: deviceId,
        onProgress: (progress) {
          final updatedTransfers = state.transfers.map((t) {
            if (t.id == transfer.id) {
              return t.copyWith(
                progress: progress,
                bytesTransferred: (fileSize * progress).toInt(),
              );
            }
            return t;
          }).toList();
          state = state.copyWith(transfers: updatedTransfers);
        },
      );

      final updatedTransfers = state.transfers.map((t) {
        if (t.id == transfer.id) {
          return t.copyWith(
            status: result.isSuccess
                ? TransferStatus.completed
                : TransferStatus.failed,
            endTime: DateTime.now(),
            progress: result.isSuccess ? 1.0 : t.progress,
          );
        }
        return t;
      }).toList();

      state = state.copyWith(transfers: updatedTransfers);

      return result;
    } catch (e) {
      final updatedTransfers = state.transfers.map((t) {
        if (t.id == transfer.id) {
          return t.copyWith(
            status: TransferStatus.failed,
            errorMessage: e.toString(),
            endTime: DateTime.now(),
          );
        }
        return t;
      }).toList();

      state = state.copyWith(transfers: updatedTransfers);
      return Failure(e.toString());
    }
  }

  void clear() {
    state = const TransferState();
  }
}

final transferProvider =
    StateNotifierProvider<TransferNotifier, TransferState>((ref) {
  return TransferNotifier(ref.watch(networkServiceProvider));
});

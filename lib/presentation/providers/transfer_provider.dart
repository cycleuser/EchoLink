import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/models.dart';
import '../../domain/repositories/repositories.dart';
import '../../core/result.dart';

class TransferState {
  final List<FileTransfer> transfers;
  final Map<String, double> progress;
  final bool isLoading;
  final String? error;

  const TransferState({
    this.transfers = const [],
    this.progress = const {},
    this.isLoading = false,
    this.error,
  });

  TransferState copyWith({
    List<FileTransfer>? transfers,
    Map<String, double>? progress,
    bool? isLoading,
    String? error,
  }) {
    return TransferState(
      transfers: transfers ?? this.transfers,
      progress: progress ?? this.progress,
      isLoading: isLoading,
      error: error,
    );
  }

  List<FileTransfer> get activeTransfers =>
      transfers.where((t) => t.isActive).toList();
  
  List<FileTransfer> get completedTransfers =>
      transfers.where((t) => t.isCompleted).toList();
}

class TransferNotifier extends StateNotifier<TransferState> {
  final FileRepository _fileRepository;

  TransferNotifier(this._fileRepository) : super(const TransferState()) {
    _init();
  }

  void _init() {
    _fileRepository.transfers.listen(_onTransferUpdate);
  }

  Future<Result<FileTransfer>> sendFile({
    required String receiverId,
    required String filePath,
  }) async {
    state = state.copyWith(isLoading: true);

    final result = await _fileRepository.sendFile(
      receiverId: receiverId,
      filePath: filePath,
    );

    return result.when(
      success: (transfer) {
        state = state.copyWith(
          transfers: [...state.transfers, transfer],
          isLoading: false,
        );
        return Success(transfer);
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

  Future<Result<void>> pauseTransfer(String transferId) async {
    return _fileRepository.pauseTransfer(transferId);
  }

  Future<Result<void>> resumeTransfer(String transferId) async {
    return _fileRepository.resumeTransfer(transferId);
  }

  Future<Result<void>> cancelTransfer(String transferId) async {
    final result = await _fileRepository.cancelTransfer(transferId);

    return result.when(
      success: (_) {
        state = state.copyWith(
          transfers: state.transfers.map((t) {
            if (t.id == transferId) {
              return t.copyWith(status: TransferStatus.cancelled);
            }
            return t;
          }).toList(),
        );
        return const Success(null);
      },
      failure: (msg, {exception}) => Failure(msg),
    );
  }

  void _onTransferUpdate(FileTransfer transfer) {
    final index = state.transfers.indexWhere((t) => t.id == transfer.id);

    if (index >= 0) {
      state = state.copyWith(
        transfers: [...state.transfers]..[index] = transfer,
        progress: {...state.progress, transfer.id: transfer.progress},
      );
    } else {
      state = state.copyWith(
        transfers: [...state.transfers, transfer],
        progress: {...state.progress, transfer.id: transfer.progress},
      );
    }
  }

  void clear() {
    state = const TransferState();
  }
}

final transferProvider = StateNotifierProvider<TransferNotifier, TransferState>((ref) {
  throw UnimplementedError('FileRepository provider not implemented');
});
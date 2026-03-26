import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/models.dart';
import '../../core/result.dart';
import '../../infrastructure/network/cross_platform_network_service.dart';

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

  TransferNotifier(this._networkService) : super(const TransferState());

  Future<Result<void>> sendTestFile() async {
    final device = _networkService.getCurrentDevice();
    final testContent = '''
EchoLink Test File
==================
Generated at: ${DateTime.now()}
Device: ${device.name}
Platform: ${device.platform.name}

This is a test file sent via EchoLink cross-platform communication.
''';

    final result = await _networkService.sendMessage('[FILE] test_file.txt:\n$testContent');

    final transfer = FileTransfer(
      id: 'transfer_${DateTime.now().millisecondsSinceEpoch}',
      fileName: 'test_file.txt',
      fileSize: testContent.length,
      filePath: '',
      senderId: device.id,
      senderName: device.name,
      receiverId: '',
      direction: TransferDirection.send,
      status: TransferStatus.completed,
      progress: 1.0,
      startTime: DateTime.now(),
      endTime: DateTime.now(),
    );

    state = state.copyWith(
      transfers: [...state.transfers, transfer],
    );

    return result;
  }

  void clear() {
    state = const TransferState();
  }
}

final transferProvider = StateNotifierProvider<TransferNotifier, TransferState>((ref) {
  return TransferNotifier(CrossPlatformNetworkService());
});
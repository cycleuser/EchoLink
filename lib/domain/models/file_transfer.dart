enum TransferDirection { send, receive }

enum TransferStatus {
  pending,
  preparing,
  inProgress,
  paused,
  completed,
  failed,
  cancelled,
}

class FileTransfer {
  final String id;
  final String fileName;
  final int fileSize;
  final String filePath;
  final String senderId;
  final String senderName;
  final String receiverId;
  final String? receiverName;
  final TransferDirection direction;
  final TransferStatus status;
  final double progress;
  final int bytesTransferred;
  final DateTime startTime;
  final DateTime? endTime;
  final String? checksum;
  final String? errorMessage;
  final Map<String, dynamic> metadata;

  const FileTransfer({
    required this.id,
    required this.fileName,
    required this.fileSize,
    required this.filePath,
    required this.senderId,
    required this.senderName,
    required this.receiverId,
    this.receiverName,
    required this.direction,
    this.status = TransferStatus.pending,
    this.progress = 0.0,
    this.bytesTransferred = 0,
    required this.startTime,
    this.endTime,
    this.checksum,
    this.errorMessage,
    this.metadata = const {},
  });

  FileTransfer copyWith({
    String? id,
    String? fileName,
    int? fileSize,
    String? filePath,
    String? senderId,
    String? senderName,
    String? receiverId,
    String? receiverName,
    TransferDirection? direction,
    TransferStatus? status,
    double? progress,
    int? bytesTransferred,
    DateTime? startTime,
    DateTime? endTime,
    String? checksum,
    String? errorMessage,
    Map<String, dynamic>? metadata,
  }) {
    return FileTransfer(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      filePath: filePath ?? this.filePath,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      receiverId: receiverId ?? this.receiverId,
      receiverName: receiverName ?? this.receiverName,
      direction: direction ?? this.direction,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      bytesTransferred: bytesTransferred ?? this.bytesTransferred,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      checksum: checksum ?? this.checksum,
      errorMessage: errorMessage ?? this.errorMessage,
      metadata: metadata ?? this.metadata,
    );
  }

  bool get isSending => direction == TransferDirection.send;
  bool get isReceiving => direction == TransferDirection.receive;

  bool get isPending => status == TransferStatus.pending;
  bool get isInProgress => status == TransferStatus.inProgress;
  bool get isPaused => status == TransferStatus.paused;
  bool get isCompleted => status == TransferStatus.completed;
  bool get isFailed => status == TransferStatus.failed;
  bool get isCancelled => status == TransferStatus.cancelled;

  bool get isActive => isPending || isInProgress || status == TransferStatus.preparing;

  double get progressPercentage => (progress * 100).clamp(0, 100);

  Duration? get duration {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }

  double? get speedBytesPerSecond {
    final dur = duration;
    if (dur == null || dur.inSeconds == 0) return null;
    return bytesTransferred / dur.inSeconds;
  }

  Duration? get estimatedTimeRemaining {
    final speed = speedBytesPerSecond;
    if (speed == null || speed == 0) return null;
    final remainingBytes = fileSize - bytesTransferred;
    return Duration(seconds: (remainingBytes / speed).round());
  }

  String get formattedFileSize => _formatBytes(fileSize);
  String get formattedBytesTransferred => _formatBytes(bytesTransferred);

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fileName': fileName,
      'fileSize': fileSize,
      'filePath': filePath,
      'senderId': senderId,
      'senderName': senderName,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'direction': direction.name,
      'status': status.name,
      'progress': progress,
      'bytesTransferred': bytesTransferred,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'checksum': checksum,
      'errorMessage': errorMessage,
      'metadata': metadata,
    };
  }

  factory FileTransfer.fromJson(Map<String, dynamic> json) {
    return FileTransfer(
      id: json['id'] as String,
      fileName: json['fileName'] as String,
      fileSize: json['fileSize'] as int,
      filePath: json['filePath'] as String,
      senderId: json['senderId'] as String,
      senderName: json['senderName'] as String? ?? 'Unknown',
      receiverId: json['receiverId'] as String,
      receiverName: json['receiverName'] as String?,
      direction: TransferDirection.values.firstWhere(
        (e) => e.name == json['direction'],
        orElse: () => TransferDirection.send,
      ),
      status: TransferStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => TransferStatus.pending,
      ),
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      bytesTransferred: json['bytesTransferred'] as int? ?? 0,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: json['endTime'] != null
          ? DateTime.parse(json['endTime'] as String)
          : null,
      checksum: json['checksum'] as String?,
      errorMessage: json['errorMessage'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FileTransfer && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'FileTransfer(id: $id, fileName: $fileName, progress: $progressPercentage%)';
}
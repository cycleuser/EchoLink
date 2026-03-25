enum MessageType { text, image, file, system, location }

enum MessageStatus { pending, sending, sent, delivered, read, failed }

class Message {
  final String id;
  final String senderId;
  final String senderName;
  final String? receiverId;
  final String? groupId;
  final MessageType type;
  final String content;
  final MessageStatus status;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  const Message({
    required this.id,
    required this.senderId,
    required this.senderName,
    this.receiverId,
    this.groupId,
    this.type = MessageType.text,
    required this.content,
    this.status = MessageStatus.pending,
    required this.timestamp,
    this.metadata,
  });

  Message copyWith({
    String? id,
    String? senderId,
    String? senderName,
    String? receiverId,
    String? groupId,
    MessageType? type,
    String? content,
    MessageStatus? status,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
  }) {
    return Message(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      receiverId: receiverId ?? this.receiverId,
      groupId: groupId ?? this.groupId,
      type: type ?? this.type,
      content: content ?? this.content,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      metadata: metadata ?? this.metadata,
    );
  }

  bool get isGroupMessage => groupId != null;
  bool get isDirectMessage => receiverId != null && groupId == null;
  bool get isSystemMessage => type == MessageType.system;
  bool get isFileMessage => type == MessageType.file;
  bool get isImageMessage => type == MessageType.image;

  bool get isPending => status == MessageStatus.pending;
  bool get isSending => status == MessageStatus.sending;
  bool get isSent => status == MessageStatus.sent;
  bool get isDelivered => status == MessageStatus.delivered;
  bool get isFailed => status == MessageStatus.failed;

  String? get fileName => metadata?['fileName'] as String?;
  int? get fileSize => metadata?['fileSize'] as int?;
  String? get filePath => metadata?['filePath'] as String?;
  String? get mimeType => metadata?['mimeType'] as String?;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderId': senderId,
      'senderName': senderName,
      'receiverId': receiverId,
      'groupId': groupId,
      'type': type.name,
      'content': content,
      'status': status.name,
      'timestamp': timestamp.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      senderId: json['senderId'] as String,
      senderName: json['senderName'] as String? ?? 'Unknown',
      receiverId: json['receiverId'] as String?,
      groupId: json['groupId'] as String?,
      type: MessageType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => MessageType.text,
      ),
      content: json['content'] as String,
      status: MessageStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => MessageStatus.pending,
      ),
      timestamp: DateTime.parse(json['timestamp'] as String),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  static Message text({
    required String id,
    required String senderId,
    required String senderName,
    String? receiverId,
    String? groupId,
    required String content,
  }) {
    return Message(
      id: id,
      senderId: senderId,
      senderName: senderName,
      receiverId: receiverId,
      groupId: groupId,
      type: MessageType.text,
      content: content,
      timestamp: DateTime.now(),
    );
  }

  static Message system({
    required String id,
    required String content,
    String? groupId,
  }) {
    return Message(
      id: id,
      senderId: 'system',
      senderName: 'System',
      groupId: groupId,
      type: MessageType.system,
      content: content,
      status: MessageStatus.delivered,
      timestamp: DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Message && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Message(id: $id, type: $type, status: $status)';
}
import 'dart:convert';
import 'dart:typed_data';
import '../../../domain/models/models.dart';
import '../../../core/utils/logger.dart';

class MessageProtocol {
  static const int version = 1;
  static const int headerSize = 24;

  static const int typeText = 1;
  static const int typeImage = 2;
  static const int typeFile = 3;
  static const int typeSystem = 4;

  static Uint8List encode(Message message) {
    try {
      final payload = utf8.encode(jsonEncode(message.toJson()));
      final header = ByteData(headerSize);

      header.setUint8(0, version);
      header.setUint8(1, _getTypeCode(message.type));
      header.setUint16(2, _getStatusCode(message.status), Endian.big);
      header.setUint32(4, payload.length, Endian.big);
      header.setUint64(8, message.timestamp.millisecondsSinceEpoch, Endian.big);
      header.setUint64(16, message.id.hashCode.abs(), Endian.big);

      return Uint8List.fromList([...header.buffer.asUint8List(), ...payload]);
    } catch (e) {
      AppLogger.error('Failed to encode message', e);
      rethrow;
    }
  }

  static Message? decode(Uint8List data) {
    try {
      if (data.length < headerSize) {
        AppLogger.warning('Message data too short: ${data.length}');
        return null;
      }

      final header = ByteData.sublistView(data, 0, headerSize);
      
      final protocolVersion = header.getUint8(0);
      if (protocolVersion != version) {
        AppLogger.warning('Unsupported protocol version: $protocolVersion');
        return null;
      }

      final payloadLength = header.getUint32(4, Endian.big);
      if (data.length < headerSize + payloadLength) {
        AppLogger.warning('Incomplete message payload');
        return null;
      }

      final payloadBytes = data.sublist(headerSize, headerSize + payloadLength);
      final payloadJson = jsonDecode(utf8.decode(payloadBytes)) as Map<String, dynamic>;

      return Message.fromJson(payloadJson);
    } catch (e) {
      AppLogger.error('Failed to decode message', e);
      return null;
    }
  }

  static List<Uint8List> chunk(Uint8List data, {int chunkSize = 65536}) {
    final chunks = <Uint8List>[];
    
    for (int i = 0; i < data.length; i += chunkSize) {
      final end = (i + chunkSize < data.length) ? i + chunkSize : data.length;
      chunks.add(Uint8List.sublistView(data, i, end));
    }

    return chunks;
  }

  static Uint8List assemble(List<Uint8List> chunks) {
    final totalLength = chunks.fold<int>(0, (sum, chunk) => sum + chunk.length);
    final result = Uint8List(totalLength);
    
    int offset = 0;
    for (final chunk in chunks) {
      result.setAll(offset, chunk);
      offset += chunk.length;
    }

    return result;
  }

  static int _getTypeCode(MessageType type) {
    return switch (type) {
      MessageType.text => typeText,
      MessageType.image => typeImage,
      MessageType.file => typeFile,
      MessageType.system => typeSystem,
      MessageType.location => typeText,
    };
  }

  static MessageType _getTypeFromCode(int code) {
    return switch (code) {
      typeText => MessageType.text,
      typeImage => MessageType.image,
      typeFile => MessageType.file,
      typeSystem => MessageType.system,
      _ => MessageType.text,
    };
  }

  static int _getStatusCode(MessageStatus status) {
    return switch (status) {
      MessageStatus.pending => 0,
      MessageStatus.sending => 1,
      MessageStatus.sent => 2,
      MessageStatus.delivered => 3,
      MessageStatus.read => 4,
      MessageStatus.failed => 5,
    };
  }

  static MessageStatus _getStatusFromCode(int code) {
    return switch (code) {
      0 => MessageStatus.pending,
      1 => MessageStatus.sending,
      2 => MessageStatus.sent,
      3 => MessageStatus.delivered,
      4 => MessageStatus.read,
      5 => MessageStatus.failed,
      _ => MessageStatus.pending,
    };
  }
}
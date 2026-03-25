import 'dart:convert';
import 'dart:typed_data';
import '../../domain/models/device.dart';
import '../../core/utils/logger.dart';

class HandshakeProtocol {
  static const int version = 1;
  static const String protocolName = 'EchoLink';

  static const int typeDiscover = 1;
  static const int typeDiscoverResponse = 2;
  static const int typeConnect = 3;
  static const int typeConnectAck = 4;
  static const int typeDisconnect = 5;
  static const int typeHeartbeat = 6;

  static Uint8List createDiscover(Device device) {
    return _encode(typeDiscover, {
      'device': device.toJson(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  static Map<String, dynamic>? parseDiscover(Uint8List data) {
    return _decode(typeDiscover, data);
  }

  static Uint8List createDiscoverResponse(Device device, List<String> knownPeers) {
    return _encode(typeDiscoverResponse, {
      'device': device.toJson(),
      'knownPeers': knownPeers,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  static Map<String, dynamic>? parseDiscoverResponse(Uint8List data) {
    return _decode(typeDiscoverResponse, data);
  }

  static Uint8List createConnect(Device device, String? groupId) {
    return _encode(typeConnect, {
      'device': device.toJson(),
      'groupId': groupId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  static Map<String, dynamic>? parseConnect(Uint8List data) {
    return _decode(typeConnect, data);
  }

  static Uint8List createConnectAck(bool accepted, String? message) {
    return _encode(typeConnectAck, {
      'accepted': accepted,
      'message': message,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  static Map<String, dynamic>? parseConnectAck(Uint8List data) {
    return _decode(typeConnectAck, data);
  }

  static Uint8List createDisconnect(String reason) {
    return _encode(typeDisconnect, {
      'reason': reason,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  static Map<String, dynamic>? parseDisconnect(Uint8List data) {
    return _decode(typeDisconnect, data);
  }

  static Uint8List createHeartbeat() {
    return _encode(typeHeartbeat, {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  static Map<String, dynamic>? parseHeartbeat(Uint8List data) {
    return _decode(typeHeartbeat, data);
  }

  static Uint8List _encode(int type, Map<String, dynamic> payload) {
    try {
      final payloadBytes = utf8.encode(jsonEncode(payload));
      final header = ByteData(12);

      header.setUint32(0, _magicNumber, Endian.big);
      header.setUint8(4, version);
      header.setUint8(5, type);
      header.setUint16(6, 0, Endian.big);
      header.setUint32(8, payloadBytes.length, Endian.big);

      return Uint8List.fromList([
        ...header.buffer.asUint8List(),
        ...payloadBytes,
      ]);
    } catch (e) {
      AppLogger.error('Failed to encode handshake packet', e);
      rethrow;
    }
  }

  static Map<String, dynamic>? _decode(int expectedType, Uint8List data) {
    try {
      if (data.length < 12) {
        AppLogger.warning('Handshake packet too short');
        return null;
      }

      final header = ByteData.sublistView(data, 0, 12);
      final magic = header.getUint32(0, Endian.big);

      if (magic != _magicNumber) {
        AppLogger.warning('Invalid handshake magic number');
        return null;
      }

      final pktVersion = header.getUint8(4);
      if (pktVersion != version) {
        AppLogger.warning('Unsupported handshake version: $pktVersion');
        return null;
      }

      final type = header.getUint8(5);
      if (type != expectedType && expectedType != -1) {
        AppLogger.warning('Unexpected handshake type: $type');
        return null;
      }

      final payloadLength = header.getUint32(8, Endian.big);
      if (data.length < 12 + payloadLength) {
        AppLogger.warning('Incomplete handshake payload');
        return null;
      }

      final payloadBytes = data.sublist(12, 12 + payloadLength);
      return jsonDecode(utf8.decode(payloadBytes)) as Map<String, dynamic>;
    } catch (e) {
      AppLogger.error('Failed to decode handshake packet', e);
      return null;
    }
  }

  static int get _magicNumber =>
      protocolName.codeUnits.fold<int>(0, (sum, c) => sum + c);
}
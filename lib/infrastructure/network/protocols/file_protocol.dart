import 'dart:io';
import 'dart:typed_data';
import '../../../domain/models/models.dart';
import '../../../core/utils/logger.dart';

class FileProtocol {
  static const int chunkSize = 65536;
  static const int headerSize = 64;

  static const int magicNumber = 0x454C4B46;

  static Future<FileHeader> createHeader(File file, String transferId) async {
    final stat = await file.stat();

    return FileHeader(
      transferId: transferId,
      fileName: file.path.split('/').last,
      fileSize: stat.size,
      chunkSize: chunkSize,
      checksum: null,
    );
  }

  static Uint8List encodeHeader(FileHeader header) {
    final buffer = ByteData(headerSize);
    final nameBytes = Uint8List(32);
    final nameEncoded = header.fileName.codeUnits;
    
    for (int i = 0; i < 32 && i < nameEncoded.length; i++) {
      nameBytes[i] = nameEncoded[i];
    }

    buffer.setUint32(0, magicNumber, Endian.big);
    buffer.setUint32(4, header.totalChunks ?? 0, Endian.big);
    buffer.setUint32(8, header.fileSize, Endian.big);
    buffer.setUint32(12, header.chunkSize, Endian.big);

    return Uint8List.fromList([
      ...buffer.buffer.asUint8List(),
      ...nameBytes,
      ..._encodeTransferId(header.transferId),
    ]);
  }

  static FileHeader? decodeHeader(Uint8List data) {
    if (data.length < headerSize) return null;

    final buffer = ByteData.sublistView(data, 0, 16);
    final magic = buffer.getUint32(0, Endian.big);

    if (magic != magicNumber) {
      AppLogger.warning('Invalid file header magic number');
      return null;
    }

    final totalChunks = buffer.getUint32(4, Endian.big);
    final fileSize = buffer.getUint32(8, Endian.big);
    final chunkSz = buffer.getUint32(12, Endian.big);

    final nameBytes = data.sublist(16, 48);
    final fileName = String.fromCharCodes(
      nameBytes.where((b) => b != 0),
    );

    final transferIdBytes = data.sublist(48, 64);
    final transferId = String.fromCharCodes(
      transferIdBytes.where((b) => b != 0),
    );

    return FileHeader(
      transferId: transferId,
      fileName: fileName,
      fileSize: fileSize,
      chunkSize: chunkSz,
      totalChunks: totalChunks,
    );
  }

  static Uint8List encodeChunk(String transferId, int index, Uint8List data) {
    final header = ByteData(24);
    
    header.setUint32(0, magicNumber, Endian.big);
    header.setUint32(4, index, Endian.big);
    header.setUint32(8, data.length, Endian.big);
    header.setUint64(16, DateTime.now().millisecondsSinceEpoch, Endian.big);

    final transferIdBytes = _encodeTransferId(transferId);

    return Uint8List.fromList([
      ...header.buffer.asUint8List(),
      ...transferIdBytes,
      ...data,
    ]);
  }

  static FileChunk? decodeChunk(Uint8List data) {
    if (data.length < 40) return null;

    final header = ByteData.sublistView(data, 0, 24);
    final magic = header.getUint32(0, Endian.big);

    if (magic != magicNumber) return null;

    final index = header.getUint32(4, Endian.big);
    final length = header.getUint32(8, Endian.big);

    final transferIdBytes = data.sublist(24, 40);
    final transferId = String.fromCharCodes(
      transferIdBytes.where((b) => b != 0),
    );

    final chunkData = data.sublist(40, 40 + length);

    return FileChunk(
      transferId: transferId,
      index: index,
      data: chunkData,
    );
  }

  static Future<List<Uint8List>> chunkFile(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final chunks = <Uint8List>[];

    for (int i = 0; i < bytes.length; i += chunkSize) {
      final end = (i + chunkSize < bytes.length) ? i + chunkSize : bytes.length;
      chunks.add(Uint8List.sublistView(bytes, i, end));
    }

    return chunks;
  }

  static Future<void> assembleChunks(
    List<FileChunk> chunks,
    String outputPath,
  ) async {
    final sortedChunks = chunks..sort((a, b) => a.index.compareTo(b.index));
    final file = File(outputPath);

    final sink = file.openWrite();
    for (final chunk in sortedChunks) {
      sink.add(chunk.data);
    }
    await sink.close();
  }

  static Uint8List _encodeTransferId(String id) {
    final bytes = Uint8List(16);
    final encoded = id.codeUnits;
    
    for (int i = 0; i < 16 && i < encoded.length; i++) {
      bytes[i] = encoded[i];
    }
    
    return bytes;
  }
}

class FileHeader {
  final String transferId;
  final String fileName;
  final int fileSize;
  final int chunkSize;
  final String? checksum;
  final int? totalChunks;

  const FileHeader({
    required this.transferId,
    required this.fileName,
    required this.fileSize,
    required this.chunkSize,
    this.checksum,
    this.totalChunks,
  });

  int get actualTotalChunks =>
      totalChunks ?? (fileSize / chunkSize).ceil();
}

class FileChunk {
  final String transferId;
  final int index;
  final Uint8List data;

  const FileChunk({
    required this.transferId,
    required this.index,
    required this.data,
  });

  int get length => data.length;
}
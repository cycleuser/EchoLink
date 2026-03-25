import '../models/models.dart';
import '../../core/result.dart';

abstract class ConnectionRepository {
  Stream<Device> get discoveredDevices;
  Stream<EchoLinkConnectionState> get connectionState;
  Stream<Device> get currentDevice;

  Future<Result<void>> initialize();
  Future<Result<void>> startDiscovery();
  Future<Result<void>> stopDiscovery();
  Future<Result<void>> connect(Device device);
  Future<Result<void>> disconnect();
  Future<Result<Device>> getCurrentDevice();
  Future<Result<List<Device>>> getDiscoveredDevices();
  Future<void> dispose();
}

enum EchoLinkConnectionState {
  disconnected,
  discovering,
  connecting,
  connected,
  error,
}

extension EchoLinkConnectionStateExtension on EchoLinkConnectionState {
  bool get isConnected => this == EchoLinkConnectionState.connected;
  bool get isDisconnected => this == EchoLinkConnectionState.disconnected;
  bool get isDiscovering => this == EchoLinkConnectionState.discovering;
  bool get isConnecting => this == EchoLinkConnectionState.connecting;
  bool get hasError => this == EchoLinkConnectionState.error;
}
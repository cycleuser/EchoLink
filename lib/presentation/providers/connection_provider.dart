import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/models.dart';
import '../../infrastructure/network/connection_manager.dart';
import '../../core/result.dart';

class ConnectionNotifier extends StateNotifier<ConnectionState> {
  final ConnectionManager _connectionManager;

  ConnectionNotifier(this._connectionManager) : super(ConnectionState.disconnected) {
    _init();
  }

  void _init() {
    _connectionManager.connectionState.listen((connectionState) {
      state = connectionState;
    });
  }

  Future<Result<void>> initialize() => _connectionManager.initialize();
  Future<Result<void>> startDiscovery() => _connectionManager.startDiscovery();
  Future<Result<void>> stopDiscovery() => _connectionManager.stopDiscovery();
  Future<Result<void>> connect(Device device) => _connectionManager.connect(device);
  Future<Result<void>> disconnect() => _connectionManager.disconnect();
}

class DiscoveredDevicesNotifier extends StateNotifier<List<Device>> {
  final ConnectionManager _connectionManager;

  DiscoveredDevicesNotifier(this._connectionManager) : super([]) {
    _init();
  }

  void _init() {
    _connectionManager.discoveredDevices.listen((device) {
      state = [...state.where((d) => d.id != device.id), device];
    });
  }

  void removeDevice(String deviceId) {
    state = state.where((d) => d.id != deviceId).toList();
  }

  void clear() {
    state = [];
  }
}

class CurrentDeviceNotifier extends StateNotifier<Device?> {
  final ConnectionManager _connectionManager;

  CurrentDeviceNotifier(this._connectionManager) : super(null);

  Future<void> load() async {
    final device = await _connectionManager.getCurrentDevice();
    state = device;
  }
}

final connectionManagerProvider = Provider<ConnectionManager>((ref) {
  return ConnectionManagerImpl();
});

final connectionStateProvider = StateNotifierProvider<ConnectionNotifier, ConnectionState>((ref) {
  return ConnectionNotifier(ref.watch(connectionManagerProvider));
});

final discoveredDevicesProvider = StateNotifierProvider<DiscoveredDevicesNotifier, List<Device>>((ref) {
  return DiscoveredDevicesNotifier(ref.watch(connectionManagerProvider));
});

final currentDeviceProvider = StateNotifierProvider<CurrentDeviceNotifier, Device?>((ref) {
  return CurrentDeviceNotifier(ref.watch(connectionManagerProvider));
});
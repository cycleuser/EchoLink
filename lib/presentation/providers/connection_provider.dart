import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/models.dart';
import '../../infrastructure/network/connection_manager.dart';
import '../../core/result.dart';
import '../../infrastructure/network/cross_platform_network_service.dart';

final connectionManagerProvider = Provider<ConnectionManager>((ref) {
  return ConnectionManagerImpl();
});

final connectionStateProvider = StateNotifierProvider<ConnectionNotifier, EchoLinkConnectionState>((ref) {
  return ConnectionNotifier(ref.watch(connectionManagerProvider));
});

final discoveredDevicesProvider = StateNotifierProvider<DiscoveredDevicesNotifier, List<Device>>((ref) {
  return DiscoveredDevicesNotifier(ref.watch(connectionManagerProvider));
});

final currentDeviceProvider = StateNotifierProvider<CurrentDeviceNotifier, Device?>((ref) {
  return CurrentDeviceNotifier(ref.watch(connectionManagerProvider));
});

final allowAutoConnectProvider = StateProvider<bool>((ref) => false);

final debugLogProvider = Provider<Stream<String>>((ref) {
  return ref.watch(connectionManagerProvider).debugLog;
});

final connectedDevicesProvider = Provider<List<Device>>((ref) {
  return CrossPlatformNetworkService().connectedDevices;
});

final connectedDeviceProvider = Provider<Device?>((ref) {
  final devices = ref.watch(connectedDevicesProvider);
  return devices.isNotEmpty ? devices.first : null;
});

class ConnectionNotifier extends StateNotifier<EchoLinkConnectionState> {
  final ConnectionManager _connectionManager;
  bool _allowAutoConnect = false;

  ConnectionNotifier(this._connectionManager) : super(EchoLinkConnectionState.disconnected) {
    _init();
  }

  void _init() {
    _connectionManager.connectionState.listen((connectionState) {
      state = connectionState;
    });
  }

  bool get allowAutoConnect => _allowAutoConnect;

  void setAllowAutoConnect(bool enabled) {
    _allowAutoConnect = enabled;
    CrossPlatformNetworkService().setAllowAutoConnect(enabled);
  }

  Future<Result<void>> initialize() => _connectionManager.initialize();
  Future<Result<void>> startDiscovery() => _connectionManager.startDiscovery();
  Future<Result<void>> stopDiscovery() => _connectionManager.stopDiscovery();
  Future<Result<void>> connect(Device device) => _connectionManager.connect(device);
  Future<Result<void>> disconnect([String? deviceId]) => _connectionManager.disconnect(deviceId);
}

class DiscoveredDevicesNotifier extends StateNotifier<List<Device>> {
  final ConnectionManager _connectionManager;

  DiscoveredDevicesNotifier(this._connectionManager) : super([]) {
    _init();
  }

  void _init() {
    _connectionManager.discoveredDevices.listen((device) {
      final existingIndex = state.indexWhere((d) => d.id == device.id);
      if (existingIndex >= 0) {
        state = [...state.sublist(0, existingIndex), device, ...state.sublist(existingIndex + 1)];
      } else {
        state = [...state, device];
      }
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

  CurrentDeviceNotifier(this._connectionManager) : super(null) {
    _load();
  }

  Future<void> _load() async {
    await Future.delayed(const Duration(milliseconds: 500));
    final device = await _connectionManager.getCurrentDevice();
    state = device;
  }

  Future<void> load() async {
    final device = await _connectionManager.getCurrentDevice();
    state = device;
  }
}
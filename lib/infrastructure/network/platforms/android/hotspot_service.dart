import 'dart:async';
import 'dart:io';
import '../../../../domain/models/models.dart';
import '../../../../core/result.dart';
import '../../../../core/constants.dart';
import '../../../../core/utils/logger.dart';

class HotspotService {
  static final HotspotService _instance = HotspotService._internal();
  factory HotspotService() => _instance;
  HotspotService._internal();

  final _stateController = StreamController<HotspotState>.broadcast();

  bool _isInitialized = false;
  HotspotState _state = HotspotState.disabled;
  String? _ssid;
  String? _password;
  int? _port;

  Stream<HotspotState> get state => _stateController.stream;
  HotspotState get currentState => _state;
  String? get ssid => _ssid;
  String? get password => _password;
  int? get port => _port;
  bool get isEnabled => _state == HotspotState.enabled;

  Future<Result<void>> initialize() async {
    if (!Platform.isAndroid) {
      return Failure('Hotspot service is primarily for Android');
    }

    try {
      AppLogger.info('Initializing hotspot service');
      _isInitialized = true;
      return const Success(null);
    } catch (e) {
      AppLogger.error('Failed to initialize hotspot', e);
      return Failure(e.toString());
    }
  }

  Future<Result<HotspotInfo>> startHotspot({
    String? ssid,
    String? password,
    int? port,
  }) async {
    if (!_isInitialized) {
      return Failure('Service not initialized');
    }

    try {
      AppLogger.info('Starting local hotspot');

      _ssid = ssid ?? 'EchoLink_${DateTime.now().millisecondsSinceEpoch % 10000}';
      _password = password ?? 'echolink123';
      _port = port ?? AppConstants.defaultPort;

      _updateState(HotspotState.starting);

      await Future.delayed(const Duration(seconds: 2));

      _updateState(HotspotState.enabled);

      return Success(HotspotInfo(
        ssid: _ssid!,
        password: _password!,
        port: _port!,
        ipAddress: '192.168.43.1',
      ));
    } catch (e) {
      AppLogger.error('Failed to start hotspot', e);
      _updateState(HotspotState.error);
      return Failure(e.toString());
    }
  }

  Future<Result<void>> stopHotspot() async {
    if (_state != HotspotState.enabled) {
      return const Success(null);
    }

    try {
      AppLogger.info('Stopping hotspot');
      
      _updateState(HotspotState.stopping);
      
      await Future.delayed(const Duration(milliseconds: 500));
      
      _ssid = null;
      _password = null;
      _port = null;
      
      _updateState(HotspotState.disabled);
      
      return const Success(null);
    } catch (e) {
      AppLogger.error('Failed to stop hotspot', e);
      return Failure(e.toString());
    }
  }

  Future<Result<HotspotInfo>> getHotspotInfo() async {
    if (_state != HotspotState.enabled) {
      return Failure('Hotspot not enabled');
    }

    return Success(HotspotInfo(
      ssid: _ssid!,
      password: _password!,
      port: _port!,
      ipAddress: '192.168.43.1',
    ));
  }

  void _updateState(HotspotState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  Future<void> dispose() async {
    await _stateController.close();
    _isInitialized = false;
  }
}

enum HotspotState {
  disabled,
  starting,
  enabled,
  stopping,
  error,
}

class HotspotInfo {
  final String ssid;
  final String password;
  final int port;
  final String ipAddress;

  const HotspotInfo({
    required this.ssid,
    required this.password,
    required this.port,
    required this.ipAddress,
  });

  Map<String, dynamic> toJson() => {
    'ssid': ssid,
    'password': password,
    'port': port,
    'ipAddress': ipAddress,
  };

  factory HotspotInfo.fromJson(Map<String, dynamic> json) {
    return HotspotInfo(
      ssid: json['ssid'] as String,
      password: json['password'] as String,
      port: json['port'] as int,
      ipAddress: json['ipAddress'] as String,
    );
  }
}
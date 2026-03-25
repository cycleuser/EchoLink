import 'dart:async';
import 'dart:io';
import '../../../../domain/models/models.dart';
import '../../../../core/result.dart';
import '../../../../core/constants.dart';
import '../../../../core/utils/logger.dart';

class BonjourService {
  static final BonjourService _instance = BonjourService._internal();
  factory BonjourService() => _instance;
  BonjourService._internal();

  final _servicesController = StreamController<List<DiscoveredService>>.broadcast();

  bool _isInitialized = false;
  bool _isPublishing = false;
  bool _isBrowsing = false;
  List<DiscoveredService> _discoveredServices = [];

  Stream<List<DiscoveredService>> get services => _servicesController.stream;

  bool get isInitialized => _isInitialized;
  bool get isPublishing => _isPublishing;
  bool get isBrowsing => _isBrowsing;

  Future<Result<void>> initialize() async {
    if (!Platform.isIOS && !Platform.isMacOS) {
      return Failure('Bonjour is only available on iOS/macOS');
    }

    try {
      AppLogger.info('Initializing Bonjour service');
      _isInitialized = true;
      return const Success(null);
    } catch (e) {
      AppLogger.error('Failed to initialize Bonjour', e);
      return Failure(e.toString());
    }
  }

  Future<Result<void>> publishService({
    required String name,
    required int port,
    Map<String, String>? txtRecords,
  }) async {
    if (!_isInitialized) {
      return Failure('Service not initialized');
    }

    if (_isPublishing) {
      return const Success(null);
    }

    try {
      AppLogger.info('Publishing Bonjour service: $name');
      _isPublishing = true;
      
      return const Success(null);
    } catch (e) {
      AppLogger.error('Failed to publish service', e);
      return Failure(e.toString());
    }
  }

  Future<Result<void>> stopPublishing() async {
    if (!_isPublishing) {
      return const Success(null);
    }

    try {
      AppLogger.info('Stopping Bonjour publishing');
      _isPublishing = false;
      
      return const Success(null);
    } catch (e) {
      AppLogger.error('Failed to stop publishing', e);
      return Failure(e.toString());
    }
  }

  Future<Result<void>> startBrowsing({String? serviceType}) async {
    if (!_isInitialized) {
      return Failure('Service not initialized');
    }

    if (_isBrowsing) {
      return const Success(null);
    }

    try {
      AppLogger.info('Browsing for Bonjour services');
      _isBrowsing = true;
      _discoveredServices = [];
      _servicesController.add([]);
      
      return const Success(null);
    } catch (e) {
      AppLogger.error('Failed to start browsing', e);
      return Failure(e.toString());
    }
  }

  Future<Result<void>> stopBrowsing() async {
    if (!_isBrowsing) {
      return const Success(null);
    }

    try {
      AppLogger.info('Stopping Bonjour browsing');
      _isBrowsing = false;
      
      return const Success(null);
    } catch (e) {
      AppLogger.error('Failed to stop browsing', e);
      return Failure(e.toString());
    }
  }

  void _onServiceFound(DiscoveredService service) {
    final index = _discoveredServices.indexWhere((s) => s.name == service.name);
    
    if (index < 0) {
      _discoveredServices.add(service);
      _servicesController.add(List.from(_discoveredServices));
    }
  }

  void _onServiceLost(String serviceName) {
    _discoveredServices.removeWhere((s) => s.name == serviceName);
    _servicesController.add(List.from(_discoveredServices));
  }

  Future<void> dispose() async {
    await _servicesController.close();
    _isInitialized = false;
    _isPublishing = false;
    _isBrowsing = false;
  }
}

class DiscoveredService {
  final String name;
  final String type;
  final String? hostName;
  final int? port;
  final Map<String, String> txtRecords;

  const DiscoveredService({
    required this.name,
    required this.type,
    this.hostName,
    this.port,
    this.txtRecords = const {},
  });

  Device toDevice() {
    return Device(
      id: name,
      name: name,
      platform: DevicePlatform.ios,
      ipAddress: hostName,
      port: port,
      status: DeviceStatus.disconnected,
    );
  }
}
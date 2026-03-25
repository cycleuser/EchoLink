import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import '../../core/result.dart';
import '../../core/exceptions.dart';
import '../../core/utils/logger.dart';

class PermissionHandler {
  static final PermissionHandler _instance = PermissionHandler._internal();
  factory PermissionHandler() => _instance;
  PermissionHandler._internal();

  Future<Result<Map<PermissionType, bool>>> checkAllPermissions() async {
    try {
      final results = <PermissionType, bool>{};

      if (Platform.isAndroid) {
        results[PermissionType.location] = await _checkLocation();
        results[PermissionType.nearbyWifiDevices] = await _checkNearbyWifiDevices();
        results[PermissionType.storage] = await _checkStorage();
        results[PermissionType.bluetooth] = await _checkBluetooth();
      } else if (Platform.isIOS) {
        results[PermissionType.localNetwork] = await _checkLocalNetwork();
        results[PermissionType.bluetooth] = await _checkBluetooth();
        results[PermissionType.photoLibrary] = await _checkPhotoLibrary();
      }

      return Success(results);
    } catch (e) {
      AppLogger.error('Failed to check permissions', e);
      return Failure(e.toString());
    }
  }

  Future<Result<Map<PermissionType, bool>>> requestAllPermissions() async {
    try {
      final results = <PermissionType, bool>{};

      if (Platform.isAndroid) {
        results[PermissionType.location] = await _requestLocation();
        results[PermissionType.nearbyWifiDevices] = await _requestNearbyWifiDevices();
        results[PermissionType.storage] = await _requestStorage();
        results[PermissionType.bluetooth] = await _requestBluetooth();
      } else if (Platform.isIOS) {
        results[PermissionType.localNetwork] = await _requestLocalNetwork();
        results[PermissionType.bluetooth] = await _requestBluetooth();
        results[PermissionType.photoLibrary] = await _requestPhotoLibrary();
      }

      return Success(results);
    } catch (e) {
      AppLogger.error('Failed to request permissions', e);
      return Failure(e.toString());
    }
  }

  Future<bool> _checkLocation() async {
    final status = await Permission.location.status;
    return status.isGranted;
  }

  Future<bool> _requestLocation() async {
    final status = await Permission.location.request();
    return status.isGranted;
  }

  Future<bool> _checkNearbyWifiDevices() async {
    if (Platform.isAndroid) {
      final status = await Permission.nearbyWifiDevices.status;
      return status.isGranted;
    }
    return true;
  }

  Future<bool> _requestNearbyWifiDevices() async {
    if (Platform.isAndroid) {
      final status = await Permission.nearbyWifiDevices.request();
      return status.isGranted;
    }
    return true;
  }

  Future<bool> _checkStorage() async {
    if (Platform.isAndroid) {
      final status = await Permission.storage.status;
      return status.isGranted;
    }
    return true;
  }

  Future<bool> _requestStorage() async {
    if (Platform.isAndroid) {
      final status = await Permission.storage.request();
      return status.isGranted;
    }
    return true;
  }

  Future<bool> _checkBluetooth() async {
    final status = await Permission.bluetooth.status;
    return status.isGranted;
  }

  Future<bool> _requestBluetooth() async {
    final status = await Permission.bluetooth.request();
    return status.isGranted;
  }

  Future<bool> _checkLocalNetwork() async {
    return true;
  }

  Future<bool> _requestLocalNetwork() async {
    return true;
  }

  Future<bool> _checkPhotoLibrary() async {
    final status = await Permission.photos.status;
    return status.isGranted;
  }

  Future<bool> _requestPhotoLibrary() async {
    final status = await Permission.photos.request();
    return status.isGranted;
  }

  Future<bool> hasAllRequiredPermissions() async {
    final result = await checkAllPermissions();
    
    return result.when(
      success: (permissions) {
        return permissions.values.every((granted) => granted);
      },
      failure: (message, {exception}) => false,
    );
  }

  Future<void> openAppSettings() async {
    await openAppSettings();
  }
}

enum PermissionType {
  location,
  nearbyWifiDevices,
  storage,
  bluetooth,
  localNetwork,
  photoLibrary,
}
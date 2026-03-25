class AppConstants {
  static const String appName = 'EchoLink';
  static const String appVersion = '1.0.0';
  
  static const Duration discoveryTimeout = Duration(seconds: 30);
  static const Duration connectionTimeout = Duration(seconds: 15);
  static const Duration messageTimeout = Duration(seconds: 10);
  
  static const int maxRetryAttempts = 3;
  static const int heartbeatIntervalSeconds = 30;
  
  static const int messageChunkSize = 65536;
  static const int fileChunkSize = 65536;
  static const int maxFileSize = 1024 * 1024 * 1024;
  
  static const String bonjourServiceType = '_echolink._tcp';
  static const int defaultPort = 50505;
}

class NetworkConstants {
  static const String wifiDirectServiceName = 'EchoLink';
  static const String multipeerServiceType = 'echolink';
  
  static const int socketTimeoutMs = 30000;
  static const int bufferSize = 8192;
}

class StorageKeys {
  static const String deviceName = 'device_name';
  static const String lastConnectedDevices = 'last_connected_devices';
  static const String themeMode = 'theme_mode';
  static const String notifications = 'notifications_enabled';
}
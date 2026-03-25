enum EchoLinkExceptionType {
  permissionDenied,
  wifiDisabled,
  bluetoothDisabled,
  discoveryFailed,
  connectionFailed,
  connectionTimeout,
  connectionLost,
  sendFailed,
  receiveFailed,
  fileNotFound,
  fileTooLarge,
  storageError,
  platformNotSupported,
  unknown,
}

class EchoLinkException implements Exception {
  final EchoLinkExceptionType type;
  final String message;
  final Exception? cause;
  
  const EchoLinkException(
    this.type, {
    this.message = '',
    this.cause,
  });
  
  factory EchoLinkException.permissionDenied([String? detail]) {
    return EchoLinkException(
      EchoLinkExceptionType.permissionDenied,
      message: detail ?? 'Permission denied',
    );
  }
  
  factory EchoLinkException.wifiDisabled() {
    return const EchoLinkException(
      EchoLinkExceptionType.wifiDisabled,
      message: 'Wi-Fi is disabled',
    );
  }
  
  factory EchoLinkException.discoveryFailed([String? detail]) {
    return EchoLinkException(
      EchoLinkExceptionType.discoveryFailed,
      message: detail ?? 'Device discovery failed',
    );
  }
  
  factory EchoLinkException.connectionFailed([String? detail]) {
    return EchoLinkException(
      EchoLinkExceptionType.connectionFailed,
      message: detail ?? 'Connection failed',
    );
  }
  
  factory EchoLinkException.connectionTimeout() {
    return const EchoLinkException(
      EchoLinkExceptionType.connectionTimeout,
      message: 'Connection timed out',
    );
  }
  
  factory EchoLinkException.connectionLost() {
    return const EchoLinkException(
      EchoLinkExceptionType.connectionLost,
      message: 'Connection lost',
    );
  }
  
  factory EchoLinkException.sendFailed([String? detail]) {
    return EchoLinkException(
      EchoLinkExceptionType.sendFailed,
      message: detail ?? 'Failed to send data',
    );
  }
  
  factory EchoLinkException.platformNotSupported() {
    return const EchoLinkException(
      EchoLinkExceptionType.platformNotSupported,
      message: 'Platform not supported',
    );
  }
  
  @override
  String toString() => 'EchoLinkException($type): $message';
}
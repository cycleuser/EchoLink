import 'dart:developer' as developer;

enum LogLevel { debug, info, warning, error }

class AppLogger {
  static bool _isEnabled = true;
  static LogLevel _minLevel = LogLevel.debug;

  static void setEnabled(bool enabled) => _isEnabled = enabled;
  static void setMinLevel(LogLevel level) => _minLevel = level;

  static void debug(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _log(LogLevel.debug, message, error, stackTrace);
  }

  static void info(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _log(LogLevel.info, message, error, stackTrace);
  }

  static void warning(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _log(LogLevel.warning, message, error, stackTrace);
  }

  static void error(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _log(LogLevel.error, message, error, stackTrace);
  }

  static void _log(LogLevel level, dynamic message, [dynamic error, StackTrace? stackTrace]) {
    if (!_isEnabled) return;
    if (level.index < _minLevel.index) return;

    final timestamp = DateTime.now().toString().substring(11, 23);
    final levelStr = level.name.toUpperCase().padRight(7);
    final prefix = '[$timestamp] $levelStr';

    final output = StringBuffer();
    output.write(prefix);
    output.write(' ');
    output.write(message);

    if (error != null) {
      output.write(' | Error: $error');
    }

    developer.log(output.toString(), name: 'EchoLink', level: _getLevel(level));

    if (stackTrace != null && level == LogLevel.error) {
      developer.log(stackTrace.toString(), name: 'EchoLink');
    }
  }

  static int _getLevel(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return 500;
      case LogLevel.info:
        return 800;
      case LogLevel.warning:
        return 900;
      case LogLevel.error:
        return 1000;
    }
  }
}
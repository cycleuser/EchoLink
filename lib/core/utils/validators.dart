class Validators {
  static bool isValidDeviceName(String? name) {
    if (name == null || name.isEmpty) return false;
    if (name.length > 32) return false;
    return RegExp(r'^[\w\s\-]+$').hasMatch(name);
  }
  
  static bool isValidMessageContent(String? content) {
    if (content == null || content.isEmpty) return false;
    if (content.length > 10000) return false;
    return true;
  }
  
  static bool isValidFilePath(String? path) {
    if (path == null || path.isEmpty) return false;
    return path.contains('/') || path.contains('\\');
  }
  
  static bool isValidIpAddress(String? ip) {
    if (ip == null || ip.isEmpty) return false;
    return RegExp(
      r'^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$'
    ).hasMatch(ip);
  }
  
  static bool isValidPort(int? port) {
    if (port == null) return false;
    return port > 0 && port <= 65535;
  }
  
  static bool isValidGroupName(String? name) {
    if (name == null || name.isEmpty) return false;
    if (name.length > 50) return false;
    return RegExp(r'^[\w\s\-]+$').hasMatch(name);
  }
  
  static bool isValidFileSize(int bytes, {int maxSize = 1024 * 1024 * 1024}) {
    return bytes > 0 && bytes <= maxSize;
  }
}
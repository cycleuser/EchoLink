import 'package:flutter/foundation.dart';

enum ProxyType {
  none,
  http,
  socks5,
}

@immutable
class ProxySettings {
  final ProxyType type;
  final String host;
  final int port;
  final String? username;
  final String? password;
  final bool enabled;
  final List<String> bypassHosts;

  const ProxySettings({
    this.type = ProxyType.none,
    this.host = '',
    this.port = 7890,
    this.username,
    this.password,
    this.enabled = false,
    this.bypassHosts = const ['localhost', '127.0.0.1', '192.168.*', '10.*', '172.16.*'],
  });

  bool get isValid {
    if (!enabled || type == ProxyType.none) return true;
    return host.isNotEmpty && port > 0 && port <= 65535;
  }

  String get proxyUrl {
    if (!enabled || type == ProxyType.none || !isValid) return '';
    
    final protocol = type == ProxyType.socks5 ? 'socks5' : 'http';
    
    if (username != null && username!.isNotEmpty && password != null) {
      return '$protocol://$username:$password@$host:$port';
    }
    
    return '$protocol://$host:$port';
  }

  bool shouldBypass(String address) {
    if (!enabled || type == ProxyType.none) return true;
    
    for (final bypass in bypassHosts) {
      if (bypass.contains('*')) {
        final pattern = bypass.replaceAll('.', r'\.').replaceAll('*', '.*');
        if (RegExp('^$pattern\$').hasMatch(address)) {
          return true;
        }
      } else if (address == bypass) {
        return true;
      }
    }
    
    return false;
  }

  ProxySettings copyWith({
    ProxyType? type,
    String? host,
    int? port,
    String? username,
    String? password,
    bool? enabled,
    List<String>? bypassHosts,
  }) {
    return ProxySettings(
      type: type ?? this.type,
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      password: password ?? this.password,
      enabled: enabled ?? this.enabled,
      bypassHosts: bypassHosts ?? this.bypassHosts,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.index,
      'host': host,
      'port': port,
      'username': username,
      'password': password,
      'enabled': enabled,
      'bypassHosts': bypassHosts,
    };
  }

  factory ProxySettings.fromJson(Map<String, dynamic> json) {
    return ProxySettings(
      type: ProxyType.values[json['type'] as int? ?? 0],
      host: json['host'] as String? ?? '',
      port: json['port'] as int? ?? 7890,
      username: json['username'] as String?,
      password: json['password'] as String?,
      enabled: json['enabled'] as bool? ?? false,
      bypassHosts: json['bypassHosts'] != null 
          ? List<String>.from(json['bypassHosts']) 
          : const ['localhost', '127.0.0.1', '192.168.*', '10.*', '172.16.*'],
    );
  }

  static const ProxySettings defaultSettings = ProxySettings();
}
enum DevicePlatform { android, ios, unknown }

enum ConnectionType { wifiDirect, multipeer, hotspot, wifiAware }

enum DeviceStatus { disconnected, discovering, connecting, connected }

enum ConnectionState { disconnected, discovering, connecting, connected, error }

class Device {
  final String id;
  final String name;
  final DevicePlatform platform;
  final String? ipAddress;
  final int? port;
  final DeviceStatus status;
  final ConnectionType? connectionType;
  final DateTime? lastSeen;
  final Map<String, dynamic> metadata;

  const Device({
    required this.id,
    required this.name,
    this.platform = DevicePlatform.unknown,
    this.ipAddress,
    this.port,
    this.status = DeviceStatus.disconnected,
    this.connectionType,
    this.lastSeen,
    this.metadata = const {},
  });

  Device copyWith({
    String? id,
    String? name,
    DevicePlatform? platform,
    String? ipAddress,
    int? port,
    DeviceStatus? status,
    ConnectionType? connectionType,
    DateTime? lastSeen,
    Map<String, dynamic>? metadata,
  }) {
    return Device(
      id: id ?? this.id,
      name: name ?? this.name,
      platform: platform ?? this.platform,
      ipAddress: ipAddress ?? this.ipAddress,
      port: port ?? this.port,
      status: status ?? this.status,
      connectionType: connectionType ?? this.connectionType,
      lastSeen: lastSeen ?? this.lastSeen,
      metadata: metadata ?? this.metadata,
    );
  }

  bool get isConnected => status == DeviceStatus.connected;
  bool get isDiscovering => status == DeviceStatus.discovering;
  bool get isConnecting => status == DeviceStatus.connecting;

  bool get isAndroid => platform == DevicePlatform.android;
  bool get isIOS => platform == DevicePlatform.ios;

  String get displayName => name.isEmpty ? 'Unknown Device' : name;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'platform': platform.name,
      'ipAddress': ipAddress,
      'port': port,
      'status': status.name,
      'connectionType': connectionType?.name,
      'lastSeen': lastSeen?.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      platform: DevicePlatform.values.firstWhere(
        (e) => e.name == json['platform'],
        orElse: () => DevicePlatform.unknown,
      ),
      ipAddress: json['ipAddress'] as String?,
      port: json['port'] as int?,
      status: DeviceStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => DeviceStatus.disconnected,
      ),
      connectionType: json['connectionType'] != null
          ? ConnectionType.values.firstWhere(
              (e) => e.name == json['connectionType'],
              orElse: () => ConnectionType.hotspot,
            )
          : null,
      lastSeen: json['lastSeen'] != null
          ? DateTime.parse(json['lastSeen'] as String)
          : null,
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Device && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Device(id: $id, name: $name, platform: $platform)';
}
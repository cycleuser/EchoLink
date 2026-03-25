enum GroupRole { owner, admin, member }

enum GroupStatus { active, inactive, archived }

class GroupMember {
  final String deviceId;
  final String name;
  final GroupRole role;
  final DateTime joinedAt;
  final bool isOnline;

  const GroupMember({
    required this.deviceId,
    required this.name,
    this.role = GroupRole.member,
    required this.joinedAt,
    this.isOnline = false,
  });

  GroupMember copyWith({
    String? deviceId,
    String? name,
    GroupRole? role,
    DateTime? joinedAt,
    bool? isOnline,
  }) {
    return GroupMember(
      deviceId: deviceId ?? this.deviceId,
      name: name ?? this.name,
      role: role ?? this.role,
      joinedAt: joinedAt ?? this.joinedAt,
      isOnline: isOnline ?? this.isOnline,
    );
  }

  bool get isOwner => role == GroupRole.owner;
  bool get isAdmin => role == GroupRole.admin || isOwner;

  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      'name': name,
      'role': role.name,
      'joinedAt': joinedAt.toIso8601String(),
      'isOnline': isOnline,
    };
  }

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      deviceId: json['deviceId'] as String,
      name: json['name'] as String? ?? 'Unknown',
      role: GroupRole.values.firstWhere(
        (e) => e.name == json['role'],
        orElse: () => GroupRole.member,
      ),
      joinedAt: DateTime.parse(json['joinedAt'] as String),
      isOnline: json['isOnline'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GroupMember && other.deviceId == deviceId;
  }

  @override
  int get hashCode => deviceId.hashCode;
}

class Group {
  final String id;
  final String name;
  final String ownerId;
  final List<GroupMember> members;
  final GroupStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic> metadata;

  const Group({
    required this.id,
    required this.name,
    required this.ownerId,
    this.members = const [],
    this.status = GroupStatus.active,
    required this.createdAt,
    this.updatedAt,
    this.metadata = const {},
  });

  Group copyWith({
    String? id,
    String? name,
    String? ownerId,
    List<GroupMember>? members,
    GroupStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
  }) {
    return Group(
      id: id ?? this.id,
      name: name ?? this.name,
      ownerId: ownerId ?? this.ownerId,
      members: members ?? this.members,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  bool get isActive => status == GroupStatus.active;
  int get memberCount => members.length;
  int get onlineCount => members.where((m) => m.isOnline).length;

  GroupMember? get owner => members.where((m) => m.deviceId == ownerId).firstOrNull;

  bool isMember(String deviceId) => members.any((m) => m.deviceId == deviceId);
  bool isOwnerOf(String deviceId) => deviceId == ownerId;

  GroupMember? getMember(String deviceId) {
    try {
      return members.firstWhere((m) => m.deviceId == deviceId);
    } catch (_) {
      return null;
    }
  }

  Group addMember(GroupMember member) {
    if (isMember(member.deviceId)) return this;
    return copyWith(
      members: [...members, member],
      updatedAt: DateTime.now(),
    );
  }

  Group removeMember(String deviceId) {
    if (deviceId == ownerId) return this;
    return copyWith(
      members: members.where((m) => m.deviceId != deviceId).toList(),
      updatedAt: DateTime.now(),
    );
  }

  Group updateMemberStatus(String deviceId, {bool? isOnline, GroupRole? role}) {
    return copyWith(
      members: members.map((m) {
        if (m.deviceId == deviceId) {
          return m.copyWith(isOnline: isOnline, role: role);
        }
        return m;
      }).toList(),
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'ownerId': ownerId,
      'members': members.map((m) => m.toJson()).toList(),
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: json['id'] as String,
      name: json['name'] as String,
      ownerId: json['ownerId'] as String,
      members: (json['members'] as List<dynamic>?)
              ?.map((m) => GroupMember.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [],
      status: GroupStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => GroupStatus.active,
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
    );
  }

  static Group create({
    required String id,
    required String name,
    required String ownerId,
    required String ownerName,
  }) {
    return Group(
      id: id,
      name: name,
      ownerId: ownerId,
      members: [
        GroupMember(
          deviceId: ownerId,
          name: ownerName,
          role: GroupRole.owner,
          joinedAt: DateTime.now(),
          isOnline: true,
        ),
      ],
      createdAt: DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Group && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Group(id: $id, name: $name, members: $memberCount)';
}
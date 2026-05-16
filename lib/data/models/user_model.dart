class UserModel {
  const UserModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    this.email,
    this.profilePhoto,
    this.isActive = true,
    this.lastLogin,
    this.createdAt,
  });

  final String id;
  final String name;
  final String phone;
  final String role;
  final String? email;
  final String? profilePhoto;
  final bool isActive;
  final DateTime? lastLogin;
  final DateTime? createdAt;

  bool get isSuperAdmin => role == 'super_admin';

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      name: (json['name'] ?? '') as String,
      phone: (json['phone'] ?? '') as String,
      role: (json['role'] ?? 'family_member') as String,
      email: json['email'] as String?,
      profilePhoto: json['profilePhoto'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      lastLogin: json['lastLogin'] != null
          ? DateTime.tryParse(json['lastLogin'].toString())
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    '_id': id,
    'name': name,
    'phone': phone,
    'role': role,
    'email': email,
    'profilePhoto': profilePhoto,
    'isActive': isActive,
    'lastLogin': lastLogin?.toIso8601String(),
    'createdAt': createdAt?.toIso8601String(),
  };
}

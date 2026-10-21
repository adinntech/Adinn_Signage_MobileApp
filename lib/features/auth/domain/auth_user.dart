enum UserRole {
  superAdmin('SUPER_ADMIN', 'Super Admin'),
  bd('BD', 'Business Development'),
  recceCoordinator('RECCE_COORDINATOR', 'Recce Coordinator'),
  recceExecutive('RECCE_EXECUTIVE', 'Recce Executive'),
  vendor('VENDOR', 'Vendor'),
  operations('OPERATIONS', 'Operations'),
  finance('FINANCE', 'Finance'),
  management('MANAGEMENT', 'Management'),
  unknown('UNKNOWN', 'Unknown');

  const UserRole(this.code, this.label);
  final String code;
  final String label;

  static UserRole parse(String? code) => UserRole.values.firstWhere(
        (r) => r.code == code,
        orElse: () => UserRole.unknown,
      );

  /// Where this role lands after login; null for roles that use the web CRM.
  String? get homeRoute => switch (this) {
        UserRole.recceExecutive => '/recce',
        UserRole.vendor => '/vendor',
        _ => null,
      };

  /// Roles this mobile app is built for.
  bool get isFieldStaff =>
      this == UserRole.recceExecutive || this == UserRole.vendor;
}

class AuthUser {
  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    required this.role,
    required this.isActive,
    this.permissions = const [],
  });

  final String id;
  final String name;
  final String email;
  final String? phone;
  final UserRole role;
  final bool isActive;
  final List<String> permissions;

  factory AuthUser.fromJson(Map<String, dynamic> j) => AuthUser(
        id: j['id'].toString(),
        name: (j['name'] ?? '').toString(),
        email: (j['email'] ?? '').toString(),
        phone: j['phone']?.toString(),
        role: UserRole.parse(j['role']?.toString()),
        isActive: j['isActive'] as bool? ?? true,
        permissions: ((j['permissions'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(growable: false),
      );
}

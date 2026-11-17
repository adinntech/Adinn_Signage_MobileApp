enum UserRole {
  superAdmin('SUPER_ADMIN', 'Super Admin'),
  bd('BD', 'Business Development'),
  clientServicing('CLIENT_SERVICING', 'Client Servicing'),
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

/// The vendor company a vendor login belongs to, exactly as the vendor master holds it.
class VendorProfile {
  const VendorProfile({
    required this.name,
    this.vendorNo,
    this.contactPerson,
    this.phone,
    this.altPhone,
    this.email,
    this.state,
    this.pincode,
  });

  final String name;
  final String? vendorNo;
  final String? contactPerson;
  final String? phone;
  final String? altPhone;
  final String? email;
  final String? state;
  final String? pincode;

  static String? _s(dynamic v) {
    final s = v?.toString().trim() ?? '';
    return s.isEmpty ? null : s;
  }

  factory VendorProfile.fromJson(Map<String, dynamic> j) => VendorProfile(
        name: (j['name'] ?? '').toString(),
        vendorNo: _s(j['vendorNo']),
        contactPerson: _s(j['contactPerson']),
        phone: _s(j['phone']),
        altPhone: _s(j['altPhone']),
        email: _s(j['email']),
        state: _s(j['state']),
        pincode: _s(j['pincode']),
      );
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
    this.mustChangeMpin = false,
    this.hasEmail = true,
    this.vendor,
  });

  final String id;
  final String name;
  final String email;
  final String? phone;
  final UserRole role;
  final bool isActive;
  final List<String> permissions;

  /// Vendor login made by the office with a default MPIN: a new MPIN must be set before anything else.
  final bool mustChangeMpin;

  /// False for a vendor login without an email: MPIN reset goes through Recce Operations.
  final bool hasEmail;

  /// Set for vendor logins only.
  final VendorProfile? vendor;

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
        mustChangeMpin: j['mustChangeMpin'] as bool? ?? false,
        hasEmail: j['hasEmail'] as bool? ?? true,
        vendor: j['vendor'] is Map
            ? VendorProfile.fromJson(Map<String, dynamic>.from(j['vendor'] as Map))
            : null,
      );
}

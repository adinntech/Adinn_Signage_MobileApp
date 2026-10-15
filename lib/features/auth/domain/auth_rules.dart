/// Field rules for sign in and registration. Mirrors the backend
/// (common/validators/credentials.ts); the backend stays authoritative.
class AuthRules {
  const AuthRules._();

  static const _weakMpins = {
    '0000', '1111', '2222', '3333', '4444', '5555', '6666', '7777', '8888',
    '9999', '1234', '4321', '0123', '3210',
  };

  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final _employeeId = RegExp(r'^[A-Za-z0-9._-]{2,30}$');
  static final _phone = RegExp(r'^\d{10}$');
  static final _fourDigits = RegExp(r'^\d{4}$');

  static bool hasMinLength(String v) => v.length >= 8;
  static bool hasLetter(String v) => RegExp(r'[A-Za-z]').hasMatch(v);
  static bool hasDigit(String v) => RegExp(r'\d').hasMatch(v);

  static String? identifier(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Enter your email or employee ID';
    if (s.contains('@')) return _email.hasMatch(s) ? null : 'Enter a valid email';
    return _employeeId.hasMatch(s) ? null : 'Enter a valid employee ID';
  }

  static String? name(String? v) =>
      (v?.trim().length ?? 0) < 2 ? 'Enter your full name' : null;

  static String? email(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Enter your email';
    return _email.hasMatch(s) ? null : 'Enter a valid email';
  }

  static String? employeeId(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Enter your employee ID';
    return _employeeId.hasMatch(s) ? null : 'Enter a valid employee ID';
  }

  static String? phone(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Enter your phone number';
    return _phone.hasMatch(s) ? null : 'Phone number must be exactly 10 digits';
  }

  static String? newPassword(String v) {
    if (!hasMinLength(v)) return 'Password needs at least 8 characters';
    if (!hasLetter(v)) return 'Password needs a letter';
    if (!hasDigit(v)) return 'Password needs a number';
    return null;
  }

  /// 0 = empty, 1 = weak (rules not met), 2 = fair (rules met), 3 = strong (rules met + two extras).
  static int passwordStrength(String v) {
    if (v.isEmpty) return 0;
    final met = hasMinLength(v) && hasLetter(v) && hasDigit(v);
    if (!met) return 1;
    final extras = (RegExp(r'[a-z]').hasMatch(v) && RegExp(r'[A-Z]').hasMatch(v) ? 1 : 0) +
        (RegExp(r'[^A-Za-z0-9]').hasMatch(v) ? 1 : 0) +
        (v.length >= 12 ? 1 : 0);
    return extras >= 2 ? 3 : 2;
  }

  /// Sign in only needs 4 digits.
  static String? signInMpin(String v) =>
      _fourDigits.hasMatch(v) ? null : 'Enter your 4-digit MPIN';

  /// Registration also rejects trivial MPINs.
  static String? newMpin(String v) {
    if (!_fourDigits.hasMatch(v)) return 'MPIN must be exactly 4 digits';
    if (_weakMpins.contains(v)) return 'Choose a less obvious MPIN';
    return null;
  }
}

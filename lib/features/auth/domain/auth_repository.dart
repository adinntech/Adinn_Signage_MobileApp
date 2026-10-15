import 'auth_credential.dart';
import 'auth_user.dart';

/// Failure surfaced to the UI. [code] is a backend error code or
/// `NETWORK_ERROR` / `UNKNOWN`.
class AuthFailure implements Exception {
  const AuthFailure(this.code, [this.message = '']);
  final String code;
  final String message;

  @override
  String toString() => 'AuthFailure($code, $message)';
}

class RestoredSession {
  const RestoredSession(this.user, {required this.offline});
  final AuthUser user;
  final bool offline;
}

class RegisterRequest {
  const RegisterRequest({
    required this.name,
    required this.email,
    required this.phone,
    required this.employeeId,
    required this.role,
    required this.credential,
  });

  final String name;
  final String email;
  final String phone;
  final String employeeId;
  final UserRole role;
  final AuthCredential credential;
}

abstract class AuthRepository {
  /// Tries to resume a stored session. Null when there is none / it was
  /// rejected. Returns an offline session if the network is down.
  Future<RestoredSession?> restore();

  /// [identifier] is an email or an employee ID. [loginRole] is the card the person picked (`RECCE` or
  /// `VENDOR`); the backend answers `USER_NOT_FOUND` if the account is registered under another role.
  /// Throws [AuthFailure].
  Future<AuthUser> login(String identifier, AuthCredential credential, {String? loginRole});

  /// Creates the account and signs the user in. Throws [AuthFailure].
  Future<AuthUser> register(RegisterRequest request);

  /// Best-effort server logout, then always clears local storage.
  Future<void> logout();

  /// Emits when the server permanently rejected the session.
  Stream<void> get sessionExpired;
}

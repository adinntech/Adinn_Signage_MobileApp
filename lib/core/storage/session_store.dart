import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the refresh token and cached user JSON. The access token is
/// intentionally never persisted.
abstract class SessionStore {
  Future<String?> readRefreshToken();
  Future<String?> readUserJson();
  Future<void> save({required String refreshToken, required String userJson});
  Future<void> clear();
}

class SecureSessionStore implements SessionStore {
  SecureSessionStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  static const _refreshKey = 'refresh_token';
  static const _userKey = 'cached_user';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> readRefreshToken() => _storage.read(key: _refreshKey);

  @override
  Future<String?> readUserJson() => _storage.read(key: _userKey);

  @override
  Future<void> save({
    required String refreshToken,
    required String userJson,
  }) async {
    await _storage.write(key: _refreshKey, value: refreshToken);
    await _storage.write(key: _userKey, value: userJson);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _refreshKey);
    await _storage.delete(key: _userKey);
  }
}

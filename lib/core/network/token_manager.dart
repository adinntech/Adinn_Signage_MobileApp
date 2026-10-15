// ignore_for_file: prefer_initializing_formals
import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../storage/session_store.dart';
import 'api_exception.dart';

/// Result payload of login/refresh.
class TokenPayload {
  const TokenPayload({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final Map<String, dynamic> user;

  factory TokenPayload.fromEnvelope(dynamic body) {
    final data = (body as Map)['data'] as Map;
    return TokenPayload(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
      user: Map<String, dynamic>.from(data['user'] as Map),
    );
  }
}

/// Holds the in-memory access token and performs single-flight refreshes.
/// Uses its own bare [Dio] (no interceptors) to avoid recursion.
class TokenManager {
  TokenManager({required Dio refreshDio, required SessionStore store})
      : _dio = refreshDio,
        _store = store;

  final Dio _dio;
  final SessionStore _store;
  final _expired = StreamController<void>.broadcast();
  Future<String?>? _inFlight;

  String? accessToken;

  /// Fires when the server rejected the refresh token (session is gone).
  Stream<void> get sessionExpired => _expired.stream;

  Future<void> persist(TokenPayload p) async {
    accessToken = p.accessToken;
    await _store.save(
      refreshToken: p.refreshToken,
      userJson: jsonEncode(p.user),
    );
  }

  Future<void> clear() async {
    accessToken = null;
    await _store.clear();
  }

  /// Returns a fresh access token, or null if the session was rejected.
  /// Throws [ApiException] (network) when offline; caller must not log out.
  Future<String?> refresh() {
    return _inFlight ??= _doRefresh().whenComplete(() => _inFlight = null);
  }

  Future<String?> _doRefresh() async {
    final stored = await _store.readRefreshToken();
    if (stored == null) {
      await _expire();
      return null;
    }
    try {
      final res = await _dio.post(
        '/auth/refresh',
        data: {'refreshToken': stored},
      );
      final payload = TokenPayload.fromEnvelope(res.data);
      await persist(payload); // rotated token must be saved
      return payload.accessToken;
    } on DioException catch (e) {
      final api = ApiException.fromDio(e);
      if (!api.isNetwork && api.isAuthRejection) {
        await _expire();
        return null;
      }
      throw api;
    }
  }

  Future<void> _expire() async {
    await clear();
    _expired.add(null);
  }
}

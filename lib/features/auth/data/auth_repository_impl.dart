// ignore_for_file: prefer_initializing_formals
import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/token_manager.dart';
import '../../../core/storage/session_store.dart';
import '../domain/auth_credential.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_user.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required Dio plainDio,
    required TokenManager tokens,
    required SessionStore store,
  })  : _dio = plainDio,
        _tokens = tokens,
        _store = store;

  final Dio _dio;
  final TokenManager _tokens;
  final SessionStore _store;

  @override
  Stream<void> get sessionExpired => _tokens.sessionExpired;

  AuthUser? _decode(String? json) {
    if (json == null) return null;
    try {
      return AuthUser.fromJson(
        Map<String, dynamic>.from(jsonDecode(json) as Map),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<RestoredSession?> restore() async {
    final refresh = await _store.readRefreshToken();
    if (refresh == null) return null;
    final cached = _decode(await _store.readUserJson());
    try {
      final token = await _tokens.refresh();
      if (token == null) return null; // rejected; storage already cleared
      // refresh() persisted the fresh user JSON.
      final fresh = _decode(await _store.readUserJson()) ?? cached;
      return fresh == null ? null : RestoredSession(fresh, offline: false);
    } on ApiException catch (e) {
      if (e.isNetwork || !e.isAuthRejection) {
        // Offline / server trouble: keep the session, never log out.
        return cached == null ? null : RestoredSession(cached, offline: true);
      }
      return null;
    }
  }

  /// POST that maps transport errors to [AuthFailure].
  Future<Response<dynamic>> _post(String path, Map<String, dynamic> body) async {
    try {
      return await _dio.post(path, data: body);
    } on DioException catch (e) {
      final api = ApiException.fromDio(e);
      throw AuthFailure(api.code, api.message);
    }
  }

  @override
  Future<AuthUser> login(String identifier, AuthCredential credential,
      {String? loginRole}) async {
    final res = await _post('/auth/login', {
      'identifier': identifier,
      ...credential.toBody(),
      'loginRole': ?loginRole,
      'platform': 'mobile',
    });
    final payload = TokenPayload.fromEnvelope(res.data);
    await _tokens.persist(payload);
    return AuthUser.fromJson(payload.user);
  }

  @override
  Future<AuthUser> register(RegisterRequest r) async {
    final res = await _post('/auth/register', {
      'name': r.name,
      'email': r.email,
      'phone': r.phone,
      'employeeId': r.employeeId,
      'role': r.role.code,
      'platform': 'mobile',
      'authMethod': r.credential.method,
      ...r.credential.toBody(),
    });
    final payload = TokenPayload.fromEnvelope(res.data);
    await _tokens.persist(payload);
    return AuthUser.fromJson(payload.user);
  }

  @override
  Future<void> logout() async {
    final refresh = await _store.readRefreshToken();
    if (refresh != null) {
      try {
        await _dio.post(
          '/auth/logout',
          data: {'refreshToken': refresh},
          options: Options(
            headers: {
              if (_tokens.accessToken != null)
                'Authorization': 'Bearer ${_tokens.accessToken}',
            },
          ),
        );
      } catch (_) {
        // best effort
      }
    }
    await _tokens.clear();
  }
}

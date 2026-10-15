import 'package:dio/dio.dart';

import '../config/app_config.dart';
import 'token_manager.dart';

BaseOptions baseOptions() => BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      headers: {'Accept': 'application/json'},
    );

/// Dio without interceptors; used for refresh and unauthenticated calls.
Dio createPlainDio() => Dio(baseOptions());

/// Dio with Bearer attach + one-shot refresh-and-retry on 401.
Dio createAuthedDio(TokenManager tokens) {
  final dio = Dio(baseOptions());
  dio.interceptors.add(AuthInterceptor(dio, tokens));
  return dio;
}

class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._dio, this._tokens);

  final Dio _dio;
  final TokenManager _tokens;
  static const _retriedKey = 'auth_retried';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _tokens.accessToken;
    if (token != null) options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final req = err.requestOptions;
    final isAuthPath = req.path.contains('/auth/login') ||
        req.path.contains('/auth/refresh');
    if (err.response?.statusCode != 401 ||
        isAuthPath ||
        req.extra[_retriedKey] == true) {
      return handler.next(err);
    }
    try {
      final token = await _tokens.refresh();
      if (token == null) return handler.next(err);
      req.extra[_retriedKey] = true;
      req.headers['Authorization'] = 'Bearer $token';
      final response = await _dio.fetch<dynamic>(req);
      handler.resolve(response);
    } on DioException catch (e) {
      handler.next(e);
    } catch (_) {
      // Refresh failed for network reasons: surface original error, no logout.
      handler.next(err);
    }
  }
}

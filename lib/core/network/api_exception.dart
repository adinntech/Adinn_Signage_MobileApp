import 'package:dio/dio.dart';

/// Normalised error from the backend or the network layer.
class ApiException implements Exception {
  const ApiException({
    required this.code,
    required this.message,
    this.statusCode,
  });

  static const networkCode = 'NETWORK_ERROR';
  static const unknownCode = 'UNKNOWN';

  final String code;
  final String message;
  final int? statusCode;

  bool get isNetwork => code == networkCode;

  /// True when the server definitively rejected the credentials/session.
  bool get isAuthRejection =>
      statusCode == 401 ||
      statusCode == 403 ||
      code == 'TOKEN_INVALID' ||
      code == 'REFRESH_INVALID' ||
      code == 'REFRESH_REUSED' ||
      code == 'REFRESH_EXPIRED';

  factory ApiException.fromDio(DioException e) {
    final res = e.response;
    if (res == null) {
      return ApiException(
        code: networkCode,
        message: e.message ?? 'Network unavailable',
      );
    }
    final body = res.data;
    if (body is Map && body['error'] is Map) {
      final err = body['error'] as Map;
      return ApiException(
        code: (err['code'] ?? unknownCode).toString(),
        message: (err['message'] ?? 'Request failed').toString(),
        statusCode: res.statusCode,
      );
    }
    return ApiException(
      code: unknownCode,
      message: 'Request failed (${res.statusCode})',
      statusCode: res.statusCode,
    );
  }

  @override
  String toString() => 'ApiException($code, $message)';
}

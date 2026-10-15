import 'package:flutter/foundation.dart';

/// Build-time configuration. Override with
/// `--dart-define=API_BASE_URL=https://host/api/v1` (needed for a physical
/// phone: use your PC's LAN address, e.g. http://192.168.1.74:4000/api/v1).
class AppConfig {
  const AppConfig._();

  static const String _override = String.fromEnvironment('API_BASE_URL');

  /// Dev defaults: Chrome/desktop reach the backend on localhost; the Android
  /// emulator reaches the host PC through 10.0.2.2.
  static String get apiBaseUrl {
    if (_override.isNotEmpty) return _override;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:4000/api/v1';
    }
    return 'http://localhost:4000/api/v1';
  }

  static const String appName = 'Adinn Recce';
}

import '../domain/auth_repository.dart';

String friendlyAuthMessage(AuthFailure f) {
  switch (f.code) {
    case 'INVALID_CREDENTIALS':
      return 'Incorrect details. If you registered with an MPIN, switch on "Use MPIN".';
    case 'USER_NOT_FOUND':
      return 'User not found';
    case 'ACCOUNT_LOCKED':
      return 'Too many wrong attempts. Try again in 15 minutes or ask your administrator to reset your credential.';
    case 'PLATFORM_NOT_ALLOWED':
      return 'This account signs in on the web CRM, not the mobile app.';
    case 'CONFLICT':
      return 'An account with this email or employee ID already exists.';
    case 'ACCOUNT_DISABLED':
      return 'Your account is disabled. Contact your administrator.';
    case 'VALIDATION_ERROR':
      return 'Please check the details you entered.';
    case 'RATE_LIMITED':
      return 'Too many attempts. Please wait a minute and try again.';
    case 'NETWORK_ERROR':
      return 'Cannot reach the server. Check your connection and try again.';
    case 'TOKEN_INVALID':
    case 'REFRESH_INVALID':
    case 'REFRESH_REUSED':
    case 'REFRESH_EXPIRED':
      return 'Your session expired. Please sign in again.';
    default:
      return 'Something went wrong. Please try again.';
  }
}

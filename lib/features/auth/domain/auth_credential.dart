/// What the user types to prove who they are: a password or a 4-digit MPIN.
/// Exactly one is sent to the backend, matching how the account was registered.
sealed class AuthCredential {
  const AuthCredential();

  /// Backend `authMethod` value.
  String get method;

  /// Fields merged into the request body (`password` or `mpin`).
  Map<String, String> toBody();
}

class PasswordCredential extends AuthCredential {
  const PasswordCredential(this.password);
  final String password;

  @override
  String get method => 'PASSWORD';

  @override
  Map<String, String> toBody() => {'password': password};
}

class MpinCredential extends AuthCredential {
  const MpinCredential(this.mpin);
  final String mpin;

  @override
  String get method => 'MPIN';

  @override
  Map<String, String> toBody() => {'mpin': mpin};
}

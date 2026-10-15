import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/providers.dart';
import '../domain/auth_credential.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_user.dart';

sealed class AuthState {
  const AuthState();
}

class AuthInitializing extends AuthState {
  const AuthInitializing();
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated({this.error, this.busy = false});
  final AuthFailure? error;
  final bool busy;
}

class Authenticated extends AuthState {
  const Authenticated(this.user, {this.offline = false});
  final AuthUser user;
  final bool offline;
}

class AuthController extends Notifier<AuthState> {
  late AuthRepository _repo;

  @override
  AuthState build() {
    _repo = ref.watch(authRepositoryProvider);
    final sub = _repo.sessionExpired.listen((_) {
      state = const AuthUnauthenticated();
    });
    ref.onDispose(sub.cancel);
    Future.microtask(_init);
    return const AuthInitializing();
  }

  Future<void> _init() async {
    try {
      final s = await _repo.restore();
      state = s == null
          ? const AuthUnauthenticated()
          : Authenticated(s.user, offline: s.offline);
    } catch (_) {
      state = const AuthUnauthenticated();
    }
  }

  Future<void> login(String identifier, AuthCredential credential,
      {String? loginRole}) async {
    state = const AuthUnauthenticated(busy: true);
    try {
      final user = await _repo.login(identifier.trim(), credential, loginRole: loginRole);
      state = Authenticated(user);
    } on AuthFailure catch (e) {
      state = AuthUnauthenticated(error: e);
    } catch (e) {
      state = AuthUnauthenticated(error: AuthFailure('UNKNOWN', '$e'));
    }
  }

  /// Creates the account; on success the user is signed in.
  Future<void> register(RegisterRequest request) async {
    state = const AuthUnauthenticated(busy: true);
    try {
      state = Authenticated(await _repo.register(request));
    } on AuthFailure catch (e) {
      state = AuthUnauthenticated(error: e);
    } catch (e) {
      state = AuthUnauthenticated(error: AuthFailure('UNKNOWN', '$e'));
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AuthUnauthenticated();
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

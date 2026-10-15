import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signage/core/network/providers.dart';
import 'package:signage/features/auth/domain/auth_credential.dart';
import 'package:signage/features/auth/domain/auth_repository.dart';
import 'package:signage/features/auth/domain/auth_user.dart';
import 'package:signage/features/auth/presentation/auth_controller.dart';

const _user = AuthUser(
  id: '1',
  name: 'Ravi Kumar',
  email: 'ravi@adinn.co.in',
  role: UserRole.recceExecutive,
  isActive: true,
);

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.fail, this.restored});
  final AuthFailure? fail;
  final RestoredSession? restored;
  bool loggedOut = false;

  @override
  Future<RestoredSession?> restore() async => restored;

  @override
  Future<AuthUser> login(String identifier, AuthCredential credential,
      {String? loginRole}) async {
    if (fail != null) throw fail!;
    return _user;
  }

  @override
  Future<AuthUser> register(RegisterRequest request) async {
    if (fail != null) throw fail!;
    return _user;
  }

  @override
  Future<void> logout() async => loggedOut = true;

  @override
  Stream<void> get sessionExpired => const Stream.empty();
}

ProviderContainer _container(FakeAuthRepository repo) {
  final c = ProviderContainer(
    overrides: [authRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(c.dispose);
  return c;
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  test('starts initializing then unauthenticated with no session', () async {
    final c = _container(FakeAuthRepository());
    expect(c.read(authControllerProvider), isA<AuthInitializing>());
    await _settle();
    expect(c.read(authControllerProvider), isA<AuthUnauthenticated>());
  });

  test('restores an offline session', () async {
    final c = _container(
        FakeAuthRepository(restored: const RestoredSession(_user, offline: true)));
    c.read(authControllerProvider);
    await _settle();
    final s = c.read(authControllerProvider) as Authenticated;
    expect(s.offline, isTrue);
  });

  test('login success -> authenticated', () async {
    final c = _container(FakeAuthRepository());
    c.read(authControllerProvider);
    await _settle();
    await c.read(authControllerProvider.notifier).login('a@b.co', const PasswordCredential('Passw0rd1'));
    final s = c.read(authControllerProvider);
    expect(s, isA<Authenticated>());
    expect((s as Authenticated).user.email, 'ravi@adinn.co.in');
  });

  test('login failure -> error state', () async {
    final c = _container(
        FakeAuthRepository(fail: const AuthFailure('INVALID_CREDENTIALS')));
    c.read(authControllerProvider);
    await _settle();
    await c.read(authControllerProvider.notifier).login('a@b.co', const PasswordCredential('Wrong1234'));
    final s = c.read(authControllerProvider) as AuthUnauthenticated;
    expect(s.error?.code, 'INVALID_CREDENTIALS');
    expect(s.busy, isFalse);
  });

  test('register success -> authenticated', () async {
    final c = _container(FakeAuthRepository());
    c.read(authControllerProvider);
    await _settle();
    await c.read(authControllerProvider.notifier).register(const RegisterRequest(
        name: 'Ravi Kumar',
        email: 'ravi@adinn.co.in',
        phone: '9876543210',
        employeeId: 'EMP1',
        role: UserRole.recceExecutive,
        credential: MpinCredential('2580')));
    expect(c.read(authControllerProvider), isA<Authenticated>());
  });

  test('register conflict -> error state', () async {
    final c = _container(FakeAuthRepository(fail: const AuthFailure('CONFLICT')));
    c.read(authControllerProvider);
    await _settle();
    await c.read(authControllerProvider.notifier).register(const RegisterRequest(
        name: 'Ravi Kumar',
        email: 'ravi@adinn.co.in',
        phone: '9876543210',
        employeeId: 'EMP1',
        role: UserRole.recceExecutive,
        credential: MpinCredential('2580')));
    final s = c.read(authControllerProvider) as AuthUnauthenticated;
    expect(s.error?.code, 'CONFLICT');
  });

  test('logout -> unauthenticated', () async {
    final repo = FakeAuthRepository();
    final c = _container(repo);
    c.read(authControllerProvider);
    await _settle();
    final n = c.read(authControllerProvider.notifier);
    await n.login('a@b.co', const PasswordCredential('Passw0rd1'));
    await n.logout();
    expect(c.read(authControllerProvider), isA<AuthUnauthenticated>());
    expect(repo.loggedOut, isTrue);
  });
}

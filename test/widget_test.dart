import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signage/core/network/providers.dart';
import 'package:signage/features/auth/domain/auth_credential.dart';
import 'package:signage/features/auth/domain/auth_repository.dart';
import 'package:signage/features/auth/domain/auth_user.dart';
import 'package:signage/features/auth/presentation/login_screen.dart';

class _NoSessionRepo implements AuthRepository {
  @override
  Future<RestoredSession?> restore() async => null;
  @override
  Future<AuthUser> login(String identifier, AuthCredential credential,
      {String? loginRole}) async =>
      throw const AuthFailure('INVALID_CREDENTIALS');
  @override
  Future<AuthUser> register(RegisterRequest request) async =>
      throw const AuthFailure('CONFLICT');
  @override
  Future<void> logout() async {}
  @override
  Stream<void> get sessionExpired => const Stream.empty();
}

void main() {
  testWidgets('login screen shows validation errors on empty submit',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_NoSessionRepo()),
        ],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );

    await tester.ensureVisible(find.text('Login'));
    await tester.tap(find.text('Login'));
    await tester.pump();

    expect(find.text('Enter your email or employee ID'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
  });
}

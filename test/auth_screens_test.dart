import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signage/core/network/providers.dart';
import 'package:signage/features/auth/domain/auth_credential.dart';
import 'package:signage/features/auth/domain/auth_repository.dart';
import 'package:signage/features/auth/domain/auth_rules.dart';
import 'package:signage/features/auth/domain/auth_user.dart';
import 'package:signage/features/auth/presentation/login_screen.dart';
import 'package:signage/features/auth/presentation/register_screen.dart';

const _user = AuthUser(
  id: '1',
  name: 'Field Exec',
  email: 'recce@adinn.test',
  role: UserRole.recceExecutive,
  isActive: true,
);

class _Repo implements AuthRepository {
  _Repo({this.failWith});
  final AuthFailure? failWith;
  String? loggedInIdentifier;
  AuthCredential? loggedInWith;
  String? loggedInRole;
  RegisterRequest? registered;

  @override
  Future<RestoredSession?> restore() async => null;
  @override
  Future<AuthUser> login(String identifier, AuthCredential credential,
      {String? loginRole}) async {
    loggedInIdentifier = identifier;
    loggedInWith = credential;
    loggedInRole = loginRole;
    throw failWith ?? const AuthFailure('INVALID_CREDENTIALS');
  }

  @override
  Future<AuthUser> register(RegisterRequest request) async {
    registered = request;
    return _user;
  }

  @override
  Future<void> logout() async {}
  @override
  Stream<void> get sessionExpired => const Stream.empty();
}

Widget _app(_Repo repo, Widget home) => ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(home: home),
    );

/// The MPIN boxes are driven by an invisible TextField; text fields in a screen
/// are found in order, so tests address them by position.
Finder _fields() => find.byType(TextField);

void main() {
  group('AuthRules', () {
    test('MPIN: 4 digits, no trivial values', () {
      expect(AuthRules.newMpin('2580'), isNull);
      expect(AuthRules.newMpin('123'), isNotNull);
      expect(AuthRules.newMpin('12345'), isNotNull);
      expect(AuthRules.newMpin('abcd'), isNotNull);
      for (final weak in ['0000', '1111', '1234', '4321']) {
        expect(AuthRules.newMpin(weak), isNotNull, reason: weak);
      }
      expect(AuthRules.signInMpin('1111'), isNull);
      expect(AuthRules.signInMpin('11'), isNotNull);
    });

    test('password: 8+ chars with a letter and a number', () {
      expect(AuthRules.newPassword('Passw0rd!x'), isNull);
      expect(AuthRules.newPassword('short1'), isNotNull);
      expect(AuthRules.newPassword('onlyletters'), isNotNull);
      expect(AuthRules.newPassword('12345678'), isNotNull);
    });

    test('password strength: weak, fair, strong', () {
      expect(AuthRules.passwordStrength(''), 0);
      expect(AuthRules.passwordStrength('abc'), 1);
      expect(AuthRules.passwordStrength('password1'), 2);
      expect(AuthRules.passwordStrength('Passw0rd!x'), 3);
    });

    test('identifier accepts email or employee id', () {
      expect(AuthRules.identifier('a@b.co'), isNull);
      expect(AuthRules.identifier('EMP001'), isNull);
      expect(AuthRules.identifier('bad@'), isNotNull);
      expect(AuthRules.identifier(' '), isNotNull);
    });

    test('registration fields are all required', () {
      expect(AuthRules.name(''), isNotNull);
      expect(AuthRules.email(''), isNotNull);
      expect(AuthRules.phone(''), isNotNull);
      expect(AuthRules.employeeId(''), isNotNull);
      expect(AuthRules.phone('9876543210'), isNull);
      for (final bad in ['98765', '98765 43210', '98765abcde', '+919876543210', '98765432101']) {
        expect(AuthRules.phone(bad), isNotNull, reason: bad);
      }
    });
  });

  testWidgets('login sends the identifier and password by default',
      (tester) async {
    final repo = _Repo();
    await tester.pumpWidget(_app(repo, const LoginScreen()));

    await tester.enterText(_fields().at(0), 'EMP001');
    await tester.enterText(_fields().at(1), 'Passw0rd1');
    await tester.ensureVisible(find.text('Login'));
    await tester.tap(find.text('Login'));
    await tester.pump();

    expect(repo.loggedInIdentifier, 'EMP001');
    expect(repo.loggedInWith, isA<PasswordCredential>());
    expect((repo.loggedInWith as PasswordCredential).password, 'Passw0rd1');
  });

  testWidgets('switching Use MPIN on sends an MPIN credential', (tester) async {
    final repo = _Repo();
    await tester.pumpWidget(_app(repo, const LoginScreen()));

    await tester.enterText(_fields().at(0), 'EMP001');
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.text('MPIN'), findsOneWidget);
    expect(find.text('Password'), findsNothing);

    await tester.enterText(_fields().at(1), '2580');
    await tester.ensureVisible(find.text('Login'));
    await tester.tap(find.text('Login'));
    await tester.pump();

    expect(repo.loggedInWith, isA<MpinCredential>());
    expect((repo.loggedInWith as MpinCredential).mpin, '2580');
  });

  testWidgets('switching the MPIN off returns to the password field',
      (tester) async {
    await tester.pumpWidget(_app(_Repo(), const LoginScreen()));
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('MPIN'), findsNothing);
  });

  testWidgets('login sends the picked role card (Recce by default, Vendor when chosen)',
      (tester) async {
    final repo = _Repo();
    await tester.pumpWidget(_app(repo, const LoginScreen()));
    await tester.enterText(_fields().at(0), 'EMP001');
    await tester.enterText(_fields().at(1), 'Passw0rd1');
    await tester.ensureVisible(find.text('Login'));
    await tester.tap(find.text('Login'));
    await tester.pump();
    expect(repo.loggedInRole, 'RECCE');

    await tester.tap(find.text('Vendor'));
    await tester.pump();
    await tester.tap(find.text('Login'));
    await tester.pump();
    expect(repo.loggedInRole, 'VENDOR');
  });

  testWidgets('login shows only "User not found" when the role does not match',
      (tester) async {
    final repo = _Repo(failWith: const AuthFailure('USER_NOT_FOUND', 'User not found'));
    await tester.pumpWidget(_app(repo, const LoginScreen()));
    await tester.enterText(_fields().at(0), 'EMP001');
    await tester.enterText(_fields().at(1), 'Passw0rd1');
    await tester.ensureVisible(find.text('Login'));
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();
    expect(find.text('User not found'), findsOneWidget);
    expect(find.textContaining('Incorrect'), findsNothing);
  });

  testWidgets('login has no forgot-password option', (tester) async {
    await tester.pumpWidget(_app(_Repo(), const LoginScreen()));
    expect(find.textContaining('Forgot'), findsNothing);
  });

  testWidgets('login rejects an incomplete MPIN before calling the API',
      (tester) async {
    final repo = _Repo();
    await tester.pumpWidget(_app(repo, const LoginScreen()));
    await tester.enterText(_fields().at(0), 'EMP001');
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.enterText(_fields().at(1), '25');
    await tester.ensureVisible(find.text('Login'));
    await tester.tap(find.text('Login'));
    await tester.pump();

    expect(find.text('Enter your 4-digit MPIN'), findsOneWidget);
    expect(repo.loggedInWith, isNull);
  });

  testWidgets('register blocks empty fields and weak MPIN', (tester) async {
    final repo = _Repo();
    await tester.pumpWidget(_app(repo, const RegisterScreen()));

    await tester.ensureVisible(find.text('Create account'));
    await tester.tap(find.text('Create account'));
    await tester.pump();
    expect(find.text('Enter your full name'), findsOneWidget);
    expect(find.text('Enter your employee ID'), findsOneWidget);
    expect(find.text('Enter your phone number'), findsOneWidget);
    expect(repo.registered, isNull);

    await tester.enterText(_fields().at(4), 'short');
    await tester.tap(find.text('Create account'));
    await tester.pump();
    expect(find.text('Password needs at least 8 characters'), findsOneWidget);

    await tester.ensureVisible(find.byType(Switch));
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.enterText(_fields().at(4), '1111');
    await tester.ensureVisible(find.text('Create account'));
    await tester.tap(find.text('Create account'));
    await tester.pump();
    expect(find.text('Choose a less obvious MPIN'), findsOneWidget);
  });

  testWidgets('register submits all details with a password', (tester) async {
    final repo = _Repo();
    await tester.pumpWidget(_app(repo, const RegisterScreen()));

    await tester.enterText(_fields().at(0), 'Field Exec');
    await tester.enterText(_fields().at(1), 'EMP200');
    await tester.enterText(_fields().at(2), 'Recce@Adinn.test');
    await tester.enterText(_fields().at(3), '9876543211');
    await tester.enterText(_fields().at(4), 'Passw0rd1');
    await tester.enterText(_fields().at(5), 'Passw0rd1');
    await tester.ensureVisible(find.text('Create account'));
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    final r = repo.registered!;
    expect(r.name, 'Field Exec');
    expect(r.employeeId, 'EMP200');
    expect(r.email, 'recce@adinn.test');
    expect(r.phone, '9876543211');
    expect(r.credential, isA<PasswordCredential>());
    expect(r.role, UserRole.recceExecutive);
  });

  testWidgets('register with the MPIN switch on sends an MPIN credential',
      (tester) async {
    final repo = _Repo();
    await tester.pumpWidget(_app(repo, const RegisterScreen()));
    await tester.enterText(_fields().at(0), 'Field Exec');
    await tester.enterText(_fields().at(1), 'EMP200');
    await tester.enterText(_fields().at(2), 'recce@adinn.test');
    await tester.enterText(_fields().at(3), '9876543211');
    await tester.ensureVisible(find.byType(Switch));
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.enterText(_fields().at(4), '7391');
    await tester.enterText(_fields().at(5), '7391');
    await tester.ensureVisible(find.text('Create account'));
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    expect(repo.registered!.credential, isA<MpinCredential>());
    expect((repo.registered!.credential as MpinCredential).mpin, '7391');
  });

  testWidgets('register shows a mismatch when the passwords differ', (tester) async {
    final repo = _Repo();
    await tester.pumpWidget(_app(repo, const RegisterScreen()));
    await tester.enterText(_fields().at(0), 'Field Exec');
    await tester.enterText(_fields().at(1), 'EMP200');
    await tester.enterText(_fields().at(2), 'recce@adinn.test');
    await tester.enterText(_fields().at(3), '9876543211');
    await tester.enterText(_fields().at(4), 'Passw0rd1');
    await tester.enterText(_fields().at(5), 'Passw0rd2');
    await tester.ensureVisible(find.text('Create account'));
    await tester.tap(find.text('Create account'));
    await tester.pump();
    expect(find.text('Passwords do not match'), findsOneWidget);
    expect(repo.registered, isNull);
  });
}

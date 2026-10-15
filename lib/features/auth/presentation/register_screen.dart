import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_rules.dart';
import '../domain/auth_user.dart';
import 'auth_controller.dart';
import 'auth_messages.dart';
import 'widgets/auth_scaffold.dart';
import 'widgets/credential_section.dart';

/// Self-registration for field staff. Only mobile roles are offered; the
/// backend rejects any other role for this app. On success the user is signed
/// in and the router moves to the home screen.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _name = TextEditingController();
  final _employeeId = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _credential = CredentialInputs(create: true);
  UserRole _role = UserRole.recceExecutive;
  final _errors = <String, String?>{};

  @override
  void dispose() {
    for (final c in [_name, _employeeId, _email, _phone]) {
      c.dispose();
    }
    _credential.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _errors['name'] = AuthRules.name(_name.text);
      _errors['employeeId'] = AuthRules.employeeId(_employeeId.text);
      _errors['email'] = AuthRules.email(_email.text);
      _errors['phone'] = AuthRules.phone(_phone.text);
    });
    final credOk = _credential.validate();
    if (_errors.values.any((e) => e != null) || !credOk) return;
    FocusScope.of(context).unfocus();
    await ref.read(authControllerProvider.notifier).register(
          RegisterRequest(
            name: _name.text.trim(),
            email: _email.text.trim().toLowerCase(),
            phone: _phone.text.trim(),
            employeeId: _employeeId.text.trim(),
            role: _role,
            credential: _credential.credential,
          ),
        );
  }

  Widget _field(String key, TextEditingController c, String label, IconData icon,
      {required bool busy,
      TextInputType? type,
      List<String>? hints,
      List<TextInputFormatter>? formatters,
      String? helper}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: c,
        enabled: !busy,
        keyboardType: type,
        textInputAction: TextInputAction.next,
        autofillHints: hints,
        inputFormatters: formatters,
        decoration: InputDecoration(
          labelText: '$label *',
          helperText: helper,
          errorText: _errors[key],
          prefixIcon: Icon(icon),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final busy = state is AuthUnauthenticated && state.busy;
    final failure = state is AuthUnauthenticated ? state.error : null;

    return AuthScaffold(
      title: 'Create your account',
      subtitle: 'Choose a password or a 4-digit MPIN. You will be signed in right away.',
      showBack: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (failure != null) ...[
            AuthBanner(message: friendlyAuthMessage(failure)),
            const SizedBox(height: 16),
          ],
          const Text('I am a *',
              style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.navy)),
          const SizedBox(height: 8),
          SegmentedButton<UserRole>(
            segments: const [
              ButtonSegment(
                  value: UserRole.recceExecutive,
                  label: Text('Recce'),
                  icon: Icon(Icons.travel_explore)),
              ButtonSegment(
                  value: UserRole.vendor,
                  label: Text('Vendor'),
                  icon: Icon(Icons.storefront_outlined)),
            ],
            selected: {_role},
            onSelectionChanged:
                busy ? null : (s) => setState(() => _role = s.first),
          ),
          const SizedBox(height: 20),
          _field('name', _name, 'Full name', Icons.person_outline,
              busy: busy, type: TextInputType.name, hints: const [AutofillHints.name]),
          _field('employeeId', _employeeId, 'Employee ID', Icons.badge_outlined,
              busy: busy),
          _field('email', _email, 'Email', Icons.mail_outline,
              busy: busy,
              type: TextInputType.emailAddress,
              hints: const [AutofillHints.email]),
          _field('phone', _phone, 'Phone', Icons.phone_outlined,
              busy: busy,
              type: TextInputType.number,
              helper: '10 digits, numbers only',
              formatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              hints: const [AutofillHints.telephoneNumber]),
          const SizedBox(height: 6),
          CredentialSection(
            inputs: _credential,
            switchLabel: 'Use 4-digit MPIN',
            enabled: !busy,
            onSubmit: _submit,
          ),
          const SizedBox(height: 24),
          AuthButton(label: 'Create account', busy: busy, onPressed: _submit),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Already registered?'),
              TextButton(
                onPressed: busy ? null : () => context.go('/login'),
                child: const Text('Sign in'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

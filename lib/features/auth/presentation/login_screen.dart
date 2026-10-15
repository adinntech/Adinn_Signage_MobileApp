import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/auth_rules.dart';
import '../domain/auth_user.dart';
import 'auth_controller.dart';
import 'auth_messages.dart';
import 'widgets/auth_scaffold.dart';
import 'widgets/credential_section.dart';

/// Roles that sign in on the mobile app. The picked card is sent to the backend, which
/// answers "User not found" unless the account was registered under that role.
const _roles = [
  (role: UserRole.recceExecutive, key: 'RECCE', label: 'Recce', hint: 'Field execution', icon: Icons.travel_explore),
  (role: UserRole.vendor, key: 'VENDOR', label: 'Vendor', hint: 'Field vendors', icon: Icons.storefront_outlined),
];

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _identifier = TextEditingController();
  final _credential = CredentialInputs(create: false);
  UserRole _role = UserRole.recceExecutive;
  String? _identifierError;

  @override
  void dispose() {
    _identifier.dispose();
    _credential.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final idErr = AuthRules.identifier(_identifier.text);
    final credOk = _credential.validate();
    setState(() => _identifierError = idErr);
    if (idErr != null || !credOk) return;
    FocusScope.of(context).unfocus();
    await ref.read(authControllerProvider.notifier).login(
          _identifier.text,
          _credential.credential,
          loginRole: _roles.firstWhere((r) => r.role == _role).key,
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final busy = state is AuthUnauthenticated && state.busy;
    final error = state is AuthUnauthenticated ? state.error : null;

    return AuthScaffold(
      title: 'Welcome back',
      subtitle: 'Sign in with your password or MPIN',
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              alignment: Alignment.topCenter,
              child: error == null
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: AuthBanner(message: friendlyAuthMessage(error)),
                    ),
            ),
            const Text('Select Your Role',
                style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.navy)),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final r in _roles) ...[
                  Expanded(
                    child: _RoleCard(
                      label: r.label,
                      hint: r.hint,
                      icon: r.icon,
                      selected: _role == r.role,
                      onTap: busy ? null : () => setState(() => _role = r.role),
                    ),
                  ),
                  if (r != _roles.last) const SizedBox(width: 12),
                ],
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _identifier,
              enabled: !busy,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.username, AutofillHints.email],
              autocorrect: false,
              decoration: InputDecoration(
                labelText: 'Email / Employee ID',
                errorText: _identifierError,
                prefixIcon: const Icon(Icons.mail_outline),
              ),
            ),
            const SizedBox(height: 20),
            CredentialSection(
              inputs: _credential,
              switchLabel: 'Use MPIN',
              enabled: !busy,
              onSubmit: _submit,
            ),
            const SizedBox(height: 24),
            AuthButton(label: 'Login', busy: busy, onPressed: _submit),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('New here?'),
                TextButton(
                  onPressed: busy ? null : () => context.push('/register'),
                  child: const Text('Create an account'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.label,
    required this.hint,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String hint;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : AppColors.navy;
    return Semantics(
      button: true,
      selected: selected,
      label: '$label, $hint',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(colors: [AppColors.navy, AppColors.royal])
                : null,
            color: selected ? null : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: selected ? AppColors.royal : const Color(0xFFD5DBE8)),
            boxShadow: selected
                ? [BoxShadow(color: AppColors.royal.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))]
                : null,
          ),
          child: Column(
            children: [
              Icon(icon, color: selected ? Colors.white : AppColors.royal),
              const SizedBox(height: 6),
              Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: fg)),
              Text(hint,
                  style: TextStyle(
                      fontSize: 11,
                      color: selected ? Colors.white70 : Colors.black54)),
            ],
          ),
        ),
      ),
    );
  }
}

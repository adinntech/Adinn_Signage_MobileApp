import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/auth_credential.dart';
import '../../domain/auth_rules.dart';
import 'mpin_field.dart';

/// State for the password-or-MPIN block shared by sign in and register.
/// The owning screen creates one, passes it to [CredentialSection], calls
/// [validate] on submit and reads [credential].
class CredentialInputs extends ChangeNotifier {
  CredentialInputs({required this.create});

  /// true = register (strength rules + confirmation); false = sign in.
  final bool create;

  final password = TextEditingController();
  final confirmPassword = TextEditingController();
  final mpin = TextEditingController();
  final confirmMpin = TextEditingController();

  bool useMpin = false;
  String? passwordError;
  String? confirmError;
  String? mpinError;
  String? confirmMpinError;

  void setUseMpin(bool v) {
    useMpin = v;
    for (final c in [password, confirmPassword, mpin, confirmMpin]) {
      c.clear();
    }
    passwordError = confirmError = mpinError = confirmMpinError = null;
    notifyListeners();
  }

  /// Returns true when valid; otherwise sets the field errors and notifies.
  bool validate() {
    passwordError = confirmError = mpinError = confirmMpinError = null;
    if (useMpin) {
      mpinError = create ? AuthRules.newMpin(mpin.text) : AuthRules.signInMpin(mpin.text);
      if (create && mpinError == null && confirmMpin.text != mpin.text) {
        confirmMpinError = 'MPINs do not match';
      }
    } else {
      final p = password.text;
      if (p.isEmpty) {
        passwordError = 'Enter your password';
      } else if (create) {
        passwordError = AuthRules.newPassword(p);
        if (passwordError == null && confirmPassword.text != p) {
          confirmError = 'Passwords do not match';
        }
      }
    }
    notifyListeners();
    return passwordError == null &&
        confirmError == null &&
        mpinError == null &&
        confirmMpinError == null;
  }

  AuthCredential get credential =>
      useMpin ? MpinCredential(mpin.text) : PasswordCredential(password.text);

  @override
  void dispose() {
    password.dispose();
    confirmPassword.dispose();
    mpin.dispose();
    confirmMpin.dispose();
    super.dispose();
  }
}

class CredentialSection extends StatefulWidget {
  const CredentialSection({
    super.key,
    required this.inputs,
    required this.switchLabel,
    this.enabled = true,
    this.onSubmit,
  });

  final CredentialInputs inputs;
  final String switchLabel;
  final bool enabled;

  /// Called when the user finishes the last field (keyboard "done" / MPIN complete).
  final VoidCallback? onSubmit;

  @override
  State<CredentialSection> createState() => _CredentialSectionState();
}

class _CredentialSectionState extends State<CredentialSection> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.inputs,
      builder: (context, _) {
        final i = widget.inputs;
        final create = i.create;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _MethodSwitch(
              label: widget.switchLabel,
              value: i.useMpin,
              enabled: widget.enabled,
              onChanged: i.setUseMpin,
            ),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween(begin: const Offset(0, 0.06), end: Offset.zero)
                      .animate(anim),
                  child: child,
                ),
              ),
              child: i.useMpin
                  ? Column(
                      key: const ValueKey('mpin'),
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        MpinField(
                          controller: i.mpin,
                          label: create ? 'Set 4-digit MPIN' : 'MPIN',
                          errorText: i.mpinError,
                          enabled: widget.enabled,
                          onCompleted: create ? null : widget.onSubmit,
                        ),
                        if (create) ...[
                          const SizedBox(height: 16),
                          MpinField(
                            controller: i.confirmMpin,
                            label: 'Confirm MPIN',
                            errorText: i.confirmMpinError,
                            enabled: widget.enabled,
                            onCompleted: widget.onSubmit,
                          ),
                        ],
                      ],
                    )
                  : Column(
                      key: const ValueKey('password'),
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: i.password,
                          enabled: widget.enabled,
                          obscureText: _obscure,
                          textInputAction:
                              create ? TextInputAction.next : TextInputAction.done,
                          autofillHints: [
                            create ? AutofillHints.newPassword : AutofillHints.password
                          ],
                          onSubmitted: create ? null : (_) => widget.onSubmit?.call(),
                          decoration: InputDecoration(
                            labelText: create ? 'Create password' : 'Password',
                            errorText: i.passwordError,
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              tooltip: _obscure ? 'Show password' : 'Hide password',
                              icon: Icon(_obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined),
                              onPressed: () => setState(() => _obscure = !_obscure),
                            ),
                          ),
                        ),
                        if (create) ...[
                          const SizedBox(height: 8),
                          _StrengthMeter(controller: i.password),
                          const SizedBox(height: 8),
                          _PasswordChecks(controller: i.password),
                          const SizedBox(height: 12),
                          TextField(
                            controller: i.confirmPassword,
                            enabled: widget.enabled,
                            obscureText: _obscure,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => widget.onSubmit?.call(),
                            decoration: InputDecoration(
                              labelText: 'Confirm password',
                              errorText: i.confirmError,
                              prefixIcon: const Icon(Icons.lock_outline),
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}

/// On/off switch: off = password, on = 4-digit MPIN.
class _MethodSwitch extends StatelessWidget {
  const _MethodSwitch({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: value ? AppColors.royal.withValues(alpha: 0.06) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: value ? AppColors.royal.withValues(alpha: 0.5) : const Color(0xFFD5DBE8)),
      ),
      child: Row(
        children: [
          Icon(Icons.pin_outlined, color: value ? AppColors.royal : AppColors.navy),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, color: AppColors.navy)),
                Text(value ? 'On: quick 4-digit MPIN' : 'Off: use a password',
                    style: const TextStyle(fontSize: 12, color: Colors.black54)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: enabled ? onChanged : null,
            activeThumbColor: AppColors.royal,
          ),
        ],
      ),
    );
  }
}

class _PasswordChecks extends StatelessWidget {
  const _PasswordChecks({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final v = controller.text;
        Widget chip(String text, bool ok) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(ok ? Icons.check_circle : Icons.circle_outlined,
                    size: 14, color: ok ? AppColors.teal : Colors.black38),
                const SizedBox(width: 4),
                Text(text,
                    style: TextStyle(
                        fontSize: 12, color: ok ? AppColors.teal : Colors.black54)),
              ],
            );
        return Wrap(
          spacing: 14,
          runSpacing: 4,
          children: [
            chip('8+ characters', AuthRules.hasMinLength(v)),
            chip('A letter', AuthRules.hasLetter(v)),
            chip('A number', AuthRules.hasDigit(v)),
          ],
        );
      },
    );
  }
}

/// Red / yellow / green progress bar that follows the password as it is typed.
class _StrengthMeter extends StatelessWidget {
  const _StrengthMeter({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final level = AuthRules.passwordStrength(controller.text);
        const colors = [Color(0xFFE1E7F0), Color(0xFFDC2626), Color(0xFFF59E0B), Color(0xFF059669)];
        const labels = ['', 'Weak', 'Fair', 'Strong'];
        return Semantics(
          label: 'Password strength: ${labels[level].isEmpty ? 'none' : labels[level]}',
          child: Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Stack(
                    children: [
                      Container(height: 6, color: const Color(0xFFE1E7F0)),
                      AnimatedFractionallySizedBox(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                        widthFactor: level / 3,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          height: 6,
                          color: colors[level],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: 54,
                child: Text(labels[level],
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colors[level])),
              ),
            ],
          ),
        );
      },
    );
  }
}

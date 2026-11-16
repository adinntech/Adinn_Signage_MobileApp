import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/auth_repository.dart';
import '../domain/auth_rules.dart';
import 'auth_controller.dart';
import 'auth_messages.dart';
import 'widgets/auth_scaffold.dart';
import 'widgets/mpin_field.dart';

/// Shown right after a vendor signs in with the default MPIN the office set (last 4 digits of the vendor ID).
/// Nothing else is reachable until a new MPIN is chosen; the server then ends every session and the vendor signs in again.
class ChangeMpinScreen extends ConsumerStatefulWidget {
  const ChangeMpinScreen({super.key});

  @override
  ConsumerState<ChangeMpinScreen> createState() => _ChangeMpinScreenState();
}

class _ChangeMpinScreenState extends ConsumerState<ChangeMpinScreen> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  String? _currentError;
  String? _nextError;
  String? _confirmError;
  bool _busy = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final cur = _current.text;
    final nxt = _next.text;
    setState(() {
      _currentError = AuthRules.signInMpin(cur);
      _nextError = AuthRules.newMpin(nxt) ?? (nxt == cur ? 'Choose a different MPIN from the current one' : null);
      _confirmError = _confirm.text == nxt ? null : 'MPINs do not match';
    });
    if (_currentError != null || _nextError != null || _confirmError != null) return;
    setState(() => _busy = true);
    try {
      await ref.read(authControllerProvider.notifier).changeMpin(cur, nxt);
      // The controller signed the vendor out; the router now shows the sign-in screen.
    } on AuthFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        if (e.code == 'INVALID_CREDENTIALS') {
          _currentError = 'Current MPIN is incorrect';
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message.isNotEmpty && e.code == 'VALIDATION_ERROR' ? e.message : friendlyAuthMessage(e))));
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Set your MPIN',
      subtitle: 'For safety, replace the default MPIN before you continue',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Your default MPIN is the last 4 digits of your vendor ID.', style: TextStyle(fontSize: 14)),
          const SizedBox(height: 20),
          MpinField(controller: _current, label: 'Current (default) MPIN', errorText: _currentError, enabled: !_busy, autofocus: true),
          const SizedBox(height: 16),
          MpinField(controller: _next, label: 'New 4-digit MPIN', errorText: _nextError, enabled: !_busy),
          const SizedBox(height: 16),
          MpinField(controller: _confirm, label: 'Confirm new MPIN', errorText: _confirmError, enabled: !_busy, onCompleted: _submit),
          const SizedBox(height: 24),
          AuthButton(label: 'Save MPIN', busy: _busy, onPressed: _submit),
        ],
      ),
    );
  }
}

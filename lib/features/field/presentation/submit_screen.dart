import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../data/field_controller.dart';
import '../domain/field_models.dart';

/// C9 – closing odometer, fuel, remarks, the final checklist and submit. Works offline: the
/// submission is queued on the phone and delivered when the sync runs.
class SubmitScreen extends ConsumerStatefulWidget {
  const SubmitScreen({super.key, required this.pid});
  final String pid;

  @override
  ConsumerState<SubmitScreen> createState() => _State();
}

class _State extends ConsumerState<SubmitScreen> {
  final _form = GlobalKey<FormState>();
  final _closing = TextEditingController();
  final _fuel = TextEditingController();
  final _remarks = TextEditingController();
  bool _init = false;

  @override
  void dispose() {
    _closing.dispose();
    _fuel.dispose();
    _remarks.dispose();
    super.dispose();
  }

  void _saveDraft({bool silent = false}) {
    ref.read(fieldControllerProvider.notifier).saveClosing(widget.pid, closingOdometer: int.tryParse(_closing.text.trim()), fuelLitres: double.tryParse(_fuel.text.trim()), remarks: _remarks.text.trim());
    if (!silent && mounted) toast(context, 'Draft saved on this phone');
  }

  Future<void> _submit(Project p) async {
    if (!_form.currentState!.validate()) return;
    _saveDraft(silent: true);
    final fresh = ref.read(fieldControllerProvider).project(widget.pid)!;
    if (!fresh.canSubmit) {
      toast(context, 'Complete every checklist item first', error: true);
      return;
    }
    if (!await confirm(context, title: 'Submit recce?', message: 'Operations will receive ${fresh.doneCount} shop(s) for verification. You cannot edit after submitting.', action: 'Submit')) return;
    ref.read(fieldControllerProvider.notifier).submit(widget.pid);
    if (mounted) {
      toast(context, 'Recce submitted. It will sync when you are online.');
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(fieldControllerProvider).project(widget.pid);
    if (p == null) return Scaffold(appBar: AppBar(), body: const AppEmpty(icon: Icons.search_off, text: 'Project not found.'));
    if (!_init) {
      _init = true;
      _closing.text = p.closingOdometer?.toString() ?? '';
      _fuel.text = p.fuelLitres?.toString() ?? '';
      _remarks.text = p.remarks;
    }
    final closing = int.tryParse(_closing.text.trim());
    final km = (closing != null && p.trip != null) ? closing - p.trip!.openingOdometer : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Submit recce')),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          if (p.submitted)
            Card(
              color: const Color(0xFFD1FAE5),
              child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [const Icon(Icons.verified, color: Color(0xFF059669)), const SizedBox(width: 10), Expanded(child: Text('${p.submit == SubmitState.synced ? 'Delivered to Operations' : 'Saved – waiting to sync'} · ${DateFormat('d MMM, h:mm a').format(p.submittedAt!)}'))])),
            ),
          AppSection(
            title: 'Trip close',
            icon: Icons.speed,
            child: Column(children: [
              TextFormField(
                controller: _closing,
                enabled: !p.submitted,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Closing odometer (km) *', helperText: p.trip == null ? 'Start the trip first' : 'Opening: ${p.trip!.openingOdometer} km'),
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  final n = int.tryParse((v ?? '').trim());
                  if (n == null) return 'Enter the closing odometer';
                  if (p.trip != null && n < p.trip!.openingOdometer) return 'Cannot be less than the opening reading';
                  return null;
                },
              ),
              if (km != null && km >= 0) Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.only(top: 6), child: Text('Distance travelled: $km km', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.navy)))),
              const SizedBox(height: 12),
              TextFormField(controller: _fuel, enabled: !p.submitted, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Fuel filled (litres, optional)')),
              const SizedBox(height: 12),
              TextFormField(controller: _remarks, enabled: !p.submitted, maxLines: 3, decoration: const InputDecoration(labelText: 'Remarks')),
            ]),
          ),
          AppSection(
            title: 'Final checklist',
            icon: Icons.checklist,
            child: Column(children: [
              for (final c in p.checklist)
                ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: Icon(c.$2 ? Icons.check_circle : Icons.radio_button_unchecked, color: c.$2 ? const Color(0xFF059669) : Colors.black38), title: Text(c.$1)),
              ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: const Icon(Icons.receipt_long, color: AppColors.navy), title: Text('Expenses: ${p.expenses.length} item(s) · ₹${p.expenseTotal.toStringAsFixed(0)}')),
              if (p.heldCount > 0) ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: const Icon(Icons.pause_circle, color: AppColors.orange), title: Text('${p.heldCount} shop(s) on hold are not included')),
            ]),
          ),
          if (!p.submitted) ...[
            OutlinedButton.icon(onPressed: _saveDraft, icon: const Icon(Icons.save_outlined), label: const Text('Save draft')),
            const SizedBox(height: 10),
            FilledButton.icon(onPressed: () => _submit(p), icon: const Icon(Icons.send), label: const Text('Submit recce')),
          ],
          const SizedBox(height: 24),
        ]),
      ),
    );
  }
}

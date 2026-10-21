import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/services/photo_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../data/field_controller.dart';
import '../domain/field_models.dart';

/// C8 – expense claim lines with optional receipt photos.
class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key, required this.pid});
  final String pid;

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final e = await showModalBottomSheet<Expense>(context: context, isScrollControlled: true, showDragHandle: true, builder: (_) => const _ExpenseSheet());
    if (e != null) {
      ref.read(fieldControllerProvider.notifier).addExpense(pid, e);
      if (context.mounted) toast(context, 'Expense added');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(fieldControllerProvider).project(pid);
    if (p == null) return Scaffold(appBar: AppBar(), body: const AppEmpty(icon: Icons.search_off, text: 'Project not found.'));
    final byCat = <String, double>{for (final c in expenseCategories) c: p.expenses.where((e) => e.category == c).fold(0.0, (a, e) => a + e.amount)};
    return Scaffold(
      appBar: AppBar(title: const Text('Expense claim')),
      floatingActionButton: p.submitted ? null : FloatingActionButton.extended(onPressed: () => _add(context, ref), icon: const Icon(Icons.add), label: const Text('Add expense')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 96), children: [
        Card(
          color: AppColors.navy,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Total claim', style: TextStyle(color: Colors.white70)),
              Text('₹${p.expenseTotal.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 6, children: [for (final c in byCat.entries.where((e) => e.value > 0)) AppStatusChip('${c.key} ₹${c.value.toStringAsFixed(0)}', color: Colors.white)]),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        if (p.expenses.isEmpty) const AppEmpty(icon: Icons.receipt_long_outlined, text: 'No expenses yet. Add travel, food, stay or other costs with a receipt photo.'),
        for (final e in p.expenses)
          Card(
            child: ListTile(
              leading: e.receiptPath != null ? AppPhotoThumb(path: e.receiptPath!, size: 48) : const CircleAvatar(backgroundColor: AppColors.softBlueBg, child: Icon(Icons.receipt, color: AppColors.navy)),
              title: Text('${e.category} · ₹${e.amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('${DateFormat('d MMM').format(e.date)}${e.note.isEmpty ? '' : ' · ${e.note}'}${e.receiptPath == null ? ' · no receipt' : ''}'),
              trailing: p.submitted
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppColors.error),
                      onPressed: () async {
                        if (await confirm(context, title: 'Delete expense?', message: '${e.category} ₹${e.amount.toStringAsFixed(0)} will be removed.', action: 'Delete')) {
                          ref.read(fieldControllerProvider.notifier).removeExpense(pid, e.id);
                        }
                      },
                    ),
            ),
          ),
      ]),
    );
  }
}

class _ExpenseSheet extends ConsumerStatefulWidget {
  const _ExpenseSheet();
  @override
  ConsumerState<_ExpenseSheet> createState() => _SheetState();
}

class _SheetState extends ConsumerState<_ExpenseSheet> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String _category = expenseCategories.first;
  String? _receipt;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Add expense', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.navy)),
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: [for (final c in expenseCategories) ChoiceChip(label: Text(c), selected: _category == c, onSelected: (_) => setState(() => _category = c))]),
            const SizedBox(height: 14),
            TextFormField(controller: _amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount (₹) *', prefixIcon: Icon(Icons.currency_rupee)), validator: (v) => (double.tryParse((v ?? '').trim()) ?? 0) > 0 ? null : 'Enter an amount greater than 0'),
            const SizedBox(height: 12),
            TextFormField(controller: _note, decoration: const InputDecoration(labelText: 'Note (optional)')),
            const SizedBox(height: 12),
            Row(children: [
              if (_receipt != null) Padding(padding: const EdgeInsets.only(right: 12), child: AppPhotoThumb(path: _receipt!, size: 56)),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final path = await ref.read(photoServiceProvider).pick();
                    if (path != null && mounted) setState(() => _receipt = path);
                  },
                  icon: const Icon(Icons.photo_camera),
                  label: Text(_receipt == null ? 'Receipt photo' : 'Retake'),
                ),
              ),
            ]),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                if (!_form.currentState!.validate()) return;
                Navigator.pop(context, Expense(id: 'e${DateTime.now().microsecondsSinceEpoch}', category: _category, amount: double.parse(_amount.text.trim()), date: DateTime.now(), receiptPath: _receipt, note: _note.text.trim()));
              },
              child: const Text('Save expense'),
            ),
          ]),
        ),
      ),
    );
  }
}

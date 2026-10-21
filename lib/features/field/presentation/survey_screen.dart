import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../data/field_controller.dart';
import '../domain/field_models.dart';

final _gstin = RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$');

/// C5 – shop details, dealer information and one or more boards with W × H and board-specific questions.
class SurveyScreen extends ConsumerStatefulWidget {
  const SurveyScreen({super.key, required this.pid, required this.sid});
  final String pid;
  final String sid;

  @override
  ConsumerState<SurveyScreen> createState() => _State();
}

class _State extends ConsumerState<SurveyScreen> {
  final _form = GlobalKey<FormState>();
  late Survey _survey;
  bool _ready = false;
  int _seq = 0;

  Board _newBoard() => Board(id: 'b${DateTime.now().microsecondsSinceEpoch}_${_seq++}');

  void _init(Shop s) {
    final src = s.survey;
    _survey = Survey(
      dealerName: src?.dealerName.isNotEmpty == true ? src!.dealerName : s.dealerName,
      dealerPhone: src?.dealerPhone.isNotEmpty == true ? src!.dealerPhone : s.phone,
      gstin: src?.gstin ?? '',
      observations: src?.observations ?? '',
      boards: src == null || src.boards.isEmpty ? [_newBoard()] : src.boards.map((b) => Board.fromJson(b.toJson())).toList(),
    );
    _ready = true;
  }

  void _save() {
    if (!_form.currentState!.validate()) {
      toast(context, 'Fix the highlighted fields', error: true);
      return;
    }
    ref.read(fieldControllerProvider.notifier).saveSurvey(widget.pid, widget.sid, _survey);
    toast(context, 'Survey saved');
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(fieldControllerProvider).shop(widget.pid, widget.sid);
    if (s == null) return Scaffold(appBar: AppBar(), body: const AppEmpty(icon: Icons.search_off, text: 'Shop not found.'));
    if (!_ready) _init(s);
    final total = _survey.boards.fold<double>(0, (a, b) => a + b.sqft);

    return Scaffold(
      appBar: AppBar(title: const Text('Shop survey')),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          AppSection(
            title: 'Shop',
            icon: Icons.store,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              Text(s.address, style: const TextStyle(color: Colors.black54)),
            ]),
          ),
          AppSection(
            title: 'Dealer information',
            icon: Icons.person_outline,
            child: Column(children: [
              TextFormField(initialValue: _survey.dealerName, decoration: const InputDecoration(labelText: 'Dealer name *'), onChanged: (v) => _survey.dealerName = v, validator: (v) => (v ?? '').trim().length < 2 ? 'Enter the dealer name' : null),
              const SizedBox(height: 12),
              TextFormField(initialValue: _survey.dealerPhone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Mobile'), onChanged: (v) => _survey.dealerPhone = v, validator: (v) => (v ?? '').trim().isEmpty || RegExp(r'^[6-9]\d{9}$').hasMatch(v!.trim()) ? null : 'Enter a 10-digit mobile'),
              const SizedBox(height: 12),
              TextFormField(initialValue: _survey.gstin, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'GSTIN (optional)'), onChanged: (v) => _survey.gstin = v.toUpperCase(), validator: (v) => (v ?? '').trim().isEmpty || _gstin.hasMatch(v!.trim().toUpperCase()) ? null : 'Enter a valid 15-character GSTIN'),
            ]),
          ),
          for (var i = 0; i < _survey.boards.length; i++)
            _BoardCard(
              key: ValueKey(_survey.boards[i].id),
              index: i,
              board: _survey.boards[i],
              canRemove: _survey.boards.length > 1,
              onChanged: () => setState(() {}),
              onRemove: () async {
                if (await confirm(context, title: 'Remove board ${i + 1}?', message: 'Its measurements will be discarded.', action: 'Remove')) {
                  setState(() => _survey.boards.removeAt(i));
                }
              },
            ),
          OutlinedButton.icon(onPressed: () => setState(() => _survey.boards.add(_newBoard())), icon: const Icon(Icons.add), label: const Text('Add another board')),
          const SizedBox(height: 12),
          Card(
            color: AppColors.softBlueBg,
            child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [const Icon(Icons.calculate_outlined, color: AppColors.navy), const SizedBox(width: 10), Expanded(child: Text('Total area (preview): ${total.toStringAsFixed(1)} sq ft across ${_survey.boards.length} board(s)'))])),
          ),
          const SizedBox(height: 12),
          AppSection(
            title: 'Site observations',
            icon: Icons.notes,
            child: TextFormField(initialValue: _survey.observations, maxLines: 3, decoration: const InputDecoration(hintText: 'Obstructions, lighting, condition of the existing board…'), onChanged: (v) => _survey.observations = v),
          ),
          FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save), label: const Text('Save survey')),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }
}

class _BoardCard extends StatelessWidget {
  const _BoardCard({super.key, required this.index, required this.board, required this.canRemove, required this.onChanged, required this.onRemove});
  final int index;
  final Board board;
  final bool canRemove;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  String? _dim(String? v) => (double.tryParse((v ?? '').trim()) ?? 0) > 0 ? null : 'Required';

  @override
  Widget build(BuildContext context) {
    final type = boardTypes.where((t) => t.name == board.type).firstOrNull;
    return AppSection(
      title: 'Board ${index + 1}',
      icon: Icons.signpost_outlined,
      trailing: canRemove ? IconButton(onPressed: onRemove, icon: const Icon(Icons.delete_outline, color: AppColors.error), tooltip: 'Remove board') : null,
      child: Column(children: [
        DropdownButtonFormField<String>(
          initialValue: board.type.isEmpty ? null : board.type,
          decoration: const InputDecoration(labelText: 'Board type *'),
          items: [for (final t in boardTypes) DropdownMenuItem(value: t.name, child: Text(t.name))],
          validator: (v) => v == null ? 'Select the board type' : null,
          onChanged: (v) {
            board.type = v ?? '';
            board.extras = {}; // questions differ per type
            onChanged();
          },
        ),
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: TextFormField(initialValue: board.width?.toString() ?? '', keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Width (ft) *'), validator: _dim, onChanged: (v) { board.width = double.tryParse(v.trim()); onChanged(); })),
          const SizedBox(width: 10),
          Expanded(child: TextFormField(initialValue: board.height?.toString() ?? '', keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Height (ft) *'), validator: _dim, onChanged: (v) { board.height = double.tryParse(v.trim()); onChanged(); })),
        ]),
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: TextFormField(initialValue: board.mountHeight?.toString() ?? '', keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Mounting height (ft)'), onChanged: (v) => board.mountHeight = double.tryParse(v.trim()))),
          const SizedBox(width: 10),
          Expanded(child: TextFormField(initialValue: '${board.qty}', keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity'), validator: (v) => (int.tryParse((v ?? '').trim()) ?? 0) >= 1 ? null : 'Min 1', onChanged: (v) { board.qty = int.tryParse(v.trim()) ?? 1; onChanged(); })),
        ]),
        if (type != null) ...[
          const Divider(height: 28),
          Align(alignment: Alignment.centerLeft, child: Text('${type.name} questions', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.navy))),
          const SizedBox(height: 10),
          for (final q in type.questions.entries) ...[
            if (q.value.isEmpty)
              TextFormField(key: ValueKey('${board.id}-${q.key}'), initialValue: board.extras[q.key] ?? '', decoration: InputDecoration(labelText: q.key), onChanged: (v) => board.extras[q.key] = v)
            else
              DropdownButtonFormField<String>(key: ValueKey('${board.id}-${q.key}'), initialValue: board.extras[q.key], decoration: InputDecoration(labelText: q.key), items: [for (final o in q.value) DropdownMenuItem(value: o, child: Text(o))], onChanged: (v) => board.extras[q.key] = v ?? ''),
            const SizedBox(height: 12),
          ],
        ],
        Align(alignment: Alignment.centerRight, child: Text('${(board.sqft).toStringAsFixed(1)} sq ft', style: const TextStyle(color: Colors.black54))),
      ]),
    );
  }
}

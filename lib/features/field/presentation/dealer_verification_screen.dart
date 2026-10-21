import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../data/field_controller.dart';
import '../domain/field_models.dart';

/// C3 – call the dealer and record the outcome. Only "reached, open, visit allowed" approves travel.
class DealerVerificationScreen extends ConsumerStatefulWidget {
  const DealerVerificationScreen({super.key, required this.pid, required this.sid});
  final String pid;
  final String sid;

  @override
  ConsumerState<DealerVerificationScreen> createState() => _State();
}

class _State extends ConsumerState<DealerVerificationScreen> {
  VisitOutcome? _outcome;
  final _time = TextEditingController();
  final _note = TextEditingController();
  bool _init = false;

  @override
  void dispose() {
    _time.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(fieldControllerProvider).shop(widget.pid, widget.sid);
    if (s == null) return Scaffold(appBar: AppBar(), body: const AppEmpty(icon: Icons.search_off, text: 'Shop not found.'));
    if (!_init) {
      _init = true;
      _outcome = s.verification?.outcome;
      _time.text = s.verification?.preferredTime ?? '';
      _note.text = s.verification?.note ?? '';
    }
    final holds = _outcome != null && _outcome != VisitOutcome.approved;

    return Scaffold(
      appBar: AppBar(title: const Text('Dealer verification')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        AppSection(
          title: s.name,
          icon: Icons.store,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.address),
            if (s.dealerName.isNotEmpty) Text('Dealer: ${s.dealerName}', style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
              onPressed: s.phone.isEmpty ? null : () => launchUrl(Uri(scheme: 'tel', path: s.phone)),
              icon: const Icon(Icons.call),
              label: Text(s.phone.isEmpty ? 'No phone number on file' : 'Call dealer · ${s.phone}'),
            ),
          ]),
        ),
        AppSection(
          title: 'What happened on the call?',
          icon: Icons.fact_check_outlined,
          child: RadioGroup<VisitOutcome>(
            groupValue: _outcome,
            onChanged: (v) => setState(() => _outcome = v),
            child: Column(children: [
              for (final o in VisitOutcome.values) RadioListTile<VisitOutcome>(contentPadding: EdgeInsets.zero, value: o, title: Text(o.label)),
            ]),
          ),
        ),
        if (holds)
          const Card(color: Color(0xFFFEF3C7), child: Padding(padding: EdgeInsets.all(12), child: Row(children: [Icon(Icons.warning_amber, color: AppColors.orange), SizedBox(width: 10), Expanded(child: Text('This shop will be put on hold. You cannot travel to it until the dealer allows the visit.'))]))),
        AppSection(
          title: 'Details',
          icon: Icons.schedule,
          child: Column(children: [
            TextField(controller: _time, decoration: const InputDecoration(labelText: 'Preferred visit time (e.g. 10:00 – 12:00)')),
            const SizedBox(height: 12),
            TextField(controller: _note, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes')),
          ]),
        ),
        FilledButton.icon(
          onPressed: _outcome == null
              ? null
              : () {
                  ref.read(fieldControllerProvider.notifier).verifyShop(
                        widget.pid,
                        widget.sid,
                        DealerVerification(outcome: _outcome!, at: DateTime.now(), preferredTime: _time.text.trim(), note: _note.text.trim()),
                      );
                  toast(context, _outcome == VisitOutcome.approved ? 'Visit approved' : 'Shop put on hold');
                  context.pop();
                },
          icon: const Icon(Icons.save),
          label: const Text('Save verification'),
        ),
      ]),
    );
  }
}

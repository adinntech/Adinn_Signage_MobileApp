import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/services/photo_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/signature_pad.dart';
import '../data/field_controller.dart';
import '../domain/field_models.dart';

/// C7 – digital recce acknowledgement: sheet details, board table and dealer + staff signatures.
class AcknowledgementScreen extends ConsumerStatefulWidget {
  const AcknowledgementScreen({super.key, required this.pid, required this.sid});
  final String pid;
  final String sid;

  @override
  ConsumerState<AcknowledgementScreen> createState() => _State();
}

class _State extends ConsumerState<AcknowledgementScreen> {
  final _dealerPad = SignaturePadController();
  final _staffPad = SignaturePadController();
  final _contact = TextEditingController();
  final _gstin = TextEditingController();
  String? _dealerPath;
  String? _staffPath;
  String? _sheetPath;
  bool _init = false;
  bool _saving = false;

  @override
  void dispose() {
    _dealerPad.dispose();
    _staffPad.dispose();
    _contact.dispose();
    _gstin.dispose();
    super.dispose();
  }

  Future<void> _save(Shop s) async {
    setState(() => _saving = true);
    try {
      final svc = ref.read(photoServiceProvider);
      var dealer = _dealerPath;
      var staff = _staffPath;
      final d = await _dealerPad.export();
      final st = await _staffPad.export();
      if (d != null) dealer = await svc.saveBytes(d, 'sign_dealer');
      if (st != null) staff = await svc.saveBytes(st, 'sign_staff');
      if (dealer == null || staff == null) {
        if (mounted) toast(context, 'Both the dealer and the staff signature are required', error: true);
        return;
      }
      ref.read(fieldControllerProvider.notifier).saveAck(
            widget.pid,
            widget.sid,
            Acknowledgement(dealerSignPath: dealer, staffSignPath: staff, signedSheetPath: _sheetPath, contact: _contact.text.trim(), gstin: _gstin.text.trim().toUpperCase(), signedAt: DateTime.now()),
          );
      if (mounted) {
        toast(context, 'Acknowledgement saved');
        context.pop();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = ref.watch(fieldControllerProvider);
    final p = f.project(widget.pid);
    final s = f.shop(widget.pid, widget.sid);
    if (p == null || s == null) return Scaffold(appBar: AppBar(), body: const AppEmpty(icon: Icons.search_off, text: 'Shop not found.'));
    if (!_init) {
      _init = true;
      _contact.text = s.ack?.contact.isNotEmpty == true ? s.ack!.contact : (s.survey?.dealerPhone ?? s.phone);
      _gstin.text = s.ack?.gstin.isNotEmpty == true ? s.ack!.gstin : (s.survey?.gstin ?? '');
      _dealerPath = s.ack?.dealerSignPath;
      _staffPath = s.ack?.staffSignPath;
      _sheetPath = s.ack?.signedSheetPath;
    }
    final boards = s.survey?.boards ?? const <Board>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Recce acknowledgement')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Text.rich(TextSpan(children: [TextSpan(text: 'A', style: TextStyle(color: Color(0xFFE11D2E))), TextSpan(text: 'DINN', style: TextStyle(color: AppColors.navy))]), style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 1)),
                const Spacer(),
                Text(DateFormat('d MMM yyyy').format(DateTime.now()), style: const TextStyle(color: Colors.black54)),
              ]),
              const Divider(height: 24),
              const Text('RECCE ACKNOWLEDGEMENT', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5)),
              const SizedBox(height: 10),
              _Row('Client', '${p.client} · ${p.campaign}'),
              _Row('Dealer', s.survey?.dealerName.isNotEmpty == true ? s.survey!.dealerName : s.dealerName),
              _Row('Shop', s.name),
              _Row('Location', '${s.address}, ${s.area}'),
              const SizedBox(height: 8),
              TextField(controller: _contact, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Contact number')),
              const SizedBox(height: 12),
              TextField(controller: _gstin, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'GSTIN')),
            ]),
          ),
        ),
        AppSection(
          title: 'Boards measured',
          icon: Icons.straighten,
          child: boards.isEmpty
              ? const Text('No boards recorded.')
              : Table(columnWidths: const {0: FixedColumnWidth(28), 2: FixedColumnWidth(86)}, children: [
                  const TableRow(children: [Text('#', style: TextStyle(fontWeight: FontWeight.w700)), Text('Type', style: TextStyle(fontWeight: FontWeight.w700)), Text('W × H (ft)', style: TextStyle(fontWeight: FontWeight.w700))]),
                  for (var i = 0; i < boards.length; i++)
                    TableRow(children: [
                      Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text('${i + 1}')),
                      Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(boards[i].type)),
                      Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text('${boards[i].width} × ${boards[i].height}')),
                    ]),
                ]),
        ),
        AppSection(
          title: 'Signatures',
          icon: Icons.draw,
          child: Column(children: [
            if (_dealerPath != null && _dealerPad.isEmpty) _Signed('Dealer signature', _dealerPath!, () => setState(() => _dealerPath = null)) else AppSignaturePad(controller: _dealerPad, label: 'Dealer signature / seal'),
            const SizedBox(height: 16),
            if (_staffPath != null && _staffPad.isEmpty) _Signed('Staff signature', _staffPath!, () => setState(() => _staffPath = null)) else AppSignaturePad(controller: _staffPad, label: 'ADINN staff signature'),
          ]),
        ),
        AppSection(
          title: 'Signed paper sheet (optional)',
          icon: Icons.document_scanner_outlined,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (_sheetPath != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: AppPhotoThumb(path: _sheetPath!, size: 120)),
            OutlinedButton.icon(
              onPressed: () async {
                final path = await ref.read(photoServiceProvider).pick();
                if (path != null && mounted) setState(() => _sheetPath = path);
              },
              icon: const Icon(Icons.photo_camera),
              label: Text(_sheetPath == null ? 'Photograph the signed sheet' : 'Retake'),
            ),
          ]),
        ),
        FilledButton.icon(onPressed: _saving ? null : () => _save(s), icon: const Icon(Icons.verified), label: const Text('Save acknowledgement')),
        const SizedBox(height: 24),
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.k, this.v);
  final String k;
  final String v;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 74, child: Text(k, style: const TextStyle(color: Colors.black54))), Expanded(child: Text(v.isEmpty ? '-' : v, style: const TextStyle(fontWeight: FontWeight.w600)))]));
}

class _Signed extends StatelessWidget {
  const _Signed(this.label, this.path, this.onRedo);
  final String label;
  final String path;
  final VoidCallback onRedo;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))), TextButton.icon(onPressed: onRedo, icon: const Icon(Icons.edit, size: 18), label: const Text('Re-sign'))]),
        Container(height: 110, width: double.infinity, decoration: BoxDecoration(border: Border.all(color: const Color(0xFF059669)), borderRadius: BorderRadius.circular(12)), child: ClipRRect(borderRadius: BorderRadius.circular(12), child: AppPhotoThumb(path: path, size: 110))),
      ]);
}

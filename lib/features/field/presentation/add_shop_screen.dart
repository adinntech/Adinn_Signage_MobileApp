import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/input_formats.dart';
import '../data/field_controller.dart';
import '../data/field_repository.dart';

final _phoneRule = RegExp(r'^[6-9]\d{9}$');
final _gstRule = RegExp(r'^\d{2}[A-Z]{5}\d{4}[A-Z][A-Z\d]Z[A-Z\d]$');

/// ASO survey: the shop list starts empty, so each shop is added here when the recce person reaches it,
/// with their GPS position. The shop then appears in the job and goes through the usual visit steps.
class AddShopScreen extends ConsumerStatefulWidget {
  const AddShopScreen({super.key, required this.pid});
  final String pid;

  @override
  ConsumerState<AddShopScreen> createState() => _AddShopState();
}

class _AddShopState extends ConsumerState<AddShopScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _dealer = TextEditingController();
  final _phone = TextEditingController();
  final _addr1 = TextEditingController();
  final _addr2 = TextEditingController();
  final _area = TextEditingController();
  final _district = TextEditingController();
  final _pin = TextEditingController();
  final _gst = TextEditingController();
  GeoFix? _fix;
  bool _locating = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = ref.read(fieldControllerProvider).project(widget.pid);
    _district.text = p?.district ?? '';
    if (p != null && p.areas.length == 1) _area.text = p.areas.first.name;
    _locate();
  }

  @override
  void dispose() {
    for (final c in [_name, _dealer, _phone, _addr1, _addr2, _area, _district, _pin, _gst]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _locate() async {
    setState(() => _locating = true);
    final fix = await ref.read(locationServiceProvider).current();
    if (mounted) setState(() { _fix = fix; _locating = false; });
  }

  String? _required(String? v, String what) => (v ?? '').trim().isEmpty ? 'Enter $what' : null;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; });
    try {
      final shop = await ref.read(fieldRepositoryProvider).addShop(
            widget.pid,
            ShopDraft(
              shopName: _name.text.trim(), dealerName: _dealer.text.trim(), mobile: _phone.text.trim(), address1: _addr1.text.trim(), address2: _addr2.text.trim(),
              location: _area.text.trim(), district: _district.text.trim(), pincode: _pin.text.trim(), gstin: _gst.text.trim(), lat: _fix?.lat, lng: _fix?.lng,
            ),
          );
      ref.read(fieldControllerProvider.notifier).addShop(widget.pid, shop);
      if (!mounted) return;
      toast(context, '${shop.name} added');
      context.pushReplacement('/project/${widget.pid}/shop/${shop.id}');
    } on ApiException catch (e) {
      if (mounted) setState(() { _saving = false; _error = e.isNetwork ? 'No connection. Connect to the internet and try again.' : e.message; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(fieldControllerProvider).project(widget.pid);
    return Scaffold(
      appBar: AppBar(title: const Text('Add shop')),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          if (p != null) Text('${p.code} · ${p.client}', style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 8),
          Card(
            color: _fix != null ? const Color(0xFFE7F9EF) : const Color(0xFFFFF4E5),
            child: ListTile(
              leading: _locating ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(_fix != null ? Icons.my_location : Icons.location_off, color: _fix != null ? const Color(0xFF059669) : AppColors.orange),
              title: Text(_locating ? 'Finding your position…' : _fix != null ? 'Position captured' : 'GPS not available'),
              subtitle: Text(_fix?.label ?? 'The shop can still be saved; Operations can place it on the map later.'),
              trailing: TextButton(onPressed: _locating ? null : _locate, child: const Text('Retry')),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(controller: _name, textCapitalization: TextCapitalization.words, maxLength: 120, decoration: const InputDecoration(labelText: 'Shop name *', counterText: ''), validator: (v) => _required(v, 'the shop name')),
          const SizedBox(height: 12),
          TextFormField(controller: _dealer, textCapitalization: TextCapitalization.words, maxLength: 120, decoration: const InputDecoration(labelText: 'Dealer / owner name *', counterText: ''), validator: (v) => _required(v, 'the dealer name')),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            inputFormatters: phoneFormat,
            decoration: const InputDecoration(labelText: 'Mobile *', helperText: '10 digits, numbers only', prefixIcon: Icon(Icons.phone)),
            validator: (v) => _phoneRule.hasMatch((v ?? '').trim()) ? null : 'Enter a 10-digit mobile number',
          ),
          const SizedBox(height: 12),
          TextFormField(controller: _addr1, maxLength: 200, decoration: const InputDecoration(labelText: 'Address line 1 *', counterText: ''), validator: (v) => _required(v, 'the address')),
          const SizedBox(height: 12),
          TextFormField(controller: _addr2, maxLength: 200, decoration: const InputDecoration(labelText: 'Address line 2', counterText: '')),
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: TextFormField(controller: _area, textCapitalization: TextCapitalization.words, maxLength: 120, decoration: const InputDecoration(labelText: 'Area / town *', counterText: ''), validator: (v) => _required(v, 'the area'))),
            const SizedBox(width: 12),
            Expanded(child: TextFormField(controller: _district, textCapitalization: TextCapitalization.words, maxLength: 120, decoration: const InputDecoration(labelText: 'District *', counterText: ''), validator: (v) => _required(v, 'the district'))),
          ]),
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: TextFormField(
                controller: _pin,
                keyboardType: TextInputType.number,
                inputFormatters: pincodeFormat,
                decoration: const InputDecoration(labelText: 'Pincode', helperText: '6 digits'),
                validator: (v) => (v ?? '').isEmpty || (v ?? '').length == 6 ? null : 'Enter 6 digits',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _gst,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: gstFormat,
                decoration: const InputDecoration(labelText: 'GSTIN', helperText: '15 characters, optional'),
                validator: (v) => (v ?? '').isEmpty || _gstRule.hasMatch(v!) ? null : 'Not a valid GSTIN',
              ),
            ),
          ]),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.error)),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(onPressed: _saving ? null : _save, icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.add_business), label: Text(_saving ? 'Saving…' : 'Add shop and start visit')),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }
}

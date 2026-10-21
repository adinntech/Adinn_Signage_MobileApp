import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/services/location_service.dart';
import '../../../core/services/photo_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../data/field_controller.dart';
import '../domain/field_models.dart';

const vehicles = ['2 Wheeler', '4 Wheeler', 'Public transport'];

/// C4 – start the trip: opening odometer, odometer photo and GPS.
class TripScreen extends ConsumerStatefulWidget {
  const TripScreen({super.key, required this.pid});
  final String pid;

  @override
  ConsumerState<TripScreen> createState() => _TripScreenState();
}

class _TripScreenState extends ConsumerState<TripScreen> {
  final _form = GlobalKey<FormState>();
  final _odo = TextEditingController();
  String _vehicle = vehicles.first;
  String? _photo;
  GeoFix? _fix;
  bool _locating = false;
  bool _photoMissing = false;

  @override
  void initState() {
    super.initState();
    _locate();
  }

  @override
  void dispose() {
    _odo.dispose();
    super.dispose();
  }

  Future<void> _locate() async {
    setState(() => _locating = true);
    final fix = await ref.read(locationServiceProvider).current();
    if (mounted) setState(() { _fix = fix; _locating = false; });
  }

  Future<void> _snap() async {
    final path = await ref.read(photoServiceProvider).pick();
    if (path != null && mounted) setState(() { _photo = path; _photoMissing = false; });
  }

  void _start() {
    final ok = _form.currentState!.validate();
    if (_photo == null) setState(() => _photoMissing = true);
    if (!ok || _photo == null) return;
    ref.read(fieldControllerProvider.notifier).startTrip(
          widget.pid,
          Trip(startedAt: DateTime.now(), vehicle: _vehicle, openingOdometer: int.parse(_odo.text.trim()), photoPath: _photo!, lat: _fix?.lat, lng: _fix?.lng),
        );
    toast(context, 'Trip started');
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Scaffold(
      appBar: AppBar(title: const Text('Trip start')),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          AppSection(
            title: 'Trip details',
            icon: Icons.event,
            child: Column(children: [
              _ReadRow('Date', DateFormat('d MMM yyyy').format(now)),
              _ReadRow('Time', DateFormat('h:mm a').format(now)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(initialValue: _vehicle, decoration: const InputDecoration(labelText: 'Vehicle type'), items: [for (final v in vehicles) DropdownMenuItem(value: v, child: Text(v))], onChanged: (v) => setState(() => _vehicle = v!)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _odo,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Opening odometer (km) *', prefixIcon: Icon(Icons.speed)),
                validator: (v) => (int.tryParse((v ?? '').trim()) ?? -1) < 0 ? 'Enter the odometer reading' : null,
              ),
            ]),
          ),
          AppSection(
            title: 'Odometer photo *',
            icon: Icons.photo_camera_outlined,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (_photo != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: AppPhotoThumb(path: _photo!, size: 140)),
              OutlinedButton.icon(onPressed: _snap, icon: const Icon(Icons.photo_camera), label: Text(_photo == null ? 'Take odometer photo' : 'Retake')),
              if (_photoMissing) const Padding(padding: EdgeInsets.only(top: 6), child: Text('Take a photo of the odometer', style: TextStyle(color: AppColors.error, fontSize: 12))),
            ]),
          ),
          AppSection(
            title: 'GPS location',
            icon: Icons.my_location,
            child: Row(children: [
              Expanded(
                child: _locating
                    ? const Text('Getting your location…')
                    : Text(_fix == null ? 'GPS unavailable. You can still start the trip; it will be flagged for Operations.' : _fix!.label, style: TextStyle(color: _fix == null ? AppColors.orange : AppColors.navy)),
              ),
              IconButton(onPressed: _locating ? null : _locate, icon: const Icon(Icons.refresh), tooltip: 'Retry GPS'),
            ]),
          ),
          FilledButton.icon(onPressed: _start, icon: const Icon(Icons.play_arrow), label: const Text('Start trip')),
        ]),
      ),
    );
  }
}

class _ReadRow extends StatelessWidget {
  const _ReadRow(this.k, this.v);
  final String k;
  final String v;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [SizedBox(width: 70, child: Text(k, style: const TextStyle(color: Colors.black54))), Text(v, style: const TextStyle(fontWeight: FontWeight.w600))]));
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../data/field_controller.dart';
import 'field_dashboard.dart';

/// Project hub: trip, shops to visit, expenses and final submission.
class ProjectScreen extends ConsumerWidget {
  const ProjectScreen({super.key, required this.pid});
  final String pid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(fieldControllerProvider).project(pid);
    if (p == null) return Scaffold(appBar: AppBar(title: const Text('Project')), body: const AppEmpty(icon: Icons.search_off, text: 'Project not found.'));
    final trip = p.trip;
    return Scaffold(
      appBar: AppBar(title: Text(p.code)),
      body: ListView(children: [
        AppHeaderBand(title: '${p.client} · ${p.campaign}', subtitle: '${p.district} · due ${DateFormat('d MMM yyyy').format(p.dueDate)}'),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            AppSection(
              title: 'Trip',
              icon: Icons.directions_car_outlined,
              trailing: trip != null ? const AppStatusChip('Started', color: Color(0xFF059669)) : const AppStatusChip('Not started', color: AppColors.orange),
              child: trip == null
                  ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Record the opening odometer, a photo and your GPS position before travelling to the first shop.'),
                      const SizedBox(height: 12),
                      FilledButton.icon(onPressed: p.submitted ? null : () => context.push('/project/$pid/trip'), icon: const Icon(Icons.play_arrow), label: const Text('Start trip')),
                    ])
                  : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${trip.vehicle} · opening ${trip.openingOdometer} km'),
                      Text('Started ${DateFormat('d MMM, h:mm a').format(trip.startedAt)}${trip.lat == null ? ' · GPS unavailable' : ''}', style: const TextStyle(color: Colors.black54, fontSize: 13)),
                    ]),
            ),
            AppSection(
              title: 'Shops (${p.doneCount}/${p.shops.length})',
              icon: Icons.storefront_outlined,
              child: Column(children: [
                for (final s in p.shops)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(backgroundColor: shopColor(s).withValues(alpha: 0.14), child: Icon(s.done ? Icons.check : s.held ? Icons.pause : Icons.store, color: shopColor(s))),
                    title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(s.address, maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: AppStatusChip(s.statusLabel, color: shopColor(s)),
                    onTap: () => context.push('/project/$pid/shop/${s.id}'),
                  ),
              ]),
            ),
            AppSection(
              title: 'Expenses',
              icon: Icons.receipt_long_outlined,
              trailing: Text('₹${p.expenseTotal.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.navy)),
              child: OutlinedButton.icon(onPressed: () => context.push('/project/$pid/expenses'), icon: const Icon(Icons.add), label: Text(p.expenses.isEmpty ? 'Add expenses' : '${p.expenses.length} items · manage')),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: p.submitted ? const Color(0xFF059669) : AppColors.royal),
              onPressed: () => context.push('/project/$pid/submit'),
              icon: Icon(p.submitted ? Icons.verified : Icons.send),
              label: Text(p.submitted ? 'Submitted – view summary' : 'Review & submit recce'),
            ),
            const SizedBox(height: 24),
          ]),
        ),
      ]),
    );
  }
}

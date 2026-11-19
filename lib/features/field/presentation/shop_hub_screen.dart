import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/location_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../data/field_controller.dart';
import 'field_dashboard.dart';

String _when(DateTime d) {
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '${d.day} ${m[d.month - 1]} ${d.year}, $h:${d.minute.toString().padLeft(2, '0')} ${d.hour >= 12 ? 'pm' : 'am'}';
}

/// One shop's recce checklist. Each step unlocks only when the previous rule is satisfied.
class ShopHubScreen extends ConsumerWidget {
  const ShopHubScreen({super.key, required this.pid, required this.sid});
  final String pid;
  final String sid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(fieldControllerProvider);
    final p = f.project(pid);
    final s = f.shop(pid, sid);
    if (p == null || s == null) return Scaffold(appBar: AppBar(), body: const AppEmpty(icon: Icons.search_off, text: 'Shop not found.'));
    final base = '/project/$pid/shop/$sid';
    final locked = p.submitted;

    Widget step({required IconData icon, required String title, required String subtitle, required bool done, bool enabled = true, VoidCallback? onTap, String? lockedReason}) {
      final open = enabled && !locked;
      return Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: ListTile(
          leading: CircleAvatar(backgroundColor: done ? const Color(0xFFD1FAE5) : AppColors.softBlueBg, child: Icon(done ? Icons.check : icon, color: done ? const Color(0xFF059669) : AppColors.navy)),
          title: Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: open ? null : Colors.black45)),
          subtitle: Text(enabled ? subtitle : (lockedReason ?? subtitle), style: TextStyle(color: open ? null : Colors.black45)),
          trailing: Icon(open ? Icons.chevron_right : Icons.lock_outline),
          onTap: open ? onTap : () => toast(context, locked ? 'The project is already submitted' : (lockedReason ?? 'Not available yet'), error: true),
        ),
      );
    }

    final needsTrip = !p.tripStarted;
    final canWork = s.canVisit && !needsTrip;

    return Scaffold(
      appBar: AppBar(title: Text(s.name)),
      body: ListView(children: [
        AppHeaderBand(title: s.name, subtitle: '${s.address}${s.dealerName.isEmpty ? '' : ' · ${s.dealerName}'}'),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              AppStatusChip(s.statusLabel, color: shopColor(s)),
              const Spacer(),
              if (s.phone.isNotEmpty) TextButton.icon(onPressed: () => launchUrl(Uri(scheme: 'tel', path: s.phone)), icon: const Icon(Icons.call), label: Text(s.phone)),
            ]),
            if (s.assignedAt != null || s.details.isNotEmpty)
              Card(
                margin: const EdgeInsets.only(top: 6),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (s.assignedAt != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text('Assigned ${_when(s.assignedAt!)}${s.assignedBy.isEmpty ? '' : ' by ${s.assignedBy}'}', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.navy)),
                      ),
                    for (final e in s.details.entries)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          SizedBox(width: 110, child: Text(e.key, style: const TextStyle(color: Colors.black54))),
                          Expanded(child: Text(e.value, style: const TextStyle(fontWeight: FontWeight.w600))),
                        ]),
                      ),
                  ]),
                ),
              ),
            if (s.held)
              Card(
                color: const Color(0xFFFEE2E2),
                child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [const Icon(Icons.pause_circle, color: AppColors.error), const SizedBox(width: 10), Expanded(child: Text('Travel on hold: ${s.verification!.outcome.label}. Call the dealer again to approve this visit.'))])),
              ),
            if (s.canVisit && needsTrip && !locked)
              Card(
                color: const Color(0xFFFFF4E0),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Next: start the trip', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.orange)),
                    const SizedBox(height: 4),
                    const Text('The dealer approved this visit. Record the opening odometer and trip photo once for the project, then come back to check in at this shop.'),
                    const SizedBox(height: 10),
                    SizedBox(width: double.infinity, height: 46, child: FilledButton.icon(onPressed: () => context.push('/project/$pid/trip'), icon: const Icon(Icons.route), label: const Text('Start trip'))),
                  ]),
                ),
              ),
            const SizedBox(height: 6),
            step(
              icon: Icons.phone_in_talk,
              title: '1. Dealer verification',
              subtitle: s.verified ? s.verification!.outcome.label : 'Call the dealer and confirm the shop is open',
              done: s.canVisit,
              onTap: () => context.push('$base/verify'),
            ),
            step(
              icon: Icons.my_location,
              title: '2. Check in at shop (GPS)',
              subtitle: s.checkedIn ? (s.checkInLat == null ? 'Checked in · GPS unavailable' : 'Checked in ${s.checkInLat!.toStringAsFixed(4)}, ${s.checkInLng!.toStringAsFixed(4)}') : 'Confirm you have reached the shop',
              done: s.checkedIn,
              enabled: canWork,
              lockedReason: !s.canVisit ? 'Dealer must approve the visit first' : 'Start the trip from the project screen first',
              onTap: () async {
                final fix = await ref.read(locationServiceProvider).current();
                ref.read(fieldControllerProvider.notifier).checkIn(pid, sid, fix?.lat, fix?.lng);
                if (context.mounted) toast(context, fix == null ? 'Checked in (GPS unavailable)' : 'Checked in at shop');
              },
            ),
            step(
              icon: Icons.straighten,
              title: '3. Survey & board measurements',
              subtitle: s.survey == null ? 'Dealer details, boards and W × H' : '${s.survey!.boards.length} board(s)${s.surveyDone ? '' : ' · incomplete'}',
              done: s.surveyDone,
              enabled: canWork && s.checkedIn,
              lockedReason: !canWork ? 'Verify the dealer and start the trip first' : 'Check in at the shop first',
              onTap: () => context.push('$base/survey'),
            ),
            step(
              icon: Icons.photo_camera,
              title: '4. Photos & marking',
              subtitle: s.photos.isEmpty ? 'Capture the board and mark W × H in green' : '${s.photos.length} photo(s) · ${s.photos.where((p) => p.editedPath != null).length} marked',
              done: s.photosDone,
              enabled: canWork && s.checkedIn,
              lockedReason: 'Check in at the shop first',
              onTap: () => context.push('$base/photos'),
            ),
            step(
              icon: Icons.draw,
              title: '5. Dealer acknowledgement',
              subtitle: s.ackDone ? 'Signed by dealer and staff' : 'Dealer and staff signatures',
              done: s.ackDone,
              enabled: canWork && s.surveyDone,
              lockedReason: 'Complete the survey first',
              onTap: () => context.push('$base/ack'),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: s.done || locked
                  ? null
                  : s.readyToFinish
                      ? () {
                          ref.read(fieldControllerProvider.notifier).finishShop(pid, sid);
                          toast(context, '${s.name} completed');
                          context.pop();
                        }
                      : () => toast(context, 'Complete all five steps first', error: true),
              icon: const Icon(Icons.flag),
              label: Text(s.done ? 'Shop completed' : 'Mark shop completed'),
            ),
          ]),
        ),
      ]),
    );
  }
}

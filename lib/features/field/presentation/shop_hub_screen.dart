import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/location_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../data/field_controller.dart';
import 'field_dashboard.dart';

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
      return Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: ListTile(
          enabled: enabled && !locked,
          leading: CircleAvatar(backgroundColor: done ? const Color(0xFFD1FAE5) : AppColors.softBlueBg, child: Icon(done ? Icons.check : icon, color: done ? const Color(0xFF059669) : AppColors.navy)),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(enabled ? subtitle : (lockedReason ?? subtitle)),
          trailing: Icon(enabled ? Icons.chevron_right : Icons.lock_outline),
          onTap: enabled && !locked ? onTap : () => lockedReason != null ? toast(context, lockedReason, error: true) : null,
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
            if (s.held)
              Card(
                color: const Color(0xFFFEE2E2),
                child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [const Icon(Icons.pause_circle, color: AppColors.error), const SizedBox(width: 10), Expanded(child: Text('Travel on hold: ${s.verification!.outcome.label}. Call the dealer again to approve this visit.'))])),
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

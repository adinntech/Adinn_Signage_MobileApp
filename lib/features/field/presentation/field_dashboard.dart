import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../auth/domain/auth_user.dart';
import '../data/field_controller.dart';
import '../domain/field_models.dart';

Color accentFor(UserRole r) => r == UserRole.vendor ? AppColors.vendor : AppColors.teal;
final _date = DateFormat('d MMM yyyy');

/// C2 – field dashboard: today's plan, assigned projects and the next shops to visit.
class FieldDashboard extends ConsumerWidget {
  const FieldDashboard({super.key, required this.user});
  final AuthUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(fieldControllerProvider);
    final accent = accentFor(user.role);
    final first = user.name.trim().split(' ').first;
    final vendor = user.role == UserRole.vendor;

    if (!f.loaded) return const Center(child: CircularProgressIndicator());

    final next = <(Project, Shop)>[
      for (final p in f.active.where((p) => p.assignment == AssignmentState.accepted && !p.submitted))
        for (final s in p.shops.where((s) => !s.done && !s.held)) (p, s),
    ].take(5).toList();

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        AppHeaderBand(title: 'Hi, ${first.isEmpty ? 'there' : first}', subtitle: "${user.role.label} · ${DateFormat('EEE, d MMM').format(DateTime.now())}", accent: accent),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.2,
              children: [
                AppStatTile(label: vendor ? 'Assigned shops' : "Today's shops", value: f.todayShops, color: AppColors.royal, icon: Icons.storefront),
                AppStatTile(label: 'Pending', value: f.pending, color: AppColors.orange, icon: Icons.hourglass_bottom),
                AppStatTile(label: 'In progress', value: f.inProgress, color: AppColors.teal, icon: Icons.directions_walk),
                AppStatTile(label: 'Completed', value: f.done, color: const Color(0xFF059669), icon: Icons.check_circle),
              ],
            ),
            if (f.awaitingSync > 0) ...[
              const SizedBox(height: 10),
              Card(
                color: const Color(0xFFFFF4E5),
                child: ListTile(
                  leading: const Icon(Icons.cloud_upload_outlined, color: AppColors.orange),
                  title: Text('${f.awaitingSync} submission${f.awaitingSync > 1 ? 's' : ''} waiting to sync'),
                  trailing: TextButton(onPressed: () => ref.read(fieldControllerProvider.notifier).sync(), child: const Text('Sync now')),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Text(vendor ? 'Assigned projects' : 'Assigned projects', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.navy)),
            const SizedBox(height: 8),
            if (f.projects.isEmpty) const AppEmpty(icon: Icons.assignment_outlined, text: 'No projects assigned to you yet.'),
            for (final p in f.projects) ProjectCard(project: p, accent: accent, vendor: vendor),
            if (next.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Next shops', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.navy)),
              const SizedBox(height: 8),
              for (final (p, s) in next)
                Card(
                  child: ListTile(
                    leading: CircleAvatar(backgroundColor: AppColors.softBlueBg, child: const Icon(Icons.store, color: AppColors.navy)),
                    title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('${s.area} · ${p.code}'),
                    trailing: AppStatusChip(s.statusLabel, color: _shopColor(s)),
                    onTap: () => context.push('/project/${p.id}/shop/${s.id}'),
                  ),
                ),
            ],
          ]),
        ),
      ],
    );
  }
}

Color _shopColor(Shop s) => s.done ? const Color(0xFF059669) : s.held ? AppColors.error : s.started ? AppColors.teal : s.canVisit ? AppColors.royal : AppColors.orange;
Color shopColor(Shop s) => _shopColor(s);

class ProjectCard extends ConsumerWidget {
  const ProjectCard({super.key, required this.project, required this.accent, required this.vendor});
  final Project project;
  final Color accent;
  final bool vendor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = project;
    final offered = p.assignment == AssignmentState.offered;
    final declined = p.assignment == AssignmentState.declined;
    final total = p.shops.length;
    final frac = total == 0 ? 0.0 : p.doneCount / total;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: offered || declined ? null : () => context.push('/project/${p.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('${p.client} · ${p.campaign}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.navy))),
              AppStatusChip(
                p.submitted ? 'Submitted' : offered ? 'New offer' : declined ? 'Declined' : p.tripStarted ? 'On trip' : 'Assigned',
                color: p.submitted ? const Color(0xFF059669) : offered ? AppColors.vendor : declined ? AppColors.error : accent,
              ),
            ]),
            const SizedBox(height: 4),
            Text('${p.code} · ${p.district} · due ${_date.format(p.dueDate)}', style: const TextStyle(color: Colors.black54, fontSize: 13)),
            const SizedBox(height: 10),
            ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: frac, minHeight: 8, color: accent, backgroundColor: AppColors.softBlueBg)),
            const SizedBox(height: 6),
            Text('${p.doneCount} of $total shops done${p.heldCount > 0 ? ' · ${p.heldCount} on hold' : ''}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
            if (offered) ...[
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46), foregroundColor: AppColors.error),
                    onPressed: () async {
                      if (await confirm(context, title: 'Decline assignment?', message: '${p.code} will be returned to Operations.', action: 'Decline')) {
                        ref.read(fieldControllerProvider.notifier).respondToAssignment(p.id, accept: false);
                      }
                    },
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46), backgroundColor: accent),
                    onPressed: () {
                      ref.read(fieldControllerProvider.notifier).respondToAssignment(p.id, accept: true);
                      toast(context, 'Assignment accepted');
                    },
                    child: const Text('Accept'),
                  ),
                ),
              ]),
            ],
          ]),
        ),
      ),
    );
  }
}

/// Assignments tab: every project with its shops.
class AssignmentsPage extends ConsumerWidget {
  const AssignmentsPage({super.key, required this.user});
  final AuthUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(fieldControllerProvider);
    if (!f.loaded) return const Center(child: CircularProgressIndicator());
    if (f.projects.isEmpty) return const AppEmpty(icon: Icons.assignment_outlined, text: 'Your assignments will appear here.');
    return ListView(padding: const EdgeInsets.all(16), children: [
      for (final p in f.projects) ProjectCard(project: p, accent: accentFor(user.role), vendor: user.role == UserRole.vendor),
    ]);
  }
}

/// Sync tab: offline queue.
class SyncPage extends ConsumerWidget {
  const SyncPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(fieldControllerProvider);
    final queued = f.projects.where((p) => p.submit == SubmitState.submitted).toList();
    final synced = f.projects.where((p) => p.submit == SubmitState.synced).toList();
    return ListView(padding: const EdgeInsets.all(16), children: [
      AppSection(
        title: 'Offline queue',
        icon: Icons.cloud_sync_outlined,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(queued.isEmpty ? 'Everything is up to date.' : '${queued.length} submission(s) saved on this phone, waiting to upload.'),
          const SizedBox(height: 10),
          for (final p in queued) ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: const Icon(Icons.schedule, color: AppColors.orange), title: Text('${p.code} · ${p.client}'), subtitle: Text('Submitted ${DateFormat('d MMM, h:mm a').format(p.submittedAt!)}')),
          const SizedBox(height: 6),
          FilledButton.icon(onPressed: queued.isEmpty ? null : () { ref.read(fieldControllerProvider.notifier).sync(); toast(context, 'Synced'); }, icon: const Icon(Icons.sync), label: const Text('Sync now')),
        ]),
      ),
      if (synced.isNotEmpty)
        AppSection(title: 'Delivered', icon: Icons.cloud_done_outlined, child: Column(children: [for (final p in synced) ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: const Icon(Icons.check_circle, color: Color(0xFF059669)), title: Text('${p.code} · ${p.client}'))])),
      AppSection(
        title: 'Demo data',
        icon: Icons.science_outlined,
        child: OutlinedButton.icon(
          onPressed: () async {
            if (await confirm(context, title: 'Reset demo data?', message: 'All work saved on this phone for demo projects will be cleared.', action: 'Reset')) {
              await ref.read(fieldControllerProvider.notifier).resetDemo();
            }
          },
          icon: const Icon(Icons.restart_alt),
          label: const Text('Reset demo assignments'),
        ),
      ),
    ]);
  }
}

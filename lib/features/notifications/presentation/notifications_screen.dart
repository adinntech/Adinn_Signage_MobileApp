import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../field/data/field_controller.dart';
import '../data/notifications_controller.dart';

IconData _icon(String kind) => switch (kind) {
      'imported' => Icons.add_business,
      'assigned' => Icons.assignment_turned_in_outlined,
      'cancelled' => Icons.block,
      'approval' => Icons.rule,
      'documents' => Icons.attach_file,
      _ => Icons.notifications_none,
    };

Color _tone(String kind) => switch (kind) {
      'imported' => const Color(0xFF059669),
      'assigned' => AppColors.royal,
      'cancelled' => AppColors.error,
      _ => AppColors.navy,
    };

String _when(DateTime at) {
  final d = DateTime.now().difference(at);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} hr ago';
  return DateFormat('d MMM, h:mm a').format(at);
}

/// Everything the backend told this person: new jobs, and "5 shops added, you now have 13".
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.watch(notificationsProvider);
    final c = ref.read(notificationsProvider.notifier);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [if (n.unread > 0) TextButton(onPressed: c.markAllRead, child: const Text('Read all'))],
      ),
      body: RefreshIndicator(
        onRefresh: c.refresh,
        child: !n.loaded
            ? ListView(children: const [SizedBox(height: 200), Center(child: CircularProgressIndicator())])
            : n.items.isEmpty
                ? ListView(children: const [SizedBox(height: 120), AppEmpty(icon: Icons.notifications_off_outlined, text: 'Nothing yet. New jobs and added shops show up here.')])
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: n.items.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final x = n.items[i];
                      return ListTile(
                        tileColor: x.read ? null : const Color(0xFFF2F7FF),
                        leading: CircleAvatar(backgroundColor: _tone(x.kind).withValues(alpha: 0.12), child: Icon(_icon(x.kind), color: _tone(x.kind))),
                        title: Text(x.title, style: TextStyle(fontWeight: x.read ? FontWeight.w500 : FontWeight.w800)),
                        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(x.text),
                          const SizedBox(height: 2),
                          Text(_when(x.at), style: const TextStyle(fontSize: 12, color: Colors.black54)),
                        ]),
                        isThreeLine: true,
                        onTap: () async {
                          await c.markRead(x.id);
                          final field = ref.read(fieldControllerProvider.notifier);
                          if (ref.read(fieldControllerProvider).project(x.projectId) == null) await field.refresh();
                          if (!context.mounted) return;
                          if (ref.read(fieldControllerProvider).project(x.projectId) != null) {
                            context.push('/project/${x.projectId}');
                          } else {
                            toast(context, 'That job is no longer on your list');
                          }
                        },
                      );
                    },
                  ),
      ),
    );
  }
}

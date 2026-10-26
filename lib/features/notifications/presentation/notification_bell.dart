import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_widgets.dart';
import '../data/notifications_controller.dart';

/// The bell in the top bar: unread count, and a short message when something new arrives while the app is open.
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<NotificationsState>(notificationsProvider, (prev, next) {
      if (next.fresh > 0) {
        final latest = next.items.where((n) => !n.read).firstOrNull;
        toast(context, next.fresh == 1 && latest != null ? latest.title : '${next.fresh} new notifications');
      }
    });
    final unread = ref.watch(notificationsProvider.select((s) => s.unread));
    return IconButton(
      tooltip: unread > 0 ? 'Notifications, $unread unread' : 'Notifications',
      onPressed: () => context.push('/notifications'),
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text(unread > 9 ? '9+' : '$unread'),
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/providers.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../field/data/field_controller.dart';

class AppNotification {
  const AppNotification({required this.id, required this.kind, required this.title, required this.text, required this.at, required this.projectId, required this.projectCode, required this.read});
  final String id;
  /// assigned | imported (shops added) | approval | stage | documents | cancelled | activity
  final String kind;
  final String title;
  final String text;
  final DateTime at;
  final String projectId;
  final String projectCode;
  final bool read;

  AppNotification asRead() => AppNotification(id: id, kind: kind, title: title, text: text, at: at, projectId: projectId, projectCode: projectCode, read: true);

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: '${j['id']}',
        kind: '${j['kind']}',
        title: '${j['title']}',
        text: '${j['text']}',
        at: DateTime.tryParse('${j['at']}')?.toLocal() ?? DateTime.now(),
        projectId: '${j['projectId']}',
        projectCode: '${j['projectCode'] ?? ''}',
        read: j['read'] == true,
      );
}

class NotificationsState {
  const NotificationsState({this.items = const [], this.unread = 0, this.loaded = false, this.error, this.fresh = 0});
  final List<AppNotification> items;
  final int unread;
  final bool loaded;
  final String? error;
  /// How many notifications arrived since the last refresh (the bell shows a short message for them).
  final int fresh;
}

/// What this person was told: new jobs, more shops added to a job they already have, approvals. Polled while the app is
/// open; when new shops arrive the jobs are refreshed too, so the shops are on the phone as soon as the message is.
class NotificationsController extends Notifier<NotificationsState> {
  Timer? _timer;
  final Set<String> _seen = {};
  bool _first = true;

  static const pollEvery = Duration(seconds: 45);
  /// Kinds that mean the job list changed.
  static const _changesJobs = {'imported', 'assigned', 'cancelled'};

  @override
  NotificationsState build() {
    final auth = ref.watch(authControllerProvider);
    ref.onDispose(() => _timer?.cancel());
    if (auth is Authenticated) {
      _first = true;
      _seen.clear();
      Future.microtask(refresh);
      _timer?.cancel();
      _timer = Timer.periodic(pollEvery, (_) => refresh());
    } else {
      _timer?.cancel();
    }
    return const NotificationsState();
  }

  Future<void> refresh() async {
    if (ref.read(authControllerProvider) is! Authenticated) return;
    try {
      final res = await ref.read(apiDioProvider).get<dynamic>('/notifications');
      final data = (res.data as Map)['data'] as Map;
      final items = ((data['items'] as List?) ?? []).map((e) => AppNotification.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      final news = _first ? <AppNotification>[] : items.where((n) => !n.read && !_seen.contains(n.id)).toList();
      _seen.addAll(items.map((n) => n.id));
      _first = false;
      state = NotificationsState(items: items, unread: int.tryParse('${data['unread']}') ?? items.where((n) => !n.read).length, loaded: true, fresh: news.length);
      if (news.any((n) => _changesJobs.contains(n.kind))) await ref.read(fieldControllerProvider.notifier).refresh();
    } on DioException catch (e) {
      final err = ApiException.fromDio(e);
      state = NotificationsState(items: state.items, unread: state.unread, loaded: state.loaded, error: err.isNetwork ? null : err.message);
    }
  }

  Future<void> markRead(String id) async {
    final n = state.items.where((x) => x.id == id).firstOrNull;
    if (n == null || n.read) return;
    state = NotificationsState(items: [for (final x in state.items) x.id == id ? x.asRead() : x], unread: state.unread > 0 ? state.unread - 1 : 0, loaded: true);
    try {
      await ref.read(apiDioProvider).post<dynamic>('/notifications/$id/read', data: <String, dynamic>{});
    } on DioException {
      // it is read on the phone; the server copy is marked on the next successful open
    }
  }

  Future<void> markAllRead() async {
    state = NotificationsState(items: [for (final x in state.items) x.asRead()], unread: 0, loaded: true);
    try {
      await ref.read(apiDioProvider).post<dynamic>('/notifications/read', data: <String, dynamic>{});
    } on DioException {
      // see markRead
    }
  }
}

final notificationsProvider = NotifierProvider<NotificationsController, NotificationsState>(NotificationsController.new);

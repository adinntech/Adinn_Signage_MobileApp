import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signage/core/network/providers.dart';
import 'package:signage/features/auth/domain/auth_user.dart';
import 'package:signage/features/auth/presentation/auth_controller.dart';
import 'package:signage/features/field/data/field_controller.dart';
import 'package:signage/features/field/data/field_repository.dart';
import 'package:signage/features/field/data/field_store.dart';
import 'package:signage/features/field/domain/field_models.dart';
import 'package:signage/features/notifications/data/notifications_controller.dart';
import 'package:signage/features/notifications/presentation/notifications_screen.dart';

class _MemStore implements FieldStore {
  final Map<String, List<Project>> data = {};
  @override
  Future<List<Project>?> load(String userId) async => data[userId];
  @override
  Future<void> save(String userId, List<Project> projects) async => data[userId] = projects;
  @override
  Future<void> clear(String userId) async => data.remove(userId);
}

class _FixedAuth extends AuthController {
  @override
  AuthState build() => Authenticated(const AuthUser(id: 'u1', name: 'Ravi Kumar', email: 'r@adinn.co.in', role: UserRole.recceExecutive, isActive: true));
}

class _CountingRepo extends FieldRepository {
  _CountingRepo() : super(Dio());
  int fetches = 0;
  @override
  Future<List<Project>> fetchJobs({required bool vendor}) async {
    fetches++;
    return [];
  }
}

/// Answers GET /notifications with whatever [body] holds, and records the read calls.
class _Server implements HttpClientAdapter {
  Map<String, dynamic> body = {'items': <Object>[], 'unread': 0};
  final List<String> calls = [];
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    calls.add('${options.method} ${options.path}');
    final json = jsonEncode({'success': true, 'data': options.method == 'GET' ? body : {'ok': true}});
    return ResponseBody.fromString(json, 200, headers: {Headers.contentTypeHeader: ['application/json']});
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _n(String id, String title, String text, {bool read = false, String kind = 'imported'}) =>
    {'id': id, 'kind': kind, 'title': title, 'text': text, 'at': DateTime.now().toIso8601String(), 'projectId': 'p1', 'projectCode': '22070292', 'client': 'Adinn', 'read': read};

(ProviderContainer, _Server, _CountingRepo) _setup() {
  final server = _Server();
  final repo = _CountingRepo();
  final dio = Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = server;
  final c = ProviderContainer(overrides: [
    authControllerProvider.overrideWith(_FixedAuth.new),
    fieldStoreProvider.overrideWithValue(_MemStore()),
    fieldRepositoryProvider.overrideWithValue(repo),
    demoDataProvider.overrideWithValue(false),
    apiDioProvider.overrideWithValue(dio),
  ]);
  addTearDown(c.dispose);
  return (c, server, repo);
}

void main() {
  test('new shops arrive as a notification, and the jobs are refreshed so the shops are on the phone', () async {
    final (c, server, repo) = _setup();
    server.body = {'items': [_n('a', 'New shops assigned: 22070292', '8 shops in project 22070292 are assigned to you.', read: true)], 'unread': 0};
    c.read(fieldControllerProvider);
    c.read(notificationsProvider);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(c.read(notificationsProvider).loaded, isTrue);
    expect(c.read(notificationsProvider).fresh, 0); // what was already there is not "new"
    final jobsBefore = repo.fetches;

    server.body = {
      'items': [_n('b', '5 shops added: 22070292', '5 shops were added to project 22070292. You now have 13 shops in this project.'), _n('a', 'New shops assigned: 22070292', '8 shops in project 22070292 are assigned to you.', read: true)],
      'unread': 1,
    };
    await c.read(notificationsProvider.notifier).refresh();
    final s = c.read(notificationsProvider);
    expect(s.unread, 1);
    expect(s.fresh, 1);
    expect(s.items.first.text, contains('You now have 13 shops'));
    expect(repo.fetches, jobsBefore + 1);

    // the same notification is not announced twice
    await c.read(notificationsProvider.notifier).refresh();
    expect(c.read(notificationsProvider).fresh, 0);
    expect(repo.fetches, jobsBefore + 1);
  });

  test('reading a notification updates the count and tells the server', () async {
    final (c, server, _) = _setup();
    server.body = {'items': [_n('b', '5 shops added: 22070292', 'text')], 'unread': 1};
    c.read(notificationsProvider);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await c.read(notificationsProvider.notifier).markRead('b');
    expect(c.read(notificationsProvider).unread, 0);
    expect(c.read(notificationsProvider).items.single.read, isTrue);
    expect(server.calls, contains('POST /notifications/b/read'));
    await c.read(notificationsProvider.notifier).markAllRead();
    expect(server.calls, contains('POST /notifications/read'));
  });

  testWidgets('the list shows each message, unread first look', (tester) async {
    final (c, server, _) = _setup();
    server.body = {'items': [_n('b', '5 shops added: 22070292', 'You now have 13 shops in this project.'), _n('a', 'New shops assigned: 22070292', '8 shops are assigned to you.', read: true)], 'unread': 1};
    await tester.runAsync(() async {
      c.read(notificationsProvider);
      await Future<void>.delayed(const Duration(milliseconds: 80));
    });
    await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const MaterialApp(home: NotificationsScreen())));
    await tester.pump();
    expect(find.text('5 shops added: 22070292'), findsOneWidget);
    expect(find.textContaining('You now have 13 shops'), findsOneWidget);
    expect(find.text('Read all'), findsOneWidget);
  });
}

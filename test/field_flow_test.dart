import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signage/features/auth/domain/auth_user.dart';
import 'package:signage/features/auth/presentation/auth_controller.dart';
import 'package:signage/features/field/data/field_controller.dart';
import 'package:signage/features/field/data/field_store.dart';
import 'package:signage/features/field/domain/field_models.dart';
import 'package:signage/features/field/presentation/field_dashboard.dart';

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
  _FixedAuth(this.user);
  final AuthUser user;
  @override
  AuthState build() => Authenticated(user);
}

AuthUser _u(UserRole r) => AuthUser(id: 'u1', name: 'Ravi Kumar', email: 'r@adinn.co.in', role: r, isActive: true);

ProviderContainer _container(UserRole role, {_MemStore? store}) {
  final c = ProviderContainer(overrides: [
    authControllerProvider.overrideWith(() => _FixedAuth(_u(role))),
    fieldStoreProvider.overrideWithValue(store ?? _MemStore()),
  ]);
  addTearDown(c.dispose);
  return c;
}

Future<void> _load(ProviderContainer c) async {
  c.read(fieldControllerProvider);
  await Future<void>.delayed(const Duration(milliseconds: 20));
}

Board _board() => Board(id: 'b1', type: 'GSB', width: 10, height: 4);

void _complete(FieldController f, String pid, String sid) {
  f.verifyShop(pid, sid, DealerVerification(outcome: VisitOutcome.approved, at: DateTime.now()));
  f.checkIn(pid, sid, 11.0, 78.0);
  f.saveSurvey(pid, sid, Survey(dealerName: 'Murugan', boards: [_board()]));
  f.addPhoto(pid, sid, PhotoRec(id: 'ph$sid', kind: PhotoKind.front, originalPath: 'o.jpg', editedPath: 'm.png', at: DateTime.now()));
  f.saveAck(pid, sid, Acknowledgement(dealerSignPath: 'd.png', staffSignPath: 's.png'));
}

void main() {
  group('dealer verification rules', () {
    test('only a reached dealer who allows the visit approves travel', () {
      for (final o in VisitOutcome.values) {
        final s = Shop(id: 's', name: 'S', address: 'A', area: 'X')..verification = DealerVerification(outcome: o, at: DateTime.now());
        expect(s.canVisit, o == VisitOutcome.approved, reason: o.name);
        expect(s.held, o != VisitOutcome.approved, reason: o.name);
      }
    });

    test('an unverified shop is neither approved nor on hold', () {
      final s = Shop(id: 's', name: 'S', address: 'A', area: 'X');
      expect(s.canVisit, isFalse);
      expect(s.held, isFalse);
      expect(s.statusLabel, 'Pending');
    });
  });

  group('controller', () {
    test('loads only the signed-in user\'s demo assignments and persists them', () async {
      final store = _MemStore();
      final c = _container(UserRole.recceExecutive, store: store);
      await _load(c);
      final st = c.read(fieldControllerProvider);
      expect(st.loaded, isTrue);
      expect(st.projects.length, 2);
      expect(st.todayShops, 8);
      expect(store.data['u1'], isNotNull);
    });

    test('a no-answer shop cannot be finished and a project cannot be submitted early', () async {
      final c = _container(UserRole.recceExecutive);
      await _load(c);
      final f = c.read(fieldControllerProvider.notifier);
      f.verifyShop('p1', 's1', DealerVerification(outcome: VisitOutcome.noAnswer, at: DateTime.now()));
      expect(c.read(fieldControllerProvider).shop('p1', 's1')!.held, isTrue);
      expect(f.finishShop('p1', 's1'), isFalse);
      expect(f.submit('p1'), isFalse);
    });

    test('full flow: shop completes, then project submits only with closing odometer', () async {
      final c = _container(UserRole.recceExecutive);
      await _load(c);
      final f = c.read(fieldControllerProvider.notifier);
      // Keep the project to one shop so the checklist is satisfiable.
      final p = c.read(fieldControllerProvider).project('p2')!;
      p.shops.removeWhere((s) => s.id != 's6');
      _complete(f, 'p2', 's6');
      expect(f.finishShop('p2', 's6'), isTrue);

      f.startTrip('p2', Trip(startedAt: DateTime.now(), vehicle: '2 Wheeler', openingOdometer: 1000, photoPath: 'odo.jpg'));
      expect(f.submit('p2'), isFalse, reason: 'closing odometer missing');
      f.saveClosing('p2', closingOdometer: 900);
      expect(f.submit('p2'), isFalse, reason: 'closing below opening');
      f.saveClosing('p2', closingOdometer: 1042, fuelLitres: 1.2, remarks: 'ok');
      expect(c.read(fieldControllerProvider).project('p2')!.distanceKm, 42);
      expect(f.submit('p2'), isTrue);
      expect(c.read(fieldControllerProvider).awaitingSync, 1);
      f.sync();
      expect(c.read(fieldControllerProvider).project('p2')!.submit, SubmitState.synced);
    });

    test('vendors see offers that can be declined', () async {
      final c = _container(UserRole.vendor);
      await _load(c);
      expect(c.read(fieldControllerProvider).project('p2')!.assignment, AssignmentState.offered);
      c.read(fieldControllerProvider.notifier).respondToAssignment('p2', accept: false);
      final st = c.read(fieldControllerProvider);
      expect(st.project('p2')!.assignment, AssignmentState.declined);
      expect(st.active.length, 1);
    });

    test('drafts survive a JSON round trip', () async {
      final c = _container(UserRole.recceExecutive);
      await _load(c);
      _complete(c.read(fieldControllerProvider.notifier), 'p1', 's1');
      final p = c.read(fieldControllerProvider).project('p1')!;
      final back = Project.fromJson(p.toJson());
      expect(back.shops.first.surveyDone, isTrue);
      expect(back.shops.first.ackDone, isTrue);
      expect(back.shops.first.photos.first.editedPath, 'm.png');
      expect(back.shops.first.checkedIn, isTrue);
    });
  });

  testWidgets('dashboard shows the plan and assigned projects', (tester) async {
    final c = _container(UserRole.recceExecutive);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: MaterialApp(home: Scaffold(body: FieldDashboard(user: _u(UserRole.recceExecutive)))),
    ));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text("Today's shops"), findsOneWidget);
    expect(find.text('8'), findsNWidgets(2)); // today's shops and pending are both 8 on a fresh load
    expect(find.textContaining('AMUL'), findsWidgets);
  });

  testWidgets('vendor dashboard offers Accept and Decline', (tester) async {
    final c = _container(UserRole.vendor);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: MaterialApp(home: Scaffold(body: FieldDashboard(user: _u(UserRole.vendor)))),
    ));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.drag(find.byType(ListView).first, const Offset(0, -400));
    await tester.pump();
    expect(find.text('Accept'), findsOneWidget);
    expect(find.text('Decline'), findsOneWidget);
    await tester.tap(find.text('Accept'));
    await tester.pump();
    expect(c.read(fieldControllerProvider).project('p2')!.assignment, AssignmentState.accepted);
  });
}

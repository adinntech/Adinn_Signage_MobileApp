import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:signage/core/network/api_exception.dart';
import 'package:signage/core/services/location_service.dart';
import 'package:signage/core/widgets/input_formats.dart';
import 'package:signage/features/auth/domain/auth_user.dart';
import 'package:signage/features/auth/presentation/auth_controller.dart';
import 'package:signage/features/field/data/field_controller.dart';
import 'package:signage/features/field/data/field_repository.dart';
import 'package:signage/features/field/data/field_store.dart';
import 'package:signage/features/field/domain/field_models.dart';
import 'package:signage/features/field/presentation/add_shop_screen.dart';

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

class _FakeRepo extends FieldRepository {
  _FakeRepo(this.jobs) : super(Dio());
  List<Project> jobs;
  ApiException? failure;
  ShopDraft? lastDraft;

  @override
  Future<List<Project>> fetchJobs({required bool vendor}) async {
    if (failure != null) throw failure!;
    return jobs;
  }

  @override
  Future<Shop> addShop(String projectId, ShopDraft draft) async {
    lastDraft = draft;
    return Shop(id: 'new1', name: draft.shopName, address: draft.address1, area: draft.location, dealerName: draft.dealerName, phone: draft.mobile, lat: draft.lat, lng: draft.lng);
  }
}

class _FixedGps extends LocationService {
  const _FixedGps();
  @override
  Future<GeoFix?> current() async => const GeoFix(9.9252, 78.1198);
}

Project _aso({List<Shop>? shops}) => Project(
      id: 'aso1', code: '22070292', client: 'Adinn', campaign: 'Area survey', district: 'Madurai', dueDate: DateTime(2026, 12, 1),
      requirementType: 'ASO', shops: shops ?? [], areas: const [JobArea(name: 'Theppakulam', address: 'Near Theppakulam bus stop, Madurai', approxShops: 25)],
    );

ProviderContainer _container(_FakeRepo repo, {_MemStore? store}) {
  final c = ProviderContainer(overrides: [
    authControllerProvider.overrideWith(_FixedAuth.new),
    fieldStoreProvider.overrideWithValue(store ?? _MemStore()),
    fieldRepositoryProvider.overrideWithValue(repo),
    demoDataProvider.overrideWithValue(false),
    locationServiceProvider.overrideWithValue(const _FixedGps()),
  ]);
  addTearDown(c.dispose);
  return c;
}

Future<void> _settle(ProviderContainer c) async {
  c.read(fieldControllerProvider);
  await Future<void>.delayed(const Duration(milliseconds: 30));
}

String _apply(List<TextInputFormatter> formatters, String typed) {
  var v = const TextEditingValue();
  for (var i = 1; i <= typed.length; i++) {
    final next = TextEditingValue(text: typed.substring(0, i), selection: TextSelection.collapsed(offset: i));
    var out = next;
    for (final f in formatters) {
      out = f.formatEditUpdate(v, out);
    }
    v = out;
  }
  return v.text;
}

void main() {
  group('jobs come from the backend', () {
    test('an ASO job starts with its places and no shops', () async {
      final c = _container(_FakeRepo([_aso()]));
      await _settle(c);
      final f = c.read(fieldControllerProvider);
      expect(f.loaded, isTrue);
      expect(f.error, isNull);
      expect(f.projects.single.isAso, isTrue);
      expect(f.projects.single.shops, isEmpty);
      expect(f.projects.single.areas.single.address, contains('Theppakulam'));
    });

    test('offline: the saved jobs stay and the person is told', () async {
      final store = _MemStore();
      store.data['u1'] = [_aso()];
      final repo = _FakeRepo([])..failure = const ApiException(code: ApiException.networkCode, message: 'down');
      final c = _container(repo, store: store);
      await _settle(c);
      final f = c.read(fieldControllerProvider);
      expect(f.projects, hasLength(1));
      expect(f.error, contains('offline'));
    });

    test('a refresh keeps the work done on the phone and takes the new description', () {
      final doneShop = Shop(id: 's1', name: 'Old name', address: 'Old', area: 'X')
        ..verification = DealerVerification(outcome: VisitOutcome.approved, at: DateTime(2026, 11, 5))
        ..done = true;
      final local = [_aso(shops: [doneShop])..trip = Trip(startedAt: DateTime(2026, 11, 5), vehicle: 'Bike', openingOdometer: 100, photoPath: 'p.jpg')];
      final remote = [_aso(shops: [Shop(id: 's1', name: 'New name', address: 'New address', area: 'Y', lat: 9.9, lng: 78.1), Shop(id: 's2', name: 'Second', address: 'A', area: 'Z')])];
      final merged = mergeJobs(local, remote).single;
      expect(merged.shops.map((s) => s.name), ['New name', 'Second']);
      expect(merged.shops.first.done, isTrue);
      expect(merged.shops.first.canVisit, isTrue);
      expect(merged.shops.first.lat, 9.9);
      expect(merged.trip?.openingOdometer, 100);
    });

    test('a shop the server accepted is added once', () async {
      final c = _container(_FakeRepo([_aso()]));
      await _settle(c);
      final shop = Shop(id: 'new1', name: 'Murugan Stores', address: 'Main Rd', area: 'Theppakulam');
      c.read(fieldControllerProvider.notifier).addShop('aso1', shop);
      c.read(fieldControllerProvider.notifier).addShop('aso1', shop);
      expect(c.read(fieldControllerProvider).project('aso1')!.shops, hasLength(1));
    });

    test('the new job fields survive the JSON round trip', () {
      final back = Project.fromJson(_aso(shops: [Shop(id: 's', name: 'S', address: 'A', area: 'X', lat: 1.5, lng: 2.5)]).toJson());
      expect(back.isAso, isTrue);
      expect(back.areas.single.approxShops, 25);
      expect(back.shops.single.lng, 2.5);
    });
  });

  group('typed input is limited', () {
    test('a phone number is 10 digits and nothing else', () {
      expect(_apply(phoneFormat, '98a43-011 122 999'), '9843011122');
      expect(_apply(phoneFormat, '+91 98430 11122'), '9198430111');
    });
    test('pincode, amounts, GST and PAN', () {
      expect(_apply(pincodeFormat, '6292x51 9'), '629251');
      expect(_apply(decimalFormat(), '12.345.6'), '12.34');
      expect(_apply(decimalFormat(), 'ab'), '');
      expect(_apply(digitsFormat(7), '12ab345678'), '1234567');
      expect(_apply(gstFormat, '33aaaca2094m1zk!!x'), '33AAACA2094M1ZK');
      expect(_apply(panFormat, 'abcde1234f9'), 'ABCDE1234F');
    });
  });

  group('add shop screen', () {
    Future<(ProviderContainer, _FakeRepo)> open(WidgetTester tester) async {
      final repo = _FakeRepo([_aso()]);
      final c = _container(repo);
      await tester.runAsync(() => _settle(c));
      final router = GoRouter(routes: [
        GoRoute(path: '/', builder: (_, _) => const AddShopScreen(pid: 'aso1')),
        GoRoute(path: '/project/:pid/shop/:sid', builder: (_, _) => const Scaffold(body: Text('shop hub'))),
      ]);
      await tester.pumpWidget(UncontrolledProviderScope(container: c, child: MaterialApp.router(routerConfig: router)));
      await tester.pump(const Duration(milliseconds: 50));
      return (c, repo);
    }

    testWidgets('keeps letters out of the phone, checks it and saves with the GPS position', (tester) async {
      tester.view.physicalSize = const Size(800, 2400); // tall enough that every field is built
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final (c, repo) = await open(tester);
      expect(find.text('Position captured'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextFormField, 'Shop name *'), 'Murugan Stores');
      await tester.enterText(find.widgetWithText(TextFormField, 'Dealer / owner name *'), 'Murugan');
      await tester.enterText(find.widgetWithText(TextFormField, 'Address line 1 *'), '12 Main Road');
      await tester.enterText(find.widgetWithText(TextFormField, 'Mobile *'), '98abc43');
      await tester.ensureVisible(find.text('Add shop and start visit'));
      await tester.tap(find.text('Add shop and start visit'));
      await tester.pump();
      expect(find.text('Enter a 10-digit mobile number'), findsOneWidget);
      expect(repo.lastDraft, isNull);

      await tester.enterText(find.widgetWithText(TextFormField, 'Mobile *'), '98430111223344');
      final phoneField = tester.widget<TextFormField>(find.widgetWithText(TextFormField, 'Mobile *'));
      expect(phoneField.controller!.text, '9843011122');
      await tester.ensureVisible(find.text('Add shop and start visit'));
      await tester.tap(find.text('Add shop and start visit'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(repo.lastDraft?.mobile, '9843011122');
      expect(repo.lastDraft?.district, 'Madurai'); // taken from the job
      expect(repo.lastDraft?.location, 'Theppakulam'); // the only place of the job
      expect(repo.lastDraft?.lat, 9.9252);
      expect(c.read(fieldControllerProvider).project('aso1')!.shops.single.name, 'Murugan Stores');
      await tester.pumpAndSettle();
      expect(find.text('shop hub'), findsOneWidget); // goes straight into the visit
    });
  });
}

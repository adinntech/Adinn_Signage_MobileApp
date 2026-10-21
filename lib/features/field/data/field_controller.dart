import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_controller.dart';
import '../domain/field_models.dart';
import 'field_store.dart';

class FieldState {
  const FieldState({this.loaded = false, this.projects = const [], this.rev = 0});
  final bool loaded;
  final List<Project> projects;
  /// Bumped on every change so widgets rebuild even though models are mutated in place.
  final int rev;

  Project? project(String id) => projects.where((p) => p.id == id).firstOrNull;
  Shop? shop(String pid, String sid) => project(pid)?.shops.where((s) => s.id == sid).firstOrNull;

  Iterable<Project> get active => projects.where((p) => p.assignment != AssignmentState.declined);
  int get todayShops => active.fold(0, (a, p) => a + p.shops.length);
  int get done => active.fold(0, (a, p) => a + p.doneCount);
  int get inProgress => active.fold(0, (a, p) => a + p.inProgressCount);
  int get pending => active.fold(0, (a, p) => a + p.pendingCount);
  int get awaitingSync => projects.where((p) => p.submit == SubmitState.submitted).length;
}

/// Only the authenticated user's own assignments are ever loaded (storage is keyed per user).
class FieldController extends Notifier<FieldState> {
  String? _user;
  bool _vendor = false;

  @override
  FieldState build() {
    final auth = ref.watch(authControllerProvider);
    if (auth is Authenticated) {
      _user = auth.user.id;
      _vendor = auth.user.role.name == 'vendor';
      Future.microtask(_load);
    } else {
      _user = null;
    }
    return const FieldState();
  }

  FieldStore get _store => ref.read(fieldStoreProvider);

  Future<void> _load() async {
    final u = _user;
    if (u == null) return;
    final saved = await _store.load(u);
    final projects = saved ?? demoProjects(vendor: _vendor);
    if (saved == null) await _store.save(u, projects);
    if (_user == u) state = FieldState(loaded: true, projects: projects, rev: state.rev + 1);
  }

  void _commit() {
    state = FieldState(loaded: true, projects: state.projects, rev: state.rev + 1);
    final u = _user;
    if (u != null) _store.save(u, state.projects);
  }

  /// Apply a change to a shop and persist it.
  void _shop(String pid, String sid, void Function(Shop s) fn) {
    final s = state.shop(pid, sid);
    if (s == null) return;
    fn(s);
    _commit();
  }

  void _project(String pid, void Function(Project p) fn) {
    final p = state.project(pid);
    if (p == null) return;
    fn(p);
    _commit();
  }

  void respondToAssignment(String pid, {required bool accept}) =>
      _project(pid, (p) => p.assignment = accept ? AssignmentState.accepted : AssignmentState.declined);

  void verifyShop(String pid, String sid, DealerVerification v) => _shop(pid, sid, (s) => s.verification = v);

  void startTrip(String pid, Trip t) => _project(pid, (p) => p.trip = t);

  void checkIn(String pid, String sid, double? lat, double? lng) => _shop(pid, sid, (s) {
        s.checkInAt = DateTime.now();
        s.checkInLat = lat;
        s.checkInLng = lng;
      });

  void saveSurvey(String pid, String sid, Survey survey) => _shop(pid, sid, (s) => s.survey = survey);

  void addPhoto(String pid, String sid, PhotoRec p) => _shop(pid, sid, (s) => s.photos.add(p));

  void updatePhoto(String pid, String sid, PhotoRec p) => _shop(pid, sid, (_) {});

  void removePhoto(String pid, String sid, String photoId) => _shop(pid, sid, (s) => s.photos.removeWhere((p) => p.id == photoId));

  void saveAck(String pid, String sid, Acknowledgement a) => _shop(pid, sid, (s) => s.ack = a);

  /// A shop can only be finished when verified, measured, photographed (marked) and acknowledged.
  bool finishShop(String pid, String sid) {
    final s = state.shop(pid, sid);
    if (s == null || !s.readyToFinish) return false;
    _shop(pid, sid, (s) => s.done = true);
    return true;
  }

  void addExpense(String pid, Expense e) => _project(pid, (p) => p.expenses.add(e));

  void removeExpense(String pid, String id) => _project(pid, (p) => p.expenses.removeWhere((e) => e.id == id));

  void saveClosing(String pid, {int? closingOdometer, double? fuelLitres, String remarks = ''}) =>
      _project(pid, (p) {
        p.closingOdometer = closingOdometer;
        p.fuelLitres = fuelLitres;
        p.remarks = remarks;
      });

  bool submit(String pid) {
    final p = state.project(pid);
    if (p == null || !p.canSubmit) return false;
    _project(pid, (p) {
      p.submit = SubmitState.submitted;
      p.submittedAt = DateTime.now();
    });
    return true;
  }

  /// Marks queued submissions as delivered. The real implementation uploads to /api/v1 and retries on failure.
  void sync() {
    for (final p in state.projects) {
      if (p.submit == SubmitState.submitted) p.submit = SubmitState.synced;
    }
    _commit();
  }

  Future<void> resetDemo() async {
    final u = _user;
    if (u == null) return;
    await _store.clear(u);
    await _load();
  }
}

final fieldControllerProvider = NotifierProvider<FieldController, FieldState>(FieldController.new);

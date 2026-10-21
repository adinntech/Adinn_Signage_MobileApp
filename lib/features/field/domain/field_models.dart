/// Field recce domain. Everything is JSON-serializable so drafts survive being offline.
/// Business rules (status, completeness, areas) live here and mirror what the backend will own.
library;

DateTime _dt(Object? v) => DateTime.tryParse('$v') ?? DateTime.now();
double? _d(Object? v) => v == null ? null : double.tryParse('$v');

enum VisitOutcome {
  approved('Reached – shop open, visit allowed'),
  noAnswer('No answer'),
  shopClosed('Shop is closed'),
  declined('Dealer declined the visit');

  const VisitOutcome(this.label);
  final String label;
}

/// Only a reached dealer who allowed the visit unlocks travel; everything else holds the shop.
class DealerVerification {
  const DealerVerification({
    required this.outcome,
    required this.at,
    this.preferredTime = '',
    this.note = '',
  });
  final VisitOutcome outcome;
  final DateTime at;
  final String preferredTime;
  final String note;

  bool get allowsVisit => outcome == VisitOutcome.approved;

  Map<String, dynamic> toJson() => {'outcome': outcome.name, 'at': at.toIso8601String(), 'preferredTime': preferredTime, 'note': note};
  factory DealerVerification.fromJson(Map<String, dynamic> j) => DealerVerification(
        outcome: VisitOutcome.values.firstWhere((o) => o.name == j['outcome'], orElse: () => VisitOutcome.noAnswer),
        at: _dt(j['at']),
        preferredTime: '${j['preferredTime'] ?? ''}',
        note: '${j['note'] ?? ''}',
      );
}

class BoardType {
  const BoardType(this.name, this.questions);
  final String name;
  /// Board-specific questions: label -> options (empty options = free text).
  final Map<String, List<String>> questions;
}

const boardTypes = <BoardType>[
  BoardType('GSB', {'Lighting': ['LED', 'Tube light', 'Non-lit'], 'Face material': ['Flex', 'Vinyl', 'Acrylic']}),
  BoardType('Non-lit', {'Face material': ['Flex', 'Vinyl', 'Painted']}),
  BoardType('ACP / Acrylic', {'Thickness (mm)': [], 'Backlit?': ['Yes', 'No']}),
  BoardType('Foam / MDF', {'Thickness (mm)': [], 'Weatherproofing': ['Laminated', 'Painted', 'None']}),
  BoardType('Special characters', {'Number of characters': [], 'Character material': ['Acrylic', 'Metal', 'Foam']}),
  BoardType('Pole board', {'Pole height (ft)': [], 'Number of poles': []}),
  BoardType('Other', {'Describe the board': []}),
];

class Board {
  Board({required this.id, this.type = '', this.width, this.height, this.mountHeight, this.qty = 1, Map<String, String>? extras}) : extras = extras ?? {};
  final String id;
  String type;
  double? width;
  double? height;
  double? mountHeight;
  int qty;
  Map<String, String> extras;

  /// UI preview only; the backend recomputes square feet.
  double get sqft => (width ?? 0) * (height ?? 0) * qty;
  bool get measured => (width ?? 0) > 0 && (height ?? 0) > 0 && type.isNotEmpty;

  Map<String, dynamic> toJson() => {'id': id, 'type': type, 'width': width, 'height': height, 'mountHeight': mountHeight, 'qty': qty, 'extras': extras};
  factory Board.fromJson(Map<String, dynamic> j) => Board(
        id: '${j['id']}',
        type: '${j['type'] ?? ''}',
        width: _d(j['width']),
        height: _d(j['height']),
        mountHeight: _d(j['mountHeight']),
        qty: int.tryParse('${j['qty']}') ?? 1,
        extras: {for (final e in ((j['extras'] as Map?) ?? {}).entries) '${e.key}': '${e.value}'},
      );
}

class Survey {
  Survey({this.dealerName = '', this.dealerPhone = '', this.gstin = '', List<Board>? boards, this.observations = ''}) : boards = boards ?? [];
  String dealerName;
  String dealerPhone;
  String gstin;
  List<Board> boards;
  String observations;

  bool get complete => boards.isNotEmpty && boards.every((b) => b.measured) && dealerName.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {'dealerName': dealerName, 'dealerPhone': dealerPhone, 'gstin': gstin, 'boards': boards.map((b) => b.toJson()).toList(), 'observations': observations};
  factory Survey.fromJson(Map<String, dynamic> j) => Survey(
        dealerName: '${j['dealerName'] ?? ''}',
        dealerPhone: '${j['dealerPhone'] ?? ''}',
        gstin: '${j['gstin'] ?? ''}',
        boards: ((j['boards'] as List?) ?? []).map((b) => Board.fromJson(Map<String, dynamic>.from(b as Map))).toList(),
        observations: '${j['observations'] ?? ''}',
      );
}

enum PhotoKind {
  front('Front view'),
  side('Side view'),
  measurement('Measurement'),
  mounting('Mounting');

  const PhotoKind(this.label);
  final String label;
}

/// Raw and edited photos are stored separately; the original is never overwritten.
class PhotoRec {
  PhotoRec({required this.id, required this.kind, required this.originalPath, this.editedPath, this.lat, this.lng, required this.at, this.boardId, this.note = '', this.rect});
  final String id;
  final PhotoKind kind;
  final String originalPath;
  String? editedPath;
  final double? lat;
  final double? lng;
  final DateTime at;
  String? boardId;
  String note;
  /// Normalised green measurement rectangle [l, t, r, b] (0..1) in the displayed image.
  List<double>? rect;

  Map<String, dynamic> toJson() => {'id': id, 'kind': kind.name, 'originalPath': originalPath, 'editedPath': editedPath, 'lat': lat, 'lng': lng, 'at': at.toIso8601String(), 'boardId': boardId, 'note': note, 'rect': rect};
  factory PhotoRec.fromJson(Map<String, dynamic> j) => PhotoRec(
        id: '${j['id']}',
        kind: PhotoKind.values.firstWhere((k) => k.name == j['kind'], orElse: () => PhotoKind.front),
        originalPath: '${j['originalPath']}',
        editedPath: j['editedPath'] as String?,
        lat: _d(j['lat']),
        lng: _d(j['lng']),
        at: _dt(j['at']),
        boardId: j['boardId'] as String?,
        note: '${j['note'] ?? ''}',
        rect: (j['rect'] as List?)?.map((e) => (e as num).toDouble()).toList(),
      );
}

class Acknowledgement {
  Acknowledgement({this.dealerSignPath, this.staffSignPath, this.signedSheetPath, this.contact = '', this.gstin = '', this.signedAt});
  String? dealerSignPath;
  String? staffSignPath;
  String? signedSheetPath;
  String contact;
  String gstin;
  DateTime? signedAt;

  bool get complete => dealerSignPath != null && staffSignPath != null;

  Map<String, dynamic> toJson() => {'dealerSignPath': dealerSignPath, 'staffSignPath': staffSignPath, 'signedSheetPath': signedSheetPath, 'contact': contact, 'gstin': gstin, 'signedAt': signedAt?.toIso8601String()};
  factory Acknowledgement.fromJson(Map<String, dynamic> j) => Acknowledgement(
        dealerSignPath: j['dealerSignPath'] as String?,
        staffSignPath: j['staffSignPath'] as String?,
        signedSheetPath: j['signedSheetPath'] as String?,
        contact: '${j['contact'] ?? ''}',
        gstin: '${j['gstin'] ?? ''}',
        signedAt: j['signedAt'] == null ? null : _dt(j['signedAt']),
      );
}

class Shop {
  Shop({required this.id, required this.name, required this.address, required this.area, this.dealerName = '', this.phone = '', this.verification, this.survey, List<PhotoRec>? photos, this.ack, this.done = false, this.checkInAt, this.checkInLat, this.checkInLng}) : photos = photos ?? [];
  final String id;
  final String name;
  final String address;
  final String area;
  final String dealerName;
  final String phone;
  DealerVerification? verification;
  Survey? survey;
  List<PhotoRec> photos;
  Acknowledgement? ack;
  bool done;
  /// GPS check-in at the shop (null lat/lng with a time means GPS was unavailable).
  DateTime? checkInAt;
  double? checkInLat;
  double? checkInLng;
  bool get checkedIn => checkInAt != null;

  bool get verified => verification != null;
  bool get held => verification != null && !verification!.allowsVisit;
  bool get canVisit => verification?.allowsVisit ?? false;
  bool get surveyDone => survey?.complete ?? false;
  bool get photosDone => photos.isNotEmpty && photos.any((p) => p.editedPath != null);
  bool get ackDone => ack?.complete ?? false;
  bool get readyToFinish => canVisit && surveyDone && photosDone && ackDone;
  bool get started => canVisit && (checkedIn || survey != null || photos.isNotEmpty || ack != null);

  String get statusLabel => done
      ? 'Completed'
      : held
          ? 'On hold'
          : started
              ? 'In progress'
              : canVisit
                  ? 'Approved to visit'
                  : 'Pending';

  Map<String, dynamic> toJson() => {
        'id': id, 'name': name, 'address': address, 'area': area, 'dealerName': dealerName, 'phone': phone,
        'verification': verification?.toJson(), 'survey': survey?.toJson(), 'photos': photos.map((p) => p.toJson()).toList(),
        'ack': ack?.toJson(), 'done': done, 'checkInAt': checkInAt?.toIso8601String(), 'checkInLat': checkInLat, 'checkInLng': checkInLng,
      };
  factory Shop.fromJson(Map<String, dynamic> j) => Shop(
        id: '${j['id']}', name: '${j['name']}', address: '${j['address']}', area: '${j['area']}',
        dealerName: '${j['dealerName'] ?? ''}', phone: '${j['phone'] ?? ''}',
        verification: j['verification'] == null ? null : DealerVerification.fromJson(Map<String, dynamic>.from(j['verification'] as Map)),
        survey: j['survey'] == null ? null : Survey.fromJson(Map<String, dynamic>.from(j['survey'] as Map)),
        photos: ((j['photos'] as List?) ?? []).map((p) => PhotoRec.fromJson(Map<String, dynamic>.from(p as Map))).toList(),
        ack: j['ack'] == null ? null : Acknowledgement.fromJson(Map<String, dynamic>.from(j['ack'] as Map)),
        done: j['done'] == true,
        checkInAt: j['checkInAt'] == null ? null : _dt(j['checkInAt']),
        checkInLat: _d(j['checkInLat']),
        checkInLng: _d(j['checkInLng']),
      );
}

class Trip {
  const Trip({required this.startedAt, required this.vehicle, required this.openingOdometer, required this.photoPath, this.lat, this.lng});
  final DateTime startedAt;
  final String vehicle;
  final int openingOdometer;
  final String photoPath;
  final double? lat;
  final double? lng;
  Map<String, dynamic> toJson() => {'startedAt': startedAt.toIso8601String(), 'vehicle': vehicle, 'openingOdometer': openingOdometer, 'photoPath': photoPath, 'lat': lat, 'lng': lng};
  factory Trip.fromJson(Map<String, dynamic> j) => Trip(startedAt: _dt(j['startedAt']), vehicle: '${j['vehicle']}', openingOdometer: int.tryParse('${j['openingOdometer']}') ?? 0, photoPath: '${j['photoPath']}', lat: _d(j['lat']), lng: _d(j['lng']));
}

const expenseCategories = ['Travel / Fuel', 'Food', 'Stay', 'Others'];

class Expense {
  const Expense({required this.id, required this.category, required this.amount, required this.date, this.receiptPath, this.note = ''});
  final String id;
  final String category;
  final double amount;
  final DateTime date;
  final String? receiptPath;
  final String note;
  Map<String, dynamic> toJson() => {'id': id, 'category': category, 'amount': amount, 'date': date.toIso8601String(), 'receiptPath': receiptPath, 'note': note};
  factory Expense.fromJson(Map<String, dynamic> j) => Expense(id: '${j['id']}', category: '${j['category']}', amount: _d(j['amount']) ?? 0, date: _dt(j['date']), receiptPath: j['receiptPath'] as String?, note: '${j['note'] ?? ''}');
}

enum AssignmentState { offered, accepted, declined }

enum SubmitState { open, submitted, synced }

class Project {
  Project({
    required this.id, required this.code, required this.client, required this.campaign, required this.district, required this.dueDate,
    required this.shops, this.assignment = AssignmentState.accepted, this.trip, List<Expense>? expenses, this.closingOdometer, this.fuelLitres,
    this.remarks = '', this.submit = SubmitState.open, this.submittedAt,
  }) : expenses = expenses ?? [];
  final String id;
  final String code;
  final String client;
  final String campaign;
  final String district;
  final DateTime dueDate;
  final List<Shop> shops;
  AssignmentState assignment;
  Trip? trip;
  List<Expense> expenses;
  int? closingOdometer;
  double? fuelLitres;
  String remarks;
  SubmitState submit;
  DateTime? submittedAt;

  int get doneCount => shops.where((s) => s.done).length;
  int get heldCount => shops.where((s) => s.held && !s.done).length;
  int get inProgressCount => shops.where((s) => s.started && !s.done).length;
  int get pendingCount => shops.length - doneCount - inProgressCount;
  double get expenseTotal => expenses.fold(0, (a, e) => a + e.amount);
  int? get distanceKm => (closingOdometer != null && trip != null) ? closingOdometer! - trip!.openingOdometer : null;
  bool get tripStarted => trip != null;
  bool get submitted => submit != SubmitState.open;

  /// Final checklist (C9). Every item must be true to submit.
  List<(String, bool)> get checklist => [
        ('Dealer verification', shops.isNotEmpty && shops.every((s) => s.verified)),
        ('Opening odometer & trip photo', tripStarted),
        ('Measurements', shops.where((s) => s.canVisit).every((s) => s.surveyDone) && shops.any((s) => s.canVisit)),
        ('Photos (marked)', shops.where((s) => s.canVisit).every((s) => s.photosDone) && shops.any((s) => s.canVisit)),
        ('Acknowledgement', shops.where((s) => s.canVisit).every((s) => s.ackDone) && shops.any((s) => s.canVisit)),
        ('Closing odometer', closingOdometer != null && trip != null && closingOdometer! >= trip!.openingOdometer),
      ];
  bool get canSubmit => !submitted && checklist.every((c) => c.$2);

  Map<String, dynamic> toJson() => {
        'id': id, 'code': code, 'client': client, 'campaign': campaign, 'district': district, 'dueDate': dueDate.toIso8601String(),
        'shops': shops.map((s) => s.toJson()).toList(), 'assignment': assignment.name, 'trip': trip?.toJson(),
        'expenses': expenses.map((e) => e.toJson()).toList(), 'closingOdometer': closingOdometer, 'fuelLitres': fuelLitres,
        'remarks': remarks, 'submit': submit.name, 'submittedAt': submittedAt?.toIso8601String(),
      };
  factory Project.fromJson(Map<String, dynamic> j) => Project(
        id: '${j['id']}', code: '${j['code']}', client: '${j['client']}', campaign: '${j['campaign']}', district: '${j['district']}', dueDate: _dt(j['dueDate']),
        shops: ((j['shops'] as List?) ?? []).map((s) => Shop.fromJson(Map<String, dynamic>.from(s as Map))).toList(),
        assignment: AssignmentState.values.firstWhere((a) => a.name == j['assignment'], orElse: () => AssignmentState.accepted),
        trip: j['trip'] == null ? null : Trip.fromJson(Map<String, dynamic>.from(j['trip'] as Map)),
        expenses: ((j['expenses'] as List?) ?? []).map((e) => Expense.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
        closingOdometer: int.tryParse('${j['closingOdometer']}'), fuelLitres: _d(j['fuelLitres']), remarks: '${j['remarks'] ?? ''}',
        submit: SubmitState.values.firstWhere((s) => s.name == j['submit'], orElse: () => SubmitState.open),
        submittedAt: j['submittedAt'] == null ? null : _dt(j['submittedAt']),
      );
}

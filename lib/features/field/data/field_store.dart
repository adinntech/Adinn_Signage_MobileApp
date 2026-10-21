import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/field_models.dart';

/// Local persistence for field work (offline drafts). The sync layer will push these to the
/// backend later; screens only ever talk to [FieldController].
abstract class FieldStore {
  Future<List<Project>?> load(String userId);
  Future<void> save(String userId, List<Project> projects);
  Future<void> clear(String userId);
}

class PrefsFieldStore implements FieldStore {
  const PrefsFieldStore();
  String _key(String u) => 'field.v1.$u';

  @override
  Future<List<Project>?> load(String userId) async {
    final raw = (await SharedPreferences.getInstance()).getString(_key(userId));
    if (raw == null) return null;
    try {
      return (jsonDecode(raw) as List).map((p) => Project.fromJson(Map<String, dynamic>.from(p as Map))).toList();
    } catch (_) {
      return null; // corrupt draft: fall back to a fresh list rather than crash the app
    }
  }

  @override
  Future<void> save(String userId, List<Project> projects) async =>
      (await SharedPreferences.getInstance()).setString(_key(userId), jsonEncode(projects.map((p) => p.toJson()).toList()));

  @override
  Future<void> clear(String userId) async => (await SharedPreferences.getInstance()).remove(_key(userId));
}

final fieldStoreProvider = Provider<FieldStore>((_) => const PrefsFieldStore());

/// Demo assignments so the app is testable before the backend assignment API exists.
List<Project> demoProjects({required bool vendor}) {
  final now = DateTime.now();
  Shop shop(String id, String name, String address, String area, String dealer, String phone) =>
      Shop(id: id, name: name, address: address, area: area, dealerName: dealer, phone: phone);
  return [
    Project(
      id: 'p1', code: '22070277', client: 'AMUL', campaign: 'Dindigul Campaign', district: 'Dindigul', dueDate: now.add(const Duration(days: 10)),
      assignment: AssignmentState.accepted,
      shops: [
        shop('s1', 'Lakshmi Electricals', '12, Gandhi Rd, Dindigul', 'Dindigul', 'Murugan', '9843011122'),
        shop('s2', 'Sri Murugan Stores', '45, Palani Rd, Dindigul', 'Dindigul', 'Selvam', '9843011133'),
        shop('s3', 'Annai Fancy', '7, Main Bazaar, Oddanchatram', 'Oddanchatram', 'Annamalai', '9843011144'),
        shop('s4', 'KSR Mobiles', '88, Bus Stand Rd, Natham', 'Natham', 'Karthik', '9843011155'),
        shop('s5', 'Vinayaga Hardware', '3, Temple St, Batlagundu', 'Batlagundu', 'Rajan', '9843011166'),
      ],
    ),
    Project(
      id: 'p2', code: '22070281', client: 'ITC', campaign: 'Coimbatore Campaign', district: 'Coimbatore', dueDate: now.add(const Duration(days: 14)),
      assignment: vendor ? AssignmentState.offered : AssignmentState.accepted,
      shops: [
        shop('s6', 'Sri Krishna Agencies', '3, Race Course Rd, Coimbatore', 'Coimbatore', 'Ramesh', '9791200011'),
        shop('s7', 'Kovai Super Mart', '56, Avinashi Rd, Coimbatore', 'Coimbatore', 'Suresh', '9791200033'),
        shop('s8', 'Pollachi Provision', '9, Market Rd, Pollachi', 'Pollachi', 'Mani', '9791200044'),
      ],
    ),
  ];
}

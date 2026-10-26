import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/providers.dart';
import '../domain/field_models.dart';

/// What the recce person types when adding a shop on arrival.
class ShopDraft {
  const ShopDraft({
    required this.shopName,
    required this.dealerName,
    required this.mobile,
    required this.address1,
    this.address2 = '',
    required this.location,
    required this.district,
    this.pincode = '',
    this.gstin = '',
    this.lat,
    this.lng,
  });
  final String shopName;
  final String dealerName;
  final String mobile;
  final String address1;
  final String address2;
  final String location;
  final String district;
  final String pincode;
  final String gstin;
  final double? lat;
  final double? lng;

  Map<String, dynamic> toJson() => {
        'shopName': shopName,
        'dealerName': dealerName,
        'mobile': mobile,
        'address1': address1,
        if (address2.isNotEmpty) 'address2': address2,
        'location': location,
        'district': district,
        if (pincode.isNotEmpty) 'pincode': pincode,
        if (gstin.isNotEmpty) 'gstin': gstin,
        if (lat != null && lng != null) ...{'lat': lat, 'lng': lng},
      };
}

/// The backend's view of this person's field work: the jobs given to them and the shops in each.
/// Dealer verification, measurements, photos and the rest are still kept on the phone (see FieldStore).
class FieldRepository {
  FieldRepository(this._dio);
  final Dio _dio;

  static const _closed = {'CANCELLED', 'LOSS', 'COMPLETED'};

  /// Reads every page of a list endpoint (the backend caps a page at 100 or 200 rows).
  Future<List<Map<String, dynamic>>> _all(String path, {int pageSize = 100}) async {
    final out = <Map<String, dynamic>>[];
    for (var page = 1; page <= 50; page++) {
      final res = await _dio.get<dynamic>(path, queryParameters: {'page': page, 'limit': pageSize});
      final body = res.data as Map;
      final rows = ((body['data'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      out.addAll(rows);
      final total = int.tryParse('${(body['meta'] as Map?)?['total']}') ?? out.length;
      if (rows.isEmpty || out.length >= total) break;
    }
    return out;
  }

  /// Jobs for a vendor login: only the projects and shops the office gave to this vendor company.
  Future<List<Project>> _vendorJobs() async {
    final res = await _dio.get<dynamic>('/vendor/jobs');
    final jobs = <Project>[];
    for (final p in ((res.data as Map)['data'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map))) {
      final sites = await _all('/vendor/jobs/${p['projectId']}/shops', pageSize: 200);
      jobs.add(_project({...p, '_id': p['projectId']}, sites.map(_shop).toList(), const []));
    }
    return jobs;
  }

  /// Jobs for a recce executive: an ASO survey given to them, and projects whose in-house shops they visit.
  Future<List<Project>> fetchJobs({required bool vendor}) async {
    try {
      if (vendor) return await _vendorJobs();
      final jobs = <Project>[];
      for (final p in await _all('/projects')) {
        if (_closed.contains('${p['status']}')) continue;
        final id = '${p['_id']}';
        final aso = '${p['requirementType']}' == 'ASO';
        var sites = await _all('/projects/$id/sites', pageSize: 200);
        // A recce person visits only the in-house shops of a shop-list project.
        if (!aso) sites = sites.where((s) => '${s['channel']}' == 'IN_HOUSE').toList();
        if (!aso && sites.isEmpty) continue;
        final areas = aso ? await _areas(id) : <JobArea>[];
        jobs.add(_project(p, sites.map(_shop).toList(), areas));
      }
      return jobs;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<List<JobArea>> _areas(String projectId) async {
    final res = await _dio.get<dynamic>('/projects/$projectId/survey-areas');
    return ((res.data as Map)['data'] as List? ?? [])
        .map((a) => Map<String, dynamic>.from(a as Map))
        .map((a) => JobArea(name: '${a['area']}', address: '${a['address'] ?? ''}', approxShops: int.tryParse('${a['approxShops']}'), found: int.tryParse('${a['shopsFound']}') ?? 0))
        .toList();
  }

  /// Adds a shop to an ASO survey the moment the recce person reaches it. Needs a connection.
  Future<Shop> addShop(String projectId, ShopDraft draft) async {
    try {
      final res = await _dio.post<dynamic>('/projects/$projectId/sites', data: draft.toJson());
      final site = ((res.data as Map)['data'] as Map)['site'] as Map;
      return _shop(Map<String, dynamic>.from(site));
    } on DioException catch (e) {
      throw _readable(e);
    }
  }

  /// The backend's validation messages (one per field) joined into a sentence the person can act on.
  ApiException _readable(DioException e) {
    final body = e.response?.data;
    if (e.response?.statusCode == 422 && body is Map && body['error'] is Map) {
      final details = (body['error'] as Map)['details'];
      if (details is List && details.isNotEmpty) {
        final msgs = details.map((d) => (d is Map ? '${d['message']}' : '$d')).where((m) => m.isNotEmpty).toSet().join('. ');
        return ApiException(code: 'VALIDATION_ERROR', message: msgs, statusCode: 422);
      }
    }
    return ApiException.fromDio(e);
  }

  Project _project(Map<String, dynamic> p, List<Shop> shops, List<JobArea> areas) {
    final client = p['client'];
    return Project(
      id: '${p['_id']}',
      code: '${p['code']}',
      client: client is Map ? '${client['name'] ?? ''}' : '${client ?? ''}',
      campaign: '${p['campaign'] ?? p['name'] ?? ''}',
      district: '${p['district'] ?? ''}',
      dueDate: DateTime.tryParse('${p['targetDate']}') ?? DateTime.now().add(const Duration(days: 14)),
      shops: shops,
      requirementType: '${p['requirementType'] ?? ''}',
      instructions: '${p['instructions'] ?? ''}',
      areas: areas,
    );
  }

  Shop _shop(Map<String, dynamic> s) {
    String t(String k) => '${s[k] ?? ''}'.trim();
    final address = [t('address1'), t('address2'), t('address3')].where((x) => x.isNotEmpty).join(', ');
    return Shop(
      id: '${s['_id']}',
      name: t('shopName').isNotEmpty ? t('shopName') : (t('dealerName').isNotEmpty ? t('dealerName') : t('siteCode')),
      address: address.isNotEmpty ? address : t('location'),
      area: t('location').isNotEmpty ? t('location') : t('district'),
      dealerName: t('dealerName'),
      phone: t('mobile'),
      lat: s['lat'] == null ? null : double.tryParse('${s['lat']}'),
      lng: s['lng'] == null ? null : double.tryParse('${s['lng']}'),
    );
  }
}

final fieldRepositoryProvider = Provider<FieldRepository>((ref) => FieldRepository(ref.watch(apiDioProvider)));

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/providers.dart';

typedef Json = Map<String, dynamic>;

/// Statuses shown on the shop cards (DRAFT and READY_TO_SUBMIT are worked out by the server).
const recceStatusLabels = <String, String>{
  'NOT_STARTED': 'Not started',
  'IN_PROGRESS': 'In progress',
  'DRAFT': 'Draft',
  'READY_TO_SUBMIT': 'Ready to submit',
  'SUBMITTED': 'Submitted',
  'UNDER_REVIEW': 'Under review',
  'APPROVED': 'Approved',
  'REWORK_REQUIRED': 'Rework required',
  'REJECTED': 'Rejected',
};

String newClientId() => 'c${DateTime.now().microsecondsSinceEpoch}${Random().nextInt(1 << 31)}';

/// Calls the shop-wise recce API (only the shops given to this login are ever returned).
class RecceApi {
  RecceApi(this._dio);
  final Dio _dio;

  Future<T> _run<T>(Future<T> Function() f) async {
    try {
      return await f();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Json _data(Response<dynamic> r) => ((r.data as Map)['data'] as Map).cast<String, dynamic>();

  Future<List<Json>> shops({String? status}) => _run(() async {
        final r = await _dio.get<dynamic>('/recce/shops', queryParameters: {'limit': 200, 'status': ?status});
        final list = (r.data as Map)['data'] as List;
        return list.map((e) => (e as Map).cast<String, dynamic>()).toList();
      });

  Future<Json> detail(String siteId) => _run(() async => _data(await _dio.get<dynamic>('/recce/shops/$siteId')));
  Future<Json> start(String siteId) => _run(() async => _data(await _dio.post<dynamic>('/recce/shops/$siteId/start', data: <String, dynamic>{})));
  Future<Json> saveDraft(String siteId, {List<Json>? mediaItems, String? notes}) =>
      _run(() async => _data(await _dio.put<dynamic>('/recce/shops/$siteId/draft', data: {'mediaItems': ?mediaItems, 'notes': ?notes})));
  Future<Json> patchPhoto(String siteId, String photoId, Json body) => _run(() async => _data(await _dio.patch<dynamic>('/recce/shops/$siteId/photos/$photoId', data: body)));
  Future<Json> deletePhoto(String siteId, String photoId, {String? reason}) =>
      _run(() async => _data(await _dio.delete<dynamic>('/recce/shops/$siteId/photos/$photoId', queryParameters: {'reason': ?reason})));
  Future<Json> submit(String siteId, String key, {String? notes}) =>
      _run(() async => _data(await _dio.post<dynamic>('/recce/shops/$siteId/submit', data: {'idempotencyKey': key, 'notes': ?notes})));
  Future<List<Json>> activity(String siteId) => _run(() async {
        final r = await _dio.get<dynamic>('/recce/shops/$siteId/activity');
        return ((r.data as Map)['data'] as List).map((e) => (e as Map).cast<String, dynamic>()).toList();
      });
  Future<List<Json>> messages(String siteId) => _run(() async {
        final r = await _dio.get<dynamic>('/recce/shops/$siteId/messages');
        return ((r.data as Map)['data'] as List).map((e) => (e as Map).cast<String, dynamic>()).toList();
      });
  Future<void> sendMessage(String siteId, String body) => _run(() async {
        await _dio.post<dynamic>('/recce/shops/$siteId/messages', data: {'body': body});
      });

  Future<void> uploadPhoto(UploadItem u, {required void Function(double) onProgress, CancelToken? cancel}) => _run(() async {
        final form = FormData.fromMap({
          'photos': kIsWeb
              ? MultipartFile.fromBytes(await XFile(u.path).readAsBytes(), filename: 'photo_${u.id}.jpg')
              : await MultipartFile.fromFile(u.path, filename: u.path.split(RegExp(r'[\\/]')).last),
          'meta': jsonEncode([u.meta()]),
        });
        await _dio.post<dynamic>('/recce/shops/${u.siteId}/photos', data: form, cancelToken: cancel, onSendProgress: (s, t) => onProgress(t <= 0 ? 0 : s / t));
      });
}

final recceApiProvider = Provider<RecceApi>((ref) => RecceApi(ref.watch(apiDioProvider)));
final recceShopsProvider = FutureProvider.autoDispose<List<Json>>((ref) => ref.watch(recceApiProvider).shops());
final recceShopProvider = FutureProvider.autoDispose.family<Json, String>((ref, id) => ref.watch(recceApiProvider).detail(id));

enum UploadStatus { queued, uploading, failed }

/// One photo waiting to go to the server. Kept on the phone (original file untouched) until the server has stored it.
class UploadItem {
  UploadItem({
    required this.id,
    required this.siteId,
    required this.path,
    required this.category,
    required this.mediaKey,
    this.caption = '',
    this.capturedAt,
    this.lat,
    this.lng,
    this.accuracy,
    this.width,
    this.height,
    this.replaces,
    this.status = UploadStatus.queued,
    this.progress = 0,
    this.error,
    this.retryable = true,
  });

  final String id;
  final String siteId;
  final String path;
  final String category;
  final String mediaKey;
  final String caption;
  final DateTime? capturedAt;
  final double? lat;
  final double? lng;
  final double? accuracy;
  final int? width;
  final int? height;
  final String? replaces;
  UploadStatus status;
  double progress;
  String? error;
  bool retryable;

  Json meta() => {
        'clientId': id,
        'category': category,
        'mediaKey': mediaKey,
        'caption': caption,
        if (capturedAt != null) 'capturedAt': capturedAt!.toUtc().toIso8601String(),
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        if (accuracy != null) 'gpsAccuracy': accuracy,
        if (width != null) 'width': width,
        if (height != null) 'height': height,
        if (replaces != null) 'replaces': replaces,
      };

  Json toJson() => {...meta(), 'siteId': siteId, 'path': path};
  static UploadItem fromJson(Json j) => UploadItem(
        id: j['clientId'] as String,
        siteId: j['siteId'] as String,
        path: j['path'] as String,
        category: j['category'] as String,
        mediaKey: (j['mediaKey'] as String?) ?? '',
        caption: (j['caption'] as String?) ?? '',
        capturedAt: j['capturedAt'] == null ? null : DateTime.tryParse(j['capturedAt'] as String),
        lat: (j['lat'] as num?)?.toDouble(),
        lng: (j['lng'] as num?)?.toDouble(),
        accuracy: (j['gpsAccuracy'] as num?)?.toDouble(),
        width: (j['width'] as num?)?.toInt(),
        height: (j['height'] as num?)?.toInt(),
        replaces: j['replaces'] as String?,
      );
}

/// Pixel size of an image file (null when it cannot be read; the server then just flags "size unknown").
Future<({int w, int h})?> imageSize(String path) async {
  try {
    final codec = await ui.instantiateImageCodec(await File(path).readAsBytes());
    final f = (await codec.getNextFrame()).image;
    final r = (w: f.width, h: f.height);
    f.dispose();
    return r;
  } catch (_) {
    return null;
  }
}

/// Upload queue: at most [maxParallel] uploads at once, progress, retry, cancel. It is saved on the phone, so photos taken
/// without network (or when the app is closed) go up later. A failed upload is never dropped: it stays listed with its reason.
class UploadQueue extends Notifier<List<UploadItem>> {
  static const maxParallel = 2;
  static const _key = 'recce_upload_queue_v1';
  final Map<String, CancelToken> _tokens = {};
  Timer? _timer;

  @override
  List<UploadItem> build() {
    ref.onDispose(() => _timer?.cancel());
    // Network came back / time passed: try failed network uploads again.
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      var changed = false;
      for (final u in state) {
        if (u.status == UploadStatus.failed && u.retryable) {
          u.status = UploadStatus.queued;
          changed = true;
        }
      }
      if (changed) _emit();
      _pump();
    });
    unawaited(_load());
    return const [];
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    if (raw == null) return;
    final saved = (jsonDecode(raw) as List).map((e) => UploadItem.fromJson((e as Map).cast<String, dynamic>())).where((u) => File(u.path).existsSync()).toList();
    state = [...saved, ...state.where((n) => !saved.any((s) => s.id == n.id))];
    _pump();
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, jsonEncode(state.map((u) => u.toJson()).toList()));
  }

  void _emit() {
    state = [...state];
    unawaited(_save());
  }

  List<UploadItem> forShop(String siteId) => state.where((u) => u.siteId == siteId).toList();
  bool hasPending(String siteId) => state.any((u) => u.siteId == siteId);

  void add(UploadItem u) {
    if (state.any((x) => x.id == u.id)) return; // the same capture is never queued twice
    state = [...state, u];
    unawaited(_save());
    _pump();
  }

  void retry(String id) {
    for (final u in state) {
      if (u.id == id) {
        u.status = UploadStatus.queued;
        u.error = null;
      }
    }
    _emit();
    _pump();
  }

  /// Cancels one waiting or running upload and forgets it (the photo file stays in the phone gallery folder of the app).
  void cancel(String id) {
    _tokens.remove(id)?.cancel('cancelled');
    state = state.where((u) => u.id != id).toList();
    unawaited(_save());
  }

  void _pump() {
    final running = state.where((u) => u.status == UploadStatus.uploading).length;
    var free = maxParallel - running;
    for (final u in state.where((u) => u.status == UploadStatus.queued).toList()) {
      if (free <= 0) break;
      free--;
      unawaited(_run(u));
    }
  }

  Future<void> _run(UploadItem u) async {
    u.status = UploadStatus.uploading;
    u.progress = 0;
    _emit();
    final token = CancelToken();
    _tokens[u.id] = token;
    try {
      await ref.read(recceApiProvider).uploadPhoto(u, cancel: token, onProgress: (p) {
        u.progress = p;
        state = [...state];
      });
      state = state.where((x) => x.id != u.id).toList();
      unawaited(_save());
      ref.invalidate(recceShopProvider(u.siteId));
      ref.invalidate(recceShopsProvider);
    } on ApiException catch (e) {
      if (!state.any((x) => x.id == u.id)) return; // cancelled meanwhile
      u.status = UploadStatus.failed;
      u.error = e.message;
      // 4xx (wrong state, duplicate, invalid file) will not fix itself: wait for the person. Network trouble retries by itself.
      u.retryable = e.statusCode == null || e.statusCode! >= 500 || e.statusCode == 408;
      if (e.statusCode == 409 && (e.message.contains('already uploaded'))) {
        state = state.where((x) => x.id != u.id).toList(); // the server already has this photo
        ref.invalidate(recceShopProvider(u.siteId));
        unawaited(_save());
      } else {
        _emit();
      }
    } catch (e) {
      u.status = UploadStatus.failed;
      u.error = 'Upload failed. Will retry.';
      _emit();
    } finally {
      _tokens.remove(u.id);
      _pump();
    }
  }
}

final uploadQueueProvider = NotifierProvider<UploadQueue, List<UploadItem>>(UploadQueue.new);

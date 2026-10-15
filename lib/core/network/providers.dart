import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/auth_repository_impl.dart';
import '../../features/auth/domain/auth_repository.dart';
import '../storage/session_store.dart';
import 'dio_client.dart';
import 'token_manager.dart';

final sessionStoreProvider =
    Provider<SessionStore>((ref) => SecureSessionStore());

final plainDioProvider = Provider<Dio>((ref) => createPlainDio());

final tokenManagerProvider = Provider<TokenManager>(
  (ref) => TokenManager(
    refreshDio: ref.watch(plainDioProvider),
    store: ref.watch(sessionStoreProvider),
  ),
);

/// Authenticated Dio for future feature modules.
final apiDioProvider = Provider<Dio>(
  (ref) => createAuthedDio(ref.watch(tokenManagerProvider)),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(
    plainDio: ref.watch(plainDioProvider),
    tokens: ref.watch(tokenManagerProvider),
    store: ref.watch(sessionStoreProvider),
  ),
);

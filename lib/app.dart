import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/config/app_config.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/auth_controller.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/register_screen.dart';
import 'features/field/presentation/acknowledgement_screen.dart';
import 'features/field/presentation/dealer_verification_screen.dart';
import 'features/field/presentation/expenses_screen.dart';
import 'features/field/presentation/photo_editor_screen.dart';
import 'features/field/presentation/photos_screen.dart';
import 'features/field/presentation/project_screen.dart';
import 'features/field/presentation/shop_hub_screen.dart';
import 'features/field/presentation/submit_screen.dart';
import 'features/field/presentation/survey_screen.dart';
import 'features/field/presentation/trip_screen.dart';
import 'features/home/home_shell.dart';
import 'features/home/unsupported_role_screen.dart';

class _RouterRefresh extends ChangeNotifier {
  void ping() => notifyListeners();
}

/// Reachable without a session.
const _publicRoutes = {'/login', '/register'};

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh();
  ref.listen(authControllerProvider, (_, _) => refresh.ping());
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final loc = state.matchedLocation;
      switch (auth) {
        case AuthInitializing():
          return loc == '/splash' ? null : '/splash';
        case AuthUnauthenticated():
          return _publicRoutes.contains(loc) ? null : '/login';
        case Authenticated(:final user):
          final target = user.role.homeRoute ?? '/unsupported';
          // Field staff may open their home and any project/shop screen; everything else goes home.
          if (user.role.homeRoute != null && loc.startsWith('/project/')) return null;
          return loc == target ? null : target;
      }
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const _Splash()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      GoRoute(path: '/recce', builder: (_, _) => const HomeShell()),
      GoRoute(path: '/vendor', builder: (_, _) => const HomeShell()),
      GoRoute(path: '/project/:pid', builder: (_, s) => ProjectScreen(pid: s.pathParameters['pid']!)),
      GoRoute(path: '/project/:pid/trip', builder: (_, s) => TripScreen(pid: s.pathParameters['pid']!)),
      GoRoute(path: '/project/:pid/expenses', builder: (_, s) => ExpensesScreen(pid: s.pathParameters['pid']!)),
      GoRoute(path: '/project/:pid/submit', builder: (_, s) => SubmitScreen(pid: s.pathParameters['pid']!)),
      GoRoute(path: '/project/:pid/shop/:sid', builder: (_, s) => ShopHubScreen(pid: s.pathParameters['pid']!, sid: s.pathParameters['sid']!)),
      GoRoute(path: '/project/:pid/shop/:sid/verify', builder: (_, s) => DealerVerificationScreen(pid: s.pathParameters['pid']!, sid: s.pathParameters['sid']!)),
      GoRoute(path: '/project/:pid/shop/:sid/survey', builder: (_, s) => SurveyScreen(pid: s.pathParameters['pid']!, sid: s.pathParameters['sid']!)),
      GoRoute(path: '/project/:pid/shop/:sid/photos', builder: (_, s) => PhotosScreen(pid: s.pathParameters['pid']!, sid: s.pathParameters['sid']!)),
      GoRoute(path: '/project/:pid/shop/:sid/photos/:photoId', builder: (_, s) => PhotoEditorScreen(pid: s.pathParameters['pid']!, sid: s.pathParameters['sid']!, photoId: s.pathParameters['photoId']!)),
      GoRoute(path: '/project/:pid/shop/:sid/ack', builder: (_, s) => AcknowledgementScreen(pid: s.pathParameters['pid']!, sid: s.pathParameters['sid']!)),
      GoRoute(
          path: '/unsupported', builder: (_, _) => const UnsupportedRoleScreen()),
    ],
  );
});

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.navy,
      body: Center(child: CircularProgressIndicator(color: Colors.white)),
    );
  }
}

class SignageApp extends ConsumerWidget {
  const SignageApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: ref.watch(routerProvider),
    );
  }
}

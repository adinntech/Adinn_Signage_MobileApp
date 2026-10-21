import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../auth/domain/auth_user.dart';
import '../auth/presentation/auth_controller.dart';
import '../field/presentation/field_dashboard.dart';

/// Bottom-nav shell with Home, Assignments, Map, Sync, Profile.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  static const _titles = ['Home', 'Assignments', 'Map', 'Sync', 'Profile'];

  /// Recce executives are teal, vendors purple (shared design system).
  static Color _accent(UserRole role) =>
      role == UserRole.vendor ? AppColors.vendor : AppColors.teal;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    if (auth is! Authenticated) return const SizedBox.shrink();

    final pages = <Widget>[
      FieldDashboard(user: auth.user),
      AssignmentsPage(user: auth.user),
      const _Placeholder(
          icon: Icons.map_outlined, text: 'Route map arrives in a later phase.'),
      const SyncPage(),
      _ProfilePage(user: auth.user),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        flexibleSpace: Align(
          alignment: Alignment.bottomCenter,
          child: Container(height: 3, color: _accent(auth.user.role)),
        ),
        actions: [
          if (auth.offline)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Chip(
                avatar: Icon(Icons.cloud_off, size: 16),
                label: Text('Offline'),
              ),
            ),
        ],
      ),
      body: SafeArea(child: pages[_index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.assignment_outlined),
              selectedIcon: Icon(Icons.assignment),
              label: 'Assignments'),
          NavigationDestination(
              icon: Icon(Icons.map_outlined),
              selectedIcon: Icon(Icons.map),
              label: 'Map'),
          NavigationDestination(icon: Icon(Icons.sync), label: 'Sync'),
          NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile'),
        ],
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: AppColors.softBlue),
            const SizedBox(height: 16),
            Text(text, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _ProfilePage extends ConsumerWidget {
  const _ProfilePage({required this.user});
  final AuthUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Column(
            children: [
              ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(user.name),
                  subtitle: const Text('Name')),
              ListTile(
                  leading: const Icon(Icons.email_outlined),
                  title: Text(user.email),
                  subtitle: const Text('Email')),
              if (user.phone != null && user.phone!.isNotEmpty)
                ListTile(
                    leading: const Icon(Icons.phone_outlined),
                    title: Text(user.phone!),
                    subtitle: const Text('Phone')),
              ListTile(
                  leading: const Icon(Icons.badge_outlined),
                  title: Text(user.role.label),
                  subtitle: const Text('Role')),
            ],
          ),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          icon: const Icon(Icons.logout),
          label: const Text('Log out'),
        ),
      ],
    );
  }
}

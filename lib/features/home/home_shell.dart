import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../auth/domain/auth_user.dart';
import '../auth/presentation/auth_controller.dart';

/// Bottom-nav shell with Home, Assignments, Map, Sync, Profile.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  static const _titles = ['Home', 'Assignments', 'Map', 'Sync', 'Profile'];

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    if (auth is! Authenticated) return const SizedBox.shrink();

    final pages = <Widget>[
      _HomePage(user: auth.user),
      const _Placeholder(
          icon: Icons.assignment_outlined, text: 'Your assignments will appear here.'),
      const _Placeholder(
          icon: Icons.map_outlined, text: 'Site map arrives in a later phase.'),
      const _Placeholder(
          icon: Icons.sync, text: 'Offline sync arrives in a later phase.'),
      _ProfilePage(user: auth.user),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
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

class _HomePage extends StatelessWidget {
  const _HomePage({required this.user});
  final AuthUser user;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final first = user.name.trim().split(' ').first;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Hello, ${first.isEmpty ? 'there' : first}',
            style: text.headlineSmall?.copyWith(
                color: AppColors.navy, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Chip(
            label: Text(user.role.label),
            backgroundColor: AppColors.softBlueBg,
            side: BorderSide.none,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.3,
          children: const [
            _StatCard(label: 'Assigned', value: 0, color: AppColors.softBlue),
            _StatCard(label: 'In Progress', value: 0, color: AppColors.orange),
            _StatCard(label: 'Completed', value: 0, color: AppColors.teal),
            _StatCard(label: 'Pending Sync', value: 0, color: AppColors.navy),
          ],
        ),
        const SizedBox(height: 16),
        Text('Assignments arrive in a later phase.',
            style: text.bodyMedium?.copyWith(color: Colors.black54)),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(
      {required this.label, required this.value, required this.color});
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('$value',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: color, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(label),
          ],
        ),
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

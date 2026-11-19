import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../auth/domain/auth_user.dart';
import '../auth/presentation/auth_controller.dart';
import '../field/presentation/field_dashboard.dart';
import '../notifications/presentation/notification_bell.dart';

/// Bottom-nav shell with Home, Assignments, Map, Sync, Profile.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;
//MOBILE APP TITLE HEADER
  static const _titles = ['Homes', 'Assignment', 'Map', 'Sync', 'Profile'];

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
          IconButton(
            icon: const Icon(Icons.fact_check_outlined),
            tooltip: 'Recce evidence',
            onPressed: () => context.push('/recce-evidence'),
          ),
          const NotificationBell(),
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
      //WEB APP 
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
              label: 'Assignment'),
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
    final v = user.vendor;
    if (v != null) return _VendorProfile(user: user, vendor: v);
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

/// Vendor profile: the company's name, phone and email exactly as the vendor master holds them.
class _VendorProfile extends ConsumerWidget {
  const _VendorProfile({required this.user, required this.vendor});
  final AuthUser user;
  final VendorProfile vendor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget row(IconData icon, String? value, String label) => value == null
        ? const SizedBox.shrink()
        : ListTile(leading: Icon(icon), title: Text(value), subtitle: Text(label));
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Column(
            children: [
              row(Icons.storefront_outlined, vendor.name, 'Vendor name'),
              row(Icons.tag, vendor.vendorNo, 'Vendor ID'),
              row(Icons.person_outline, vendor.contactPerson, 'Contact person'),
              row(Icons.phone_outlined, vendor.phone, 'Phone'),
              row(Icons.phone_android_outlined, vendor.altPhone, 'Alternate phone'),
              row(Icons.email_outlined, vendor.email, 'Email'),
              row(Icons.location_on_outlined, [vendor.state, vendor.pincode].whereType<String>().join(' - ').isEmpty ? null : [vendor.state, vendor.pincode].whereType<String>().join(' - '), 'State / Pincode'),
              row(Icons.login, user.name == vendor.name ? null : user.name, 'Login name'),
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

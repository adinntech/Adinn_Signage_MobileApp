import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import 'widgets/auth_scaffold.dart';

/// "Forgot vendor ID?": who to call. In-house (recce) staff reset by email instead; this page is for vendor sign-in only.
class VendorHelpScreen extends StatelessWidget {
  const VendorHelpScreen({super.key});

  Future<void> _call(BuildContext context) async {
    final uri = Uri(scheme: 'tel', path: AppConfig.vendorSupportPhone);
    final ok = await canLaunchUrl(uri) && await launchUrl(uri);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot open the dialer. Call ${AppConfig.vendorSupportPhone}.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Forgot vendor ID?',
      subtitle: 'The office will help you sign in',
      showBack: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 0,
            color: const Color(0xFFEFF3FB),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.royal,
                    child: Icon(Icons.support_agent, color: Colors.white, size: 30),
                  ),
                  const SizedBox(height: 12),
                  Text(AppConfig.vendorSupportName,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.navy)),
                  const SizedBox(height: 6),
                  const Text('Kindly contact for vendor login', textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  InkWell(
                    key: const ValueKey('call-support'),
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _call(context),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.call, color: AppColors.royal),
                          const SizedBox(width: 8),
                          Text(AppConfig.vendorSupportPhone,
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.royal,
                                  decoration: TextDecoration.underline)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _call(context),
            icon: const Icon(Icons.call),
            label: const Text('Call now'),
          ),
        ],
      ),
    );
  }
}

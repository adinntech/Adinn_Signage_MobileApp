import 'dart:io';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppStatusChip extends StatelessWidget {
  const AppStatusChip(this.label, {super.key, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
        child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
      );
}

/// Titled white card used to group a block of a form.
class AppSection extends StatelessWidget {
  const AppSection({super.key, required this.title, required this.child, this.trailing, this.icon});
  final String title;
  final Widget child;
  final Widget? trailing;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              if (icon != null) ...[Icon(icon, size: 20, color: AppColors.royal), const SizedBox(width: 8)],
              Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.navy))),
              ?trailing,
            ]),
            const SizedBox(height: 12),
            child,
          ]),
        ),
      );
}

class AppStatTile extends StatelessWidget {
  const AppStatTile({super.key, required this.label, required this.value, required this.color, required this.icon});
  final String label;
  final int value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [color.withValues(alpha: 0.16), Colors.white], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(children: [
          CircleAvatar(radius: 18, backgroundColor: color, child: Icon(icon, color: Colors.white, size: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('$value', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: color, height: 1)),
              const SizedBox(height: 2),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ]),
          ),
        ]),
      );
}

/// Gradient header strip used at the top of field screens (matches the web section headers).
class AppHeaderBand extends StatelessWidget {
  const AppHeaderBand({super.key, required this.title, this.subtitle, this.accent = AppColors.royal});
  final String title;
  final String? subtitle;
  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.navy, accent])),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
          if (subtitle != null) Text(subtitle!, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ]),
      );
}

class AppPhotoThumb extends StatelessWidget {
  const AppPhotoThumb({super.key, required this.path, this.size = 72, this.onTap});
  final String path;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: size,
            height: size,
            child: Image.file(File(path), fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(color: AppColors.softBlueBg, child: const Icon(Icons.broken_image_outlined))),
          ),
        ),
      );
}

class AppEmpty extends StatelessWidget {
  const AppEmpty({super.key, required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(32),
        child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 56, color: AppColors.softBlue), const SizedBox(height: 12), Text(text, textAlign: TextAlign.center)])),
      );
}

Future<bool> confirm(BuildContext context, {required String title, required String message, String action = 'Confirm'}) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(96, 44)), onPressed: () => Navigator.pop(c, true), child: Text(action))],
      ),
    ) ??
    false;

void toast(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), backgroundColor: error ? AppColors.error : AppColors.navy, behavior: SnackBarBehavior.floating));
}

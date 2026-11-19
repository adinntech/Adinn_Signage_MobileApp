import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';
import 'app_photo_viewer.dart';
import 'app_widgets.dart';

enum AppFileState { waiting, uploading, done, failed }

/// One uploaded / uploading file, same behaviour as the web upload list: thumbnail, name, size, live state with a progress bar,
/// then View, Download and Remove (Cancel while uploading, Retry when failed). Use it for every file list in the app.
class AppFileRow extends StatelessWidget {
  const AppFileRow({
    super.key,
    required this.name,
    this.subtitle,
    this.size,
    this.state = AppFileState.done,
    this.progress = 0,
    this.message,
    this.localPath,
    this.url,
    this.badge,
    this.onView,
    this.onRemove,
    this.onCancel,
    this.onRetry,
    this.onTap,
  });

  final String name;
  final String? subtitle;
  final int? size;
  final AppFileState state;
  final double progress; // 0..1
  final String? message;
  final String? localPath; // picked file (phone path, or blob address in a browser)
  final String? url; // stored file address
  final Widget? badge;
  final VoidCallback? onView; // default: open the picture full screen
  final VoidCallback? onRemove;
  final VoidCallback? onCancel;
  final VoidCallback? onRetry;
  final VoidCallback? onTap;

  static String bytes(int? b) {
    if (b == null) return '';
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(0)} KB';
    return '${(b / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  void _view(BuildContext context) {
    if (onView != null) return onView!();
    final src = url ?? localPath;
    if (src == null) return;
    showPhotoViewer(context, [AppViewerPhoto(title: name, subtitle: subtitle, url: url, localPath: localPath)]);
  }

  Future<void> _download(BuildContext context) async {
    final u = url;
    if (u == null) return;
    final ok = await launchUrl(Uri.parse(u), mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) toast(context, 'Could not open the download', error: true);
  }

  @override
  Widget build(BuildContext context) {
    final failed = state == AppFileState.failed;
    final uploading = state == AppFileState.uploading;
    final done = state == AppFileState.done;
    final thumb = SizedBox(
      width: 48,
      height: 48,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: url != null
            ? Image.network(url!, fit: BoxFit.cover, cacheWidth: 200, errorBuilder: (_, _, _) => const ColoredBox(color: AppColors.softBlueBg, child: Icon(Icons.broken_image_outlined)))
            : localPath != null
                ? appImage(localPath!, fit: BoxFit.cover)
                : const ColoredBox(color: AppColors.softBlueBg, child: Icon(Icons.insert_drive_file_outlined)),
      ),
    );
    final status = switch (state) {
      AppFileState.waiting => const Text('Waiting to upload', style: TextStyle(fontSize: 12, color: Colors.black54)),
      AppFileState.uploading => Text('Uploading ${(progress * 100).round()}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.royal)),
      AppFileState.done => const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.check_circle, size: 14, color: AppColors.teal), SizedBox(width: 4), Text('Uploaded', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.teal))]),
      AppFileState.failed => const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.error_outline, size: 14, color: AppColors.error), SizedBox(width: 4), Text('Upload failed', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.error))]),
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: failed ? const Color(0xFFFFF5F5) : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap ?? ((url != null || localPath != null) ? () => _view(context) : null),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              thumb,
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    if (size != null) Text(bytes(size), style: const TextStyle(fontSize: 12, color: Colors.black54)),
                    status,
                    if (subtitle != null && subtitle!.isNotEmpty) Text(subtitle!, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                    ?badge,
                  ]),
                ]),
              ),
              if (failed && onRetry != null) IconButton(tooltip: 'Retry', icon: const Icon(Icons.refresh, color: AppColors.royal), onPressed: onRetry),
              if (done && (url != null || onView != null)) IconButton(tooltip: 'View', icon: const Icon(Icons.visibility_outlined), onPressed: () => _view(context)),
              if (done && url != null) IconButton(tooltip: 'Download', icon: const Icon(Icons.download_outlined), onPressed: () => _download(context)),
              if (uploading && onCancel != null) IconButton(tooltip: 'Cancel upload', icon: const Icon(Icons.close, color: AppColors.error), onPressed: onCancel)
              else if (!uploading && onRemove != null) IconButton(tooltip: 'Remove', icon: const Icon(Icons.delete_outline, color: AppColors.error), onPressed: onRemove),
            ]),
            if (uploading)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: progress > 0 ? progress : null, minHeight: 8, backgroundColor: AppColors.softBlueBg)),
              ),
            if (failed && (message ?? '').isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(message!, style: const TextStyle(fontSize: 12, color: AppColors.error))),
          ]),
        ),
      ),
    );
  }
}

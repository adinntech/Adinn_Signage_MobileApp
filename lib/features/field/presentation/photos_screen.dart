import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/location_service.dart';
import '../../../core/services/photo_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../data/field_controller.dart';
import '../domain/field_models.dart';

/// C6 (part 1) – capture raw photos with GPS, then open one to mark it.
class PhotosScreen extends ConsumerStatefulWidget {
  const PhotosScreen({super.key, required this.pid, required this.sid});
  final String pid;
  final String sid;

  @override
  ConsumerState<PhotosScreen> createState() => _State();
}

class _State extends ConsumerState<PhotosScreen> {
  PhotoKind _kind = PhotoKind.front;
  bool _busy = false;

  Future<void> _capture({required bool camera}) async {
    setState(() => _busy = true);
    try {
      final path = await ref.read(photoServiceProvider).pick(camera: camera);
      if (path == null) return;
      final fix = await ref.read(locationServiceProvider).current();
      final rec = PhotoRec(id: 'ph${DateTime.now().microsecondsSinceEpoch}', kind: _kind, originalPath: path, lat: fix?.lat, lng: fix?.lng, at: DateTime.now());
      ref.read(fieldControllerProvider.notifier).addPhoto(widget.pid, widget.sid, rec);
      if (mounted) {
        toast(context, 'Photo saved${fix == null ? ' (GPS unavailable)' : ''}. Tap it to mark the board.');
      }
    } catch (e) {
      if (mounted) toast(context, 'Could not open the camera', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(fieldControllerProvider).shop(widget.pid, widget.sid);
    if (s == null) return Scaffold(appBar: AppBar(), body: const AppEmpty(icon: Icons.search_off, text: 'Shop not found.'));
    return Scaffold(
      appBar: AppBar(title: const Text('Photos')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        AppSection(
          title: 'Capture',
          icon: Icons.photo_camera,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final k in PhotoKind.values) ChoiceChip(label: Text(k.label), selected: _kind == k, onSelected: (_) => setState(() => _kind = k)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: FilledButton.icon(onPressed: _busy ? null : () => _capture(camera: true), icon: const Icon(Icons.photo_camera), label: const Text('Camera'))),
              const SizedBox(width: 10),
              Expanded(child: OutlinedButton.icon(onPressed: _busy ? null : () => _capture(camera: false), icon: const Icon(Icons.photo_library_outlined), label: const Text('Gallery'))),
            ]),
          ]),
        ),
        AppSection(
          title: 'Photos (${s.photos.length})',
          icon: Icons.collections_outlined,
          child: s.photos.isEmpty
              ? const Text('No photos yet. Capture the front view first, then the board measurement.')
              : GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.9,
                  children: [
                    for (final p in s.photos)
                      GestureDetector(
                        onTap: () => context.push('/project/${widget.pid}/shop/${widget.sid}/photos/${p.id}'),
                        child: Stack(fit: StackFit.expand, children: [
                          AppPhotoThumb(path: p.editedPath ?? p.originalPath, size: double.infinity),
                          Positioned(left: 6, top: 6, child: AppStatusChip(p.kind.label, color: AppColors.navy)),
                          Positioned(left: 6, bottom: 6, child: AppStatusChip(p.editedPath != null ? 'Marked' : 'Raw – tap to mark', color: p.editedPath != null ? const Color(0xFF059669) : AppColors.orange)),
                          Positioned(
                            right: 2,
                            top: 2,
                            child: IconButton(
                              style: IconButton.styleFrom(backgroundColor: Colors.white70),
                              icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                              onPressed: () async {
                                if (await confirm(context, title: 'Delete photo?', message: 'The raw and marked versions will be removed.', action: 'Delete')) {
                                  ref.read(fieldControllerProvider.notifier).removePhoto(widget.pid, widget.sid, p.id);
                                }
                              },
                            ),
                          ),
                        ]),
                      ),
                  ],
                ),
        ),
        const Text('Raw photos are always kept unchanged. Marking creates a separate edited copy.', style: TextStyle(color: Colors.black54, fontSize: 12)),
      ]),
    );
  }
}

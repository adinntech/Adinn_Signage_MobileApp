import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/photo_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_file_row.dart';
import '../../../core/widgets/app_photo_viewer.dart';
import '../../../core/widgets/app_widgets.dart';
import '../data/recce_api.dart';
import 'recce_shops_screen.dart';

String _err(Object e) => e is ApiException ? e.message : 'Something went wrong. Try again.';

/// C. Shop details with D-J: media types, camera / gallery capture, photo gallery, measurements, notes, submission preview;
/// K-M: submission history, rework requests and the shop's message thread.
class RecceShopScreen extends ConsumerStatefulWidget {
  const RecceShopScreen({super.key, required this.siteId});
  final String siteId;

  @override
  ConsumerState<RecceShopScreen> createState() => _RecceShopScreenState();
}

class _RecceShopScreenState extends ConsumerState<RecceShopScreen> {
  final _notes = TextEditingController();
  bool _notesLoaded = false;
  bool _busy = false;
  String? _submitKey; // one key per submit attempt: a double tap can never make two versions

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  RecceApi get _api => ref.read(recceApiProvider);

  Future<void> _guard(Future<void> Function() f) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await f();
    } catch (e) {
      if (mounted) toast(context, _err(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _refresh() => ref.invalidate(recceShopProvider(widget.siteId));

  Future<void> _capture(Json d, {required bool camera, String? replaces, String? presetCategory, String? presetMedia}) async {
    final items = (d['mediaItems'] as List).cast<Map>();
    final cats = (d['categories'] as List).cast<Map>();
    final choice = await showModalBottomSheet<(String, String, String)>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => _CaptureSheet(cats: cats, items: items, category: presetCategory, mediaKey: presetMedia),
    );
    if (choice == null || !mounted) return;
    final path = await ref.read(photoServiceProvider).pick(camera: camera); // original copied once, never edited
    if (path == null || !mounted) return;
    final fix = await ref.read(locationServiceProvider).current(); // null when permission is denied: the photo is still kept
    if (fix == null && mounted) toast(context, 'Location is off or not allowed. The photo is saved without GPS.');
    final size = await imageSize(path);
    ref.read(uploadQueueProvider.notifier).add(UploadItem(
          id: newClientId(),
          siteId: widget.siteId,
          path: path,
          category: choice.$1,
          mediaKey: choice.$2,
          caption: choice.$3,
          capturedAt: DateTime.now(),
          lat: fix?.lat,
          lng: fix?.lng,
          width: size?.w,
          height: size?.h,
          replaces: replaces,
        ));
  }

  Future<void> _addPhotoMenu(Json d) async {
    final how = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.photo_camera_outlined), title: const Text('Take a photo'), onTap: () => Navigator.pop(c, true)),
          ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Choose from gallery'), onTap: () => Navigator.pop(c, false)),
        ]),
      ),
    );
    if (how != null && mounted) await _capture(d, camera: how);
  }

  Future<void> _photoActions(Json d, Json p) async {
    final draft = p['state'] == 'DRAFT';
    final editable = d['editable'] == true;
    final siteId = widget.siteId;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(title: Text(_catLabel(d, p['category'] as String), style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text((p['caption'] as String?)?.isNotEmpty == true ? p['caption'] as String : 'No caption')),
          if (editable && draft)
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit caption'),
              onTap: () async {
                Navigator.pop(c);
                final t = await _ask('Caption', initial: p['caption'] as String?);
                if (t != null) await _guard(() async { await _api.patchPhoto(siteId, p['id'] as String, {'caption': t}); _refresh(); });
              },
            ),
          if (editable && !draft)
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: const Text('Replace with a new photo'),
              onTap: () async {
                Navigator.pop(c);
                await _capture(d, camera: true, replaces: p['id'] as String, presetCategory: p['category'] as String, presetMedia: p['mediaKey'] as String?);
              },
            ),
          if (editable)
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.error),
              title: Text(draft ? 'Delete draft photo' : 'Remove from submission', style: const TextStyle(color: AppColors.error)),
              onTap: () async {
                Navigator.pop(c);
                String? reason;
                if (!draft) {
                  reason = await _ask('Why is this photo removed? (required)');
                  if (reason == null || reason.trim().length < 3) return;
                } else if (!await confirm(context, title: 'Delete photo?', message: 'This draft photo will be deleted.', action: 'Delete')) {
                  return;
                }
                await _guard(() async { await _api.deletePhoto(siteId, p['id'] as String, reason: reason); _refresh(); });
              },
            ),
        ]),
      ),
    );
  }

  Future<String?> _ask(String title, {String? initial}) {
    final c = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(controller: c, maxLength: 300, autofocus: true),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('OK'))],
      ),
    );
  }

  Future<void> _editMedia(Json d, {Map? item}) async {
    final items = (d['mediaItems'] as List).map((e) => (e as Map).cast<String, dynamic>()).toList();
    final result = await showDialog<Json>(context: context, builder: (c) => _MediaDialog(item: item?.cast<String, dynamic>(), existingKeys: items.map((e) => e['key'] as String).toList()));
    if (result == null) return;
    final next = [for (final i in items) if (item != null && i['key'] == item['key']) result else i, if (item == null) result];
    await _guard(() async {
      await _api.saveDraft(widget.siteId, mediaItems: next.map((i) => {for (final k in ['key', 'name', 'quantity', 'width', 'height', 'unit', 'notes']) if (i[k] != null) k: i[k]}).toList());
      _refresh();
    });
  }

  Future<void> _preview(Json d) async {
    _submitKey ??= newClientId();
    final progress = d['progress'] as Map;
    final missing = (progress['missing'] as List).cast<Map>();
    final photos = (d['photos'] as List).length;
    final pending = ref.read(uploadQueueProvider.notifier).hasPending(widget.siteId);
    final go = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Submission preview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Text('${(d['project'] as Map)['code']} · ${d['shopName'] ?? d['siteCode']}'),
          Text('${(d['project'] as Map)['client'] ?? ''}'),
          const Divider(height: 24),
          for (final m in (d['mediaItems'] as List).cast<Map>()) Text('• ${m['name']} × ${m['quantity']}  ${m['width'] != null ? '${m['width']} × ${m['height']} ${m['unit']}' : 'no measurement'}'),
          const SizedBox(height: 8),
          Text('Photos: $photos'),
          if ((_notes.text).isNotEmpty) Text('Notes: ${_notes.text}'),
          if (missing.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('Still missing', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700)),
            for (final m in missing) Text('• ${m['mediaName']}: ${m['label']}', style: const TextStyle(color: AppColors.error)),
          ],
          if (pending) const Padding(padding: EdgeInsets.only(top: 8), child: Text('Some photos are still uploading. Wait until they finish.', style: TextStyle(color: AppColors.orange, fontWeight: FontWeight.w700))),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, height: 48, child: FilledButton(onPressed: missing.isEmpty && !pending && photos > 0 ? () => Navigator.pop(c, true) : null, child: const Text('Submit for verification'))),
        ]),
      ),
    );
    if (go != true) return;
    await _guard(() async {
      final res = await _api.submit(widget.siteId, _submitKey!, notes: _notes.text.trim());
      _submitKey = null;
      _refresh();
      ref.invalidate(recceShopsProvider);
      if (mounted) toast(context, res['duplicate'] == true ? 'Already submitted.' : 'Submitted as version ${res['version']}.');
    });
  }

  /// Opens all of the shop's photos full screen, starting at the tapped one.
  void _openGallery(Json d, List photos, Json tapped) {
    final list = photos.cast<Json>();
    showPhotoViewer(
      context,
      [for (final x in list) AppViewerPhoto(title: _catLabel(d, x['category'] as String), subtitle: x['caption'] as String?, url: (x['editedUrl'] ?? x['url']) as String?)],
      initial: list.indexOf(tapped),
    );
  }

  String _catLabel(Json d, String key) {
    for (final c in (d['categories'] as List).cast<Map>()) {
      if (c['key'] == key) return c['label'] as String;
    }
    return key;
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(recceShopProvider(widget.siteId));
    final queue = ref.watch(uploadQueueProvider).where((u) => u.siteId == widget.siteId).toList();
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(async.value?['shopName'] as String? ?? 'Shop'),
          bottom: const TabBar(tabs: [Tab(text: 'Evidence'), Tab(text: 'History'), Tab(text: 'Messages')]),
        ),
        body: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(_err(e)), FilledButton(onPressed: _refresh, child: const Text('Retry'))])),
          data: (d) {
            if (!_notesLoaded) {
              _notes.text = d['notes'] as String? ?? '';
              _notesLoaded = true;
            }
            return TabBarView(children: [_evidence(d, queue), _History(siteId: widget.siteId, detail: d), _Messages(siteId: widget.siteId)]);
          },
        ),
      ),
    );
  }

  Widget _evidence(Json d, List<UploadItem> queue) {
    final status = d['status'] as String;
    final editable = d['editable'] == true;
    final photos = (d['photos'] as List).cast<Map>().map((e) => e.cast<String, dynamic>()).toList();
    final prog = d['progress'] as Map;
    final openRework = (d['reworks'] as List).cast<Map>().where((r) => r['status'] == 'OPEN').toList();
    final project = d['project'] as Map;
    return RefreshIndicator(
      onRefresh: () async => ref.refresh(recceShopProvider(widget.siteId).future),
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text('${project['code']} · ${project['client'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700))),
                AppStatusChip(recceStatusLabels[status] ?? status, color: recceStatusColor(status)),
              ]),
              const SizedBox(height: 6),
              Text('${d['siteCode']}${d['district'] != null ? ' · ${d['district']}' : ''}'),
              if ((d['address'] as String).isNotEmpty) Text(d['address'] as String),
              if (d['contactPerson'] != null) Text('Contact: ${d['contactPerson']}${d['mobile'] != null ? ' · ${d['mobile']}' : ''}'),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: ((prog['percent'] as num).toDouble()) / 100, minHeight: 8, color: recceStatusColor(status), backgroundColor: AppColors.softBlueBg))),
                const SizedBox(width: 10),
                Text('${prog['percent']}%', style: const TextStyle(fontWeight: FontWeight.w700)),
              ]),
              if (project['closed'] == true) const Padding(padding: EdgeInsets.only(top: 8), child: Text('This project is closed. No more changes.', style: TextStyle(color: AppColors.error))),
            ]),
          ),
        ),
        for (final r in openRework)
          Card(
            color: const Color(0xFFFFF4E0),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r['kind'] == 'ADDITIONAL' ? 'Additional photos requested' : 'Rework required', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.orange)),
                const SizedBox(height: 4),
                Text('${r['stageLabel']}: ${r['instructions']}'),
                for (final i in (r['items'] as List).cast<Map>())
                  Text('• ${i['type'] == 'ADDITIONAL_PHOTO' ? 'Add: ${i['categoryLabel']}' : i['type'] == 'REPLACE_PHOTO' ? 'Replace the photo the reviewer marked' : i['type'] == 'FIX_MEASUREMENT' ? 'Correct the measurements' : (i['note'] ?? 'Other')}'),
              ]),
            ),
          ),
        if (!editable && status != 'NOT_STARTED')
          Card(
            color: AppColors.softBlueBg,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(switch (status) {
                'SUBMITTED' || 'UNDER_REVIEW' => 'Sent for verification (version ${d['version']}). You will be notified of the decision.',
                'APPROVED' => 'Approved. This shop is complete.',
                'REJECTED' => 'Rejected. Contact the office if another attempt is allowed.',
                _ => '',
              }),
            ),
          ),
        AppSection(
          title: 'Media types and measurements',
          icon: Icons.straighten,
          trailing: editable ? TextButton.icon(onPressed: _busy ? null : () => _editMedia(d), icon: const Icon(Icons.add), label: const Text('Add')) : null,
          child: Column(children: [
            for (final m in (d['mediaItems'] as List).cast<Map>())
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${m['name']} × ${m['quantity']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${m['width'] != null ? '${m['width']} × ${m['height']} ${m['unit']}' : 'Measurement missing'}${(m['required'] as List).isNotEmpty ? '\nNeeds: ${(m['required'] as List).map((c) => _catLabel(d, c as String)).join(', ')}' : ''}'),
                isThreeLine: (m['required'] as List).isNotEmpty,
                trailing: editable ? IconButton(icon: const Icon(Icons.edit_outlined), tooltip: 'Edit measurement', onPressed: _busy ? null : () => _editMedia(d, item: m)) : null,
              ),
          ]),
        ),
        AppSection(
          title: 'Photos (${photos.length}${queue.isNotEmpty ? ' + ${queue.length} uploading' : ''})',
          icon: Icons.photo_library_outlined,
          trailing: editable ? FilledButton.icon(onPressed: _busy ? null : () => _addPhotoMenu(d), icon: const Icon(Icons.add_a_photo_outlined), label: const Text('Add')) : null,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if ((prog['missing'] as List).isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Wrap(spacing: 6, runSpacing: 6, children: [for (final m in (prog['missing'] as List).cast<Map>()) Chip(avatar: const Icon(Icons.priority_high, size: 16, color: AppColors.error), label: Text('${m['mediaName']}: ${m['label']}', style: const TextStyle(fontSize: 12)))]),
              ),
            if (photos.isEmpty && queue.isEmpty) const AppEmpty(icon: Icons.photo_camera_back_outlined, text: 'No photos yet. Tap Add to take the shop front, name board and the other views.'),
            for (final u in queue) _QueueTile(u),
            for (final p in photos) _PhotoRow(p, label: _catLabel(d, p['category'] as String), editable: editable, onMenu: () => _photoActions(d, p), onView: () => _openGallery(d, photos, p)),
          ]),
        ),
        AppSection(
          title: 'Recce notes',
          icon: Icons.notes,
          child: Column(children: [
            TextField(controller: _notes, enabled: editable, maxLines: 4, maxLength: 2000, decoration: const InputDecoration(hintText: 'Obstructions, electrical point, owner remarks...')),
            if (editable) Align(alignment: Alignment.centerRight, child: OutlinedButton(onPressed: _busy ? null : () => _guard(() async { await _api.saveDraft(widget.siteId, notes: _notes.text.trim()); if (mounted) toast(context, 'Draft saved'); _refresh(); }), child: const Text('Save draft'))),
          ]),
        ),
        if (editable)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SizedBox(height: 52, child: FilledButton.icon(onPressed: _busy ? null : () => _preview(d), icon: const Icon(Icons.fact_check_outlined), label: const Text('Review and submit'))),
          ),
        const SizedBox(height: 24),
      ]),
    );
  }
}

class _PhotoRow extends StatelessWidget {
  const _PhotoRow(this.p, {required this.label, required this.editable, required this.onMenu, required this.onView});
  final VoidCallback onView;
  final Json p;
  final String label;
  final bool editable;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final draft = p['state'] == 'DRAFT';
    final flagged = ((p['flags'] as List?) ?? const []).isNotEmpty;
    return AppFileRow(
      name: label,
      subtitle: (p['caption'] as String?)?.isNotEmpty == true ? p['caption'] as String : null,
      size: (p['size'] as num?)?.toInt(),
      url: (p['editedUrl'] ?? p['url']) as String?,
      badge: draft ? const AppStatusChip('Draft', color: AppColors.orange) : (flagged ? const Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.orange) : null),
      onView: onView,
      onTap: onView,
      onRemove: editable ? onMenu : null,
    );
  }
}

class _QueueTile extends ConsumerWidget {
  const _QueueTile(this.u);
  final UploadItem u;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = ref.read(uploadQueueProvider.notifier);
    return AppFileRow(
      name: u.path.split(RegExp(r'[\/]')).last,
      state: switch (u.status) { UploadStatus.queued => AppFileState.waiting, UploadStatus.uploading => AppFileState.uploading, UploadStatus.failed => AppFileState.failed },
      progress: u.progress,
      message: u.error,
      localPath: u.path,
      onCancel: () => q.cancel(u.id),
      onRemove: () => q.cancel(u.id),
      onRetry: () => q.retry(u.id),
    );
  }
}

class _CaptureSheet extends StatefulWidget {
  const _CaptureSheet({required this.cats, required this.items, this.category, this.mediaKey});
  final List<Map> cats;
  final List<Map> items;
  final String? category;
  final String? mediaKey;

  @override
  State<_CaptureSheet> createState() => _CaptureSheetState();
}

class _CaptureSheetState extends State<_CaptureSheet> {
  late String _cat = widget.category ?? widget.cats.first['key'] as String;
  late String _media = widget.mediaKey ?? widget.items.first['key'] as String;
  final _caption = TextEditingController();

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Photo details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _cat,
            decoration: const InputDecoration(labelText: 'Photo category'),
            items: [for (final c in widget.cats) DropdownMenuItem(value: c['key'] as String, child: Text(c['label'] as String))],
            onChanged: (v) => setState(() => _cat = v!),
          ),
          const SizedBox(height: 12),
          if (widget.items.length > 1)
            DropdownButtonFormField<String>(
              initialValue: _media,
              decoration: const InputDecoration(labelText: 'Media type'),
              items: [for (final m in widget.items) DropdownMenuItem(value: m['key'] as String, child: Text(m['name'] as String))],
              onChanged: (v) => setState(() => _media = v!),
            ),
          const SizedBox(height: 12),
          TextField(controller: _caption, maxLength: 300, decoration: const InputDecoration(labelText: 'Caption (optional)')),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, height: 48, child: FilledButton(onPressed: () => Navigator.pop(context, (_cat, _media, _caption.text.trim())), child: const Text('Continue'))),
        ]),
      );
}

class _MediaDialog extends StatefulWidget {
  const _MediaDialog({this.item, required this.existingKeys});
  final Json? item;
  final List<String> existingKeys;

  @override
  State<_MediaDialog> createState() => _MediaDialogState();
}

class _MediaDialogState extends State<_MediaDialog> {
  late final _name = TextEditingController(text: widget.item?['name'] as String? ?? '');
  late final _qty = TextEditingController(text: '${widget.item?['quantity'] ?? 1}');
  late final _w = TextEditingController(text: widget.item?['width'] == null ? '' : '${widget.item!['width']}');
  late final _h = TextEditingController(text: widget.item?['height'] == null ? '' : '${widget.item!['height']}');
  late final _notes = TextEditingController(text: widget.item?['notes'] as String? ?? '');
  late String _unit = widget.item?['unit'] as String? ?? 'FT';
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _qty, _w, _h, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final qty = int.tryParse(_qty.text);
    final w = _w.text.isEmpty ? null : double.tryParse(_w.text);
    final h = _h.text.isEmpty ? null : double.tryParse(_h.text);
    if (_name.text.trim().isEmpty) return setState(() => _error = 'Enter the media type name');
    if (qty == null || qty < 1) return setState(() => _error = 'Quantity must be 1 or more');
    if ((w == null) != (h == null)) return setState(() => _error = 'Enter both width and height');
    var key = widget.item?['key'] as String?;
    if (key == null) {
      var i = widget.existingKeys.length + 1;
      while (widget.existingKeys.contains('m$i')) {
        i++;
      }
      key = 'm$i';
    }
    Navigator.pop(context, <String, dynamic>{'key': key, 'name': _name.text.trim(), 'quantity': qty, 'width': w, 'height': h, 'unit': _unit, 'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim()});
  }

  @override
  Widget build(BuildContext context) {
    final num = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')), LengthLimitingTextInputFormatter(8)];
    return AlertDialog(
      title: Text(widget.item == null ? 'Add media type' : 'Edit media type'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: _name, maxLength: 80, decoration: const InputDecoration(labelText: 'Media type (e.g. GSB Single Side)')),
          TextField(controller: _qty, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)], decoration: const InputDecoration(labelText: 'Quantity')),
          Row(children: [
            Expanded(child: TextField(controller: _w, keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: num, decoration: const InputDecoration(labelText: 'Width'))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: _h, keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: num, decoration: const InputDecoration(labelText: 'Height'))),
          ]),
          DropdownButtonFormField<String>(initialValue: _unit, decoration: const InputDecoration(labelText: 'Unit'), items: [for (final u in ['FT', 'IN', 'M', 'CM', 'MM']) DropdownMenuItem(value: u, child: Text(u))], onChanged: (v) => setState(() => _unit = v!)),
          TextField(controller: _notes, maxLength: 500, decoration: const InputDecoration(labelText: 'Notes (optional)')),
          if (_error != null) Text(_error!, style: const TextStyle(color: AppColors.error)),
        ]),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: _save, child: const Text('Save'))],
    );
  }
}

/// K. Submission history and L. rework requests: versions, every review decision with its comment, and the activity trail.
class _History extends ConsumerWidget {
  const _History({required this.siteId, required this.detail});
  final String siteId;
  final Json detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviews = (detail['reviews'] as List).cast<Map>();
    final reworks = (detail['reworks'] as List).cast<Map>();
    final versions = (detail['versions'] as List).cast<Map>();
    return FutureBuilder<List<Json>>(
      future: ref.read(recceApiProvider).activity(siteId),
      builder: (context, snap) => ListView(padding: const EdgeInsets.all(16), children: [
        AppSection(title: 'Submissions', icon: Icons.history, child: versions.isEmpty ? const Text('Nothing submitted yet.') : Column(children: [for (final v in versions) ListTile(contentPadding: EdgeInsets.zero, title: Text('Version ${v['version']}'), subtitle: Text('${v['photoCount']} photos · ${v['submittedAt']}'))])),
        AppSection(
          title: 'Review decisions',
          icon: Icons.rule,
          child: reviews.isEmpty ? const Text('No review decisions yet.') : Column(children: [for (final r in reviews) ListTile(contentPadding: EdgeInsets.zero, title: Text('v${r['versionNo']} · ${r['stageLabel']}: ${r['decision']}'), subtitle: Text('${r['reviewer'] ?? ''}${(r['comment'] as String).isNotEmpty ? '\n${r['comment']}' : ''}'))]),
        ),
        AppSection(
          title: 'Rework requests',
          icon: Icons.restart_alt,
          child: reworks.isEmpty ? const Text('None.') : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [for (final r in reworks) ListTile(contentPadding: EdgeInsets.zero, title: Text('${r['kind'] == 'ADDITIONAL' ? 'More photos' : 'Rework'} · ${r['status'] == 'OPEN' ? 'Open' : 'Resolved'}'), subtitle: Text('${r['stageLabel']}: ${r['instructions']}'))]),
        ),
        AppSection(
          title: 'Activity',
          icon: Icons.timeline,
          child: snap.connectionState != ConnectionState.done
              ? const LinearProgressIndicator()
              : Column(children: [for (final e in snap.data ?? const <Json>[]) ListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text(e['label'] as String), subtitle: Text('${e['actor']} · ${e['at']}${(e['reason'] as String).isNotEmpty ? '\n${e['reason']}' : ''}'))]),
        ),
      ]),
    );
  }
}

/// M. Project communication for this shop: submission cards, review updates and replies.
class _Messages extends ConsumerStatefulWidget {
  const _Messages({required this.siteId});
  final String siteId;

  @override
  ConsumerState<_Messages> createState() => _MessagesState();
}

class _MessagesState extends ConsumerState<_Messages> {
  final _c = TextEditingController();
  late Future<List<Json>> _f = ref.read(recceApiProvider).messages(widget.siteId);
  bool _sending = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final t = _c.text.trim();
    if (t.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref.read(recceApiProvider).sendMessage(widget.siteId, t);
      _c.clear();
      setState(() => _f = ref.read(recceApiProvider).messages(widget.siteId));
    } catch (e) {
      if (mounted) toast(context, _err(e), error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        Expanded(
          child: FutureBuilder<List<Json>>(
            future: _f,
            builder: (c, s) {
              if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
              final list = s.data ?? const <Json>[];
              if (list.isEmpty) return const AppEmpty(icon: Icons.chat_bubble_outline, text: 'No messages for this shop yet.');
              return ListView(padding: const EdgeInsets.all(16), children: [
                for (final m in list)
                  Card(
                    color: m['card'] != null ? AppColors.softBlueBg : null,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: m['card'] != null
                          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text((m['card'] as Map)['title'] as String, style: const TextStyle(fontWeight: FontWeight.w800)),
                              for (final l in ((m['card'] as Map)['lines'] as List).cast<Map>()) Text('${l['label']}: ${l['value']}', style: const TextStyle(fontSize: 13)),
                            ])
                          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text((m['author'] as Map)['name'] as String, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), Text(m['body'] as String)]),
                    ),
                  ),
              ]);
            },
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Row(children: [
              Expanded(child: TextField(controller: _c, maxLength: 2000, decoration: const InputDecoration(hintText: 'Message the office', counterText: ''))),
              IconButton.filled(onPressed: _sending ? null : _send, icon: const Icon(Icons.send), tooltip: 'Send'),
            ]),
          ),
        ),
      ]);
}

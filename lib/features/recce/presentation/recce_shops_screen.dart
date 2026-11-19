import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../data/recce_api.dart';

Color recceStatusColor(String s) => switch (s) {
      'APPROVED' => const Color(0xFF059669),
      'REWORK_REQUIRED' => AppColors.orange,
      'REJECTED' => AppColors.error,
      'SUBMITTED' || 'UNDER_REVIEW' => AppColors.royal,
      'READY_TO_SUBMIT' => AppColors.teal,
      _ => const Color(0xFF64748B),
    };

/// A. My Assigned Projects and B. Assigned Shops: every shop given to this login, grouped by project, with status and progress.
class RecceShopsScreen extends ConsumerStatefulWidget {
  const RecceShopsScreen({super.key});

  @override
  ConsumerState<RecceShopsScreen> createState() => _RecceShopsScreenState();
}

class _RecceShopsScreenState extends ConsumerState<RecceShopsScreen> {
  String _filter = 'ALL';
  static const _filters = ['ALL', 'IN_PROGRESS', 'READY_TO_SUBMIT', 'SUBMITTED', 'REWORK_REQUIRED', 'APPROVED'];

  @override
  Widget build(BuildContext context) {
    final shops = ref.watch(recceShopsProvider);
    final queue = ref.watch(uploadQueueProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Recce evidence'), actions: [
        if (queue.isNotEmpty)
          Padding(padding: const EdgeInsets.only(right: 12), child: Chip(avatar: const Icon(Icons.cloud_upload_outlined, size: 16), label: Text('${queue.length} uploading'))),
      ]),
      body: shops.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text('$e', textAlign: TextAlign.center), const SizedBox(height: 8), FilledButton(onPressed: () => ref.invalidate(recceShopsProvider), child: const Text('Retry'))])),
        data: (all) {
          final list = _filter == 'ALL' ? all : all.where((s) => s['status'] == _filter).toList();
          final byProject = <String, List<Json>>{};
          for (final s in list) {
            byProject.putIfAbsent('${s['projectCode']}  ${s['projectName']}', () => []).add(s);
          }
          return RefreshIndicator(
            onRefresh: () async => ref.refresh(recceShopsProvider.future),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SizedBox(
                  height: 44,
                  child: ListView(scrollDirection: Axis.horizontal, children: [
                    for (final f in _filters)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(label: Text(f == 'ALL' ? 'All (${all.length})' : recceStatusLabels[f]!), selected: _filter == f, onSelected: (_) => setState(() => _filter = f)),
                      ),
                  ]),
                ),
                const SizedBox(height: 8),
                if (list.isEmpty) const AppEmpty(icon: Icons.storefront_outlined, text: 'No shops here yet. Shops given to you by Operations appear here.'),
                for (final e in byProject.entries) ...[
                  Padding(padding: const EdgeInsets.only(top: 8, bottom: 6), child: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.navy))),
                  for (final s in e.value) _ShopCard(s),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ShopCard extends StatelessWidget {
  const _ShopCard(this.s);
  final Json s;

  @override
  Widget build(BuildContext context) {
    final status = s['status'] as String;
    final progress = ((s['progress'] as num?) ?? 0).toDouble() / 100;
    final media = (s['mediaTypes'] as List).map((m) => '${m['name']} × ${m['quantity']}').join(', ');
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/recce-evidence/${s['siteId']}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text((s['shopName'] ?? s['siteCode']) as String, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
              AppStatusChip(recceStatusLabels[status] ?? status, color: recceStatusColor(status)),
            ]),
            const SizedBox(height: 4),
            Text('${s['siteCode']}${s['district'] != null ? ' · ${s['district']}' : ''}', style: const TextStyle(color: Colors.black54)),
            if ((s['address'] as String?)?.isNotEmpty ?? false) Text(s['address'] as String, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            Text(media, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: progress, minHeight: 8, color: recceStatusColor(status), backgroundColor: AppColors.softBlueBg))),
              const SizedBox(width: 10),
              Text('${s['progress']}%', style: const TextStyle(fontWeight: FontWeight.w700)),
            ]),
            if (s['reworkOpen'] == true) const Padding(padding: EdgeInsets.only(top: 6), child: Text('Reviewer asked for changes', style: TextStyle(color: AppColors.orange, fontWeight: FontWeight.w700))),
          ]),
        ),
      ),
    );
  }
}

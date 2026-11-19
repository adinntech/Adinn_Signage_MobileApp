import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';
import 'app_widgets.dart';

/// One picture for the full-screen viewer: a stored address (Spaces link or signed local-file link) or a file picked on the phone.
class AppViewerPhoto {
  const AppViewerPhoto({required this.title, this.url, this.localPath, this.subtitle});
  final String title;
  final String? subtitle;
  final String? url;
  final String? localPath;
}

/// Opens every picture full screen, same for local-disk and Spaces files: swipe between pictures, pinch / double tap to zoom,
/// thumbnail strip, download. Use this from every photo tile or file row.
Future<void> showPhotoViewer(BuildContext context, List<AppViewerPhoto> photos, {int initial = 0}) {
  if (photos.isEmpty) return Future.value();
  return Navigator.of(context, rootNavigator: true).push(PageRouteBuilder<void>(
    opaque: true,
    pageBuilder: (_, _, _) => _PhotoViewer(photos: photos, initial: initial.clamp(0, photos.length - 1)),
    transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
  ));
}

class _PhotoViewer extends StatefulWidget {
  const _PhotoViewer({required this.photos, required this.initial});
  final List<AppViewerPhoto> photos;
  final int initial;

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  late final PageController _page = PageController(initialPage: widget.initial);
  late final ScrollController _strip = ScrollController();
  late int _i = widget.initial;
  final Map<int, TransformationController> _zoom = {};
  bool _locked = false; // a zoomed picture pans instead of swiping to the next one

  TransformationController _tc(int n) => _zoom.putIfAbsent(n, () => TransformationController());

  @override
  void dispose() {
    _page.dispose();
    _strip.dispose();
    for (final c in _zoom.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _goto(int n) => _page.animateToPage(n, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);

  void _toggleZoom(int n, TapDownDetails? d) {
    final c = _tc(n);
    if (c.value.getMaxScaleOnAxis() > 1.01) {
      c.value = Matrix4.identity();
    } else {
      final p = d?.localPosition ?? Offset.zero;
      c.value = Matrix4.identity()
        ..translateByDouble(-p.dx * 1.5, -p.dy * 1.5, 0, 1)
        ..scaleByDouble(2.5, 2.5, 1, 1);
    }
    setState(() => _locked = c.value.getMaxScaleOnAxis() > 1.01);
  }

  Future<void> _download() async {
    final u = widget.photos[_i].url;
    if (u == null) return;
    final ok = await launchUrl(Uri.parse(u), mode: LaunchMode.externalApplication);
    if (!ok && mounted) toast(context, 'Could not open the download', error: true);
  }

  Widget _image(AppViewerPhoto p, {BoxFit fit = BoxFit.contain, int? cacheWidth}) {
    Widget broken() => const Center(child: Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48));
    if (p.url != null) {
      return Image.network(
        p.url!,
        fit: fit,
        cacheWidth: cacheWidth,
        loadingBuilder: (c, child, prog) => prog == null ? child : Center(child: CircularProgressIndicator(value: prog.expectedTotalBytes == null ? null : prog.cumulativeBytesLoaded / prog.expectedTotalBytes!, color: Colors.white)),
        errorBuilder: (_, _, _) => broken(),
      );
    }
    return p.localPath != null ? appImage(p.localPath!, fit: fit) : broken();
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos;
    final cur = photos[_i];
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
            child: Row(children: [
              IconButton(tooltip: 'Close', icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(cur.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  Text([if (photos.length > 1) '${_i + 1} of ${photos.length}', if ((cur.subtitle ?? '').isNotEmpty) cur.subtitle!].join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ]),
              ),
              if (cur.url != null) IconButton(tooltip: 'Download', icon: const Icon(Icons.download_outlined, color: Colors.white), onPressed: _download),
            ]),
          ),
          Expanded(
            child: PageView.builder(
              controller: _page,
              itemCount: photos.length,
              physics: _locked ? const NeverScrollableScrollPhysics() : const PageScrollPhysics(),
              onPageChanged: (n) {
                setState(() {
                  _i = n;
                  _locked = false;
                });
                if (_strip.hasClients) _strip.animateTo((n * 68.0 - 120).clamp(0, _strip.position.maxScrollExtent), duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
              },
              itemBuilder: (_, n) => GestureDetector(
                onDoubleTapDown: (d) => _toggleZoom(n, d),
                onDoubleTap: () {},
                child: InteractiveViewer(
                  transformationController: _tc(n),
                  minScale: 1,
                  maxScale: 6,
                  onInteractionEnd: (_) => setState(() => _locked = _tc(n).value.getMaxScaleOnAxis() > 1.01),
                  child: SizedBox.expand(child: _image(photos[n])),
                ),
              ),
            ),
          ),
          if (photos.length > 1)
            SizedBox(
              height: 64,
              child: ListView.builder(
                controller: _strip,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: photos.length,
                itemBuilder: (_, n) => GestureDetector(
                  onTap: () => _goto(n),
                  child: Container(
                    width: 60,
                    margin: const EdgeInsets.only(right: 8, bottom: 4, top: 4),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: n == _i ? AppColors.royal : Colors.transparent, width: 2)),
                    child: ClipRRect(borderRadius: BorderRadius.circular(6), child: Opacity(opacity: n == _i ? 1 : 0.6, child: _image(photos[n], fit: BoxFit.cover, cacheWidth: 160))),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 4),
        ]),
      ),
    );
  }
}

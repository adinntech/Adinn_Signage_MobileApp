import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/photo_service.dart';
import '../../../core/widgets/app_widgets.dart';
import '../data/field_controller.dart';
import '../domain/field_models.dart';

const markGreen = Color(0xFF22C55E);

class _Edit {
  const _Edit({this.rect, this.note = '', this.turns = 0, this.boardId});
  final List<double>? rect;
  final String note;
  final int turns;
  final String? boardId;
  _Edit copy({Object? rect = _keep, String? note, int? turns, Object? boardId = _keep}) => _Edit(
        rect: identical(rect, _keep) ? this.rect : rect as List<double>?,
        note: note ?? this.note,
        turns: turns ?? this.turns,
        boardId: identical(boardId, _keep) ? this.boardId : boardId as String?,
      );
}

const Object _keep = Object();

/// C6 (part 2) – mark the measured board: green rectangle, W × H arrows, note, rotate, undo/redo.
/// The original photo is untouched; the marked image is saved as a separate file.
class PhotoEditorScreen extends ConsumerStatefulWidget {
  const PhotoEditorScreen({super.key, required this.pid, required this.sid, required this.photoId});
  final String pid;
  final String sid;
  final String photoId;

  @override
  ConsumerState<PhotoEditorScreen> createState() => _State();
}

class _State extends ConsumerState<PhotoEditorScreen> {
  final _canvas = GlobalKey();
  final List<_Edit> _history = [const _Edit()];
  int _at = 0;
  bool _init = false;
  bool _saving = false;
  Offset? _dragStart;
  List<double>? _live;
  Size? _imageSize;

  _Edit get _e => _history[_at];
  void _push(_Edit e) => setState(() {
        _history.removeRange(_at + 1, _history.length);
        _history.add(e);
        _at++;
      });

  Future<void> _loadSize(String path) async {
    final bytes = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final f = await codec.getNextFrame();
    if (mounted) setState(() => _imageSize = Size(f.image.width.toDouble(), f.image.height.toDouble()));
  }

  Future<void> _save(PhotoRec photo, Shop shop) async {
    setState(() => _saving = true);
    try {
      final boundary = _canvas.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = await boundary.toImage(pixelRatio: 2);
      final bytes = (await img.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
      final path = await ref.read(photoServiceProvider).saveBytes(bytes, 'marked');
      photo.editedPath = path;
      photo.rect = _e.rect;
      photo.note = _e.note;
      photo.boardId = _e.boardId;
      ref.read(fieldControllerProvider.notifier).updatePhoto(widget.pid, widget.sid, photo);
      if (mounted) {
        toast(context, 'Marked photo saved');
        context.pop();
      }
    } catch (_) {
      if (mounted) toast(context, 'Could not save the marked photo', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editNote() async {
    final c = TextEditingController(text: _e.note);
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Text note'),
        content: TextField(controller: c, autofocus: true, maxLength: 80, decoration: const InputDecoration(hintText: 'e.g. Board partly hidden by tree')),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')), FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(90, 44)), onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Add'))],
      ),
    );
    c.dispose();
    if (v != null) _push(_e.copy(note: v));
  }

  @override
  Widget build(BuildContext context) {
    final f = ref.watch(fieldControllerProvider);
    final shop = f.shop(widget.pid, widget.sid);
    final photo = shop?.photos.where((p) => p.id == widget.photoId).firstOrNull;
    if (shop == null || photo == null) return Scaffold(appBar: AppBar(), body: const AppEmpty(icon: Icons.search_off, text: 'Photo not found.'));
    if (!_init) {
      _init = true;
      _history[0] = _Edit(rect: photo.rect, note: photo.note, boardId: photo.boardId ?? (shop.survey?.boards.firstOrNull?.id));
      _loadSize(photo.originalPath);
    }
    final boards = shop.survey?.boards ?? const <Board>[];
    final board = boards.where((b) => b.id == _e.boardId).firstOrNull;
    final label = board == null ? null : 'W: ${_fmt(board.width)} ft   H: ${_fmt(board.height)} ft';
    final size = _imageSize;
    final odd = _e.turns.isOdd;
    final aspect = size == null ? 1.0 : (odd ? size.height / size.width : size.width / size.height);

    return Scaffold(
      appBar: AppBar(title: const Text('Mark photo'), actions: [
        IconButton(onPressed: _at > 0 ? () => setState(() => _at--) : null, icon: const Icon(Icons.undo), tooltip: 'Undo'),
        IconButton(onPressed: _at < _history.length - 1 ? () => setState(() => _at++) : null, icon: const Icon(Icons.redo), tooltip: 'Redo'),
      ]),
      body: Column(children: [
        Expanded(
          child: Container(
            color: Colors.black,
            alignment: Alignment.center,
            child: size == null
                ? const CircularProgressIndicator(color: Colors.white)
                : AspectRatio(
                    aspectRatio: aspect,
                    child: RepaintBoundary(
                      key: _canvas,
                      child: LayoutBuilder(builder: (context, c) {
                        final box = Size(c.maxWidth, c.maxHeight);
                        Offset norm(Offset o) => Offset((o.dx / box.width).clamp(0, 1), (o.dy / box.height).clamp(0, 1));
                        return GestureDetector(
                          onPanStart: (d) => _dragStart = norm(d.localPosition),
                          onPanUpdate: (d) {
                            final a = _dragStart!;
                            final b = norm(d.localPosition);
                            setState(() => _live = [a.dx < b.dx ? a.dx : b.dx, a.dy < b.dy ? a.dy : b.dy, a.dx > b.dx ? a.dx : b.dx, a.dy > b.dy ? a.dy : b.dy]);
                          },
                          onPanEnd: (_) {
                            // One finished drag = one undoable step.
                            final r = _live;
                            _live = null;
                            if (r != null && (r[2] - r[0]) > 0.02 && (r[3] - r[1]) > 0.02) {
                              _push(_e.copy(rect: r));
                            } else {
                              setState(() {});
                            }
                          },
                          child: Stack(fit: StackFit.expand, children: [
                            RotatedBox(quarterTurns: _e.turns, child: Image.file(File(photo.originalPath), fit: BoxFit.fill)),
                            CustomPaint(painter: MarkPainter(rect: _live ?? _e.rect, label: label, note: _e.note)),
                          ]),
                        );
                      }),
                    ),
                  ),
          ),
        ),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: SafeArea(
            top: false,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (boards.isNotEmpty)
                DropdownButtonFormField<String>(
                  initialValue: board?.id,
                  decoration: const InputDecoration(labelText: 'Board measured in this photo', isDense: true),
                  items: [for (var i = 0; i < boards.length; i++) DropdownMenuItem(value: boards[i].id, child: Text('Board ${i + 1} · ${boards[i].type} · ${_fmt(boards[i].width)} × ${_fmt(boards[i].height)} ft'))],
                  onChanged: (v) => _push(_e.copy(boardId: v)),
                )
              else
                const Text('Save the survey first to label the rectangle with W × H.', style: TextStyle(color: Colors.black54, fontSize: 12)),
              const SizedBox(height: 8),
              Row(children: [
                const Expanded(child: Text('Drag on the photo to draw the green rectangle', style: TextStyle(fontSize: 12, color: Colors.black54))),
                IconButton(onPressed: () => _push(_e.copy(turns: (_e.turns + 1) % 4)), icon: const Icon(Icons.rotate_right), tooltip: 'Rotate'),
                IconButton(onPressed: _editNote, icon: const Icon(Icons.text_fields), tooltip: 'Text note'),
                IconButton(onPressed: _e.rect == null ? null : () => _push(_e.copy(rect: null)), icon: const Icon(Icons.layers_clear_outlined), tooltip: 'Clear rectangle'),
              ]),
              FilledButton.icon(onPressed: _saving || _e.rect == null ? null : () => _save(photo, shop), icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save), label: Text(_e.rect == null ? 'Draw the rectangle to save' : 'Save marked photo')),
            ]),
          ),
        ),
      ]),
    );
  }
}

String _fmt(double? v) => v == null ? '-' : (v == v.roundToDouble() ? v.toInt().toString() : v.toString());

/// Draws the green measurement rectangle, double-headed W / H arrows, the W × H label and a note strip.
class MarkPainter extends CustomPainter {
  const MarkPainter({required this.rect, this.label, this.note = ''});
  final List<double>? rect;
  final String? label;
  final String note;

  void _arrow(Canvas c, Offset a, Offset b, Paint p) {
    c.drawLine(a, b, p);
    final d = (b - a);
    final len = d.distance;
    if (len < 8) return;
    final u = d / len;
    final n = Offset(-u.dy, u.dx);
    for (final (tip, dir) in [(a, u), (b, -u)]) {
      final path = Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(tip.dx + dir.dx * 12 + n.dx * 6, tip.dy + dir.dy * 12 + n.dy * 6)
        ..lineTo(tip.dx + dir.dx * 12 - n.dx * 6, tip.dy + dir.dy * 12 - n.dy * 6)
        ..close();
      c.drawPath(path, Paint()..color = p.color);
    }
  }

  void _text(Canvas c, String t, Offset at, {Color bg = markGreen, Color fg = Colors.white, double size = 14}) {
    final tp = TextPainter(text: TextSpan(text: t, style: TextStyle(color: fg, fontSize: size, fontWeight: FontWeight.w700)), textDirection: TextDirection.ltr)..layout();
    final r = Rect.fromLTWH(at.dx, at.dy, tp.width + 12, tp.height + 6);
    c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(6)), Paint()..color = bg);
    tp.paint(c, at + const Offset(6, 3));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final r = rect;
    if (r != null) {
      final rr = Rect.fromLTRB(r[0] * size.width, r[1] * size.height, r[2] * size.width, r[3] * size.height);
      final stroke = Paint()..color = markGreen..style = PaintingStyle.stroke..strokeWidth = 4;
      canvas.drawRect(rr, stroke);
      canvas.drawRect(rr, Paint()..color = markGreen.withValues(alpha: 0.10));
      final arrow = Paint()..color = markGreen..strokeWidth = 3;
      final top = (rr.top - 18).clamp(14.0, size.height);
      _arrow(canvas, Offset(rr.left, top), Offset(rr.right, top), arrow);
      final side = (rr.right + 18).clamp(0.0, size.width - 14);
      _arrow(canvas, Offset(side, rr.top), Offset(side, rr.bottom), arrow);
      if (label != null) _text(canvas, label!, Offset(rr.left, (top - 34).clamp(2.0, size.height)));
    }
    if (note.isNotEmpty) _text(canvas, note, Offset(8, size.height - 36), bg: const Color(0xCC102449), size: 13);
  }

  @override
  bool shouldRepaint(MarkPainter o) => o.rect != rect || o.label != label || o.note != note;
}

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class SignaturePadController extends ChangeNotifier {
  final List<List<Offset>> _strokes = [];
  final GlobalKey _key = GlobalKey();

  bool get isEmpty => _strokes.isEmpty;

  void begin(Offset o) {
    _strokes.add([o]);
    notifyListeners();
  }

  void extend(Offset o) {
    if (_strokes.isEmpty) return;
    _strokes.last.add(o);
    notifyListeners();
  }

  void clear() {
    _strokes.clear();
    notifyListeners();
  }

  /// PNG of the drawn signature (white background), or null when nothing was drawn.
  Future<Uint8List?> export() async {
    if (isEmpty) return null;
    final boundary = _key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final img = await boundary.toImage(pixelRatio: 2);
    return (await img.toByteData(format: ui.ImageByteFormat.png))?.buffer.asUint8List();
  }
}

/// Finger-drawn signature box with a Clear button.
class AppSignaturePad extends StatelessWidget {
  const AppSignaturePad({super.key, required this.controller, required this.label, this.height = 150});
  final SignaturePadController controller;
  final String label;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
        ListenableBuilder(
          listenable: controller,
          builder: (_, _) => TextButton.icon(onPressed: controller.isEmpty ? null : controller.clear, icon: const Icon(Icons.refresh, size: 18), label: const Text('Clear')),
        ),
      ]),
      Container(
        height: height,
        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.black26), borderRadius: BorderRadius.circular(12)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: RepaintBoundary(
            key: controller._key,
            child: GestureDetector(
              onPanStart: (d) => controller.begin(d.localPosition),
              onPanUpdate: (d) => controller.extend(d.localPosition),
              child: ListenableBuilder(
                listenable: controller,
                builder: (_, _) => CustomPaint(painter: _SignaturePainter(controller._strokes), size: Size.infinite, child: controller.isEmpty ? const Center(child: Text('Sign here', style: TextStyle(color: Colors.black26))) : null),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

class _SignaturePainter extends CustomPainter {
  _SignaturePainter(this.strokes);
  final List<List<Offset>> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final p = Paint()..color = const Color(0xFF102449)..strokeWidth = 2.6..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
    for (final s in strokes) {
      if (s.length == 1) {
        canvas.drawCircle(s.first, 1.3, p..style = PaintingStyle.fill);
        p.style = PaintingStyle.stroke;
      } else {
        final path = Path()..moveTo(s.first.dx, s.first.dy);
        for (final o in s.skip(1)) {
          path.lineTo(o.dx, o.dy);
        }
        canvas.drawPath(path, p);
      }
    }
  }

  @override
  bool shouldRepaint(_SignaturePainter old) => true;
}

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Captures photos and keeps them in app storage. Originals are copied once and never modified;
/// edited/annotated images and signatures are written as separate files.
class PhotoService {
  const PhotoService();

  Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final d = Directory('${base.path}/recce_media');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  String _name(String prefix, String ext) => '${prefix}_${DateTime.now().microsecondsSinceEpoch}.$ext';

  /// Opens the camera (or gallery when [camera] is false). Returns the stored file path or null if cancelled.
  Future<String?> pick({bool camera = true}) async {
    final x = await ImagePicker().pickImage(source: camera ? ImageSource.camera : ImageSource.gallery, maxWidth: 2400, imageQuality: 85);
    if (x == null) return null;
    final dest = File('${(await _dir()).path}/${_name('orig', 'jpg')}');
    await File(x.path).copy(dest.path);
    return dest.path;
  }

  Future<String> saveBytes(Uint8List bytes, String prefix) async {
    final f = File('${(await _dir()).path}/${_name(prefix, 'png')}');
    await f.writeAsBytes(bytes, flush: true);
    return f.path;
  }
}

final photoServiceProvider = Provider<PhotoService>((_) => const PhotoService());

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../log.dart';

/// Foto delle lezioni (lavagna, appunti): scattate o scelte dalla galleria,
/// copiate nella cartella privata dell'app.
class LessonPhotos {
  static bool get supported =>
      defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.windows;

  /// Restituisce il percorso del file salvato, o null se annullato.
  static Future<String?> take(BuildContext context, {bool camera = true}) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: camera && defaultTargetPlatform == TargetPlatform.android ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 2000,
        imageQuality: 80,
      );
      if (picked == null) return null;
      final dir = Directory('${(await getApplicationDocumentsDirectory()).path}${Platform.pathSeparator}easylesson_foto');
      if (!await dir.exists()) await dir.create(recursive: true);
      final ext = picked.path.contains('.') ? picked.path.substring(picked.path.lastIndexOf('.')) : '.jpg';
      final dest = '${dir.path}${Platform.pathSeparator}${DateTime.now().millisecondsSinceEpoch}$ext';
      await File(picked.path).copy(dest);
      return dest;
    } catch (e, st) {
      AppLog.e('foto', e, st);
      return null;
    }
  }

  static Widget image(String path, {BoxFit fit = BoxFit.cover}) => Image.file(
        File(path),
        fit: fit,
        errorBuilder: (context, error, stack) => const Center(child: Icon(Icons.broken_image_outlined)),
      );

  static Future<void> delete(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {/* già cancellata */}
  }
}

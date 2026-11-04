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
      final dir = await folder();
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

  /// Solo per i test: cartella al posto di quella dei documenti dell'app.
  @visibleForTesting
  static Directory? folderOverride;

  /// La cartella privata delle foto.
  static Future<Directory> folder() async =>
      folderOverride ??
      Directory('${(await getApplicationDocumentsDirectory()).path}${Platform.pathSeparator}easylesson_foto');

  /// true solo se [path] è un file dentro la cartella delle foto (sicurezza EL-02: un backup può
  /// contenere un percorso qualsiasi). Si confrontano i percorsi veri, dopo i collegamenti simbolici.
  static Future<bool> isOwnPhoto(String path) async {
    try {
      final dir = await folder();
      if (!await dir.exists()) return false;
      final f = File(path);
      if (!await f.exists()) return false;
      if (await FileSystemEntity.type(path, followLinks: false) != FileSystemEntityType.file) return false;
      final base = await dir.resolveSymbolicLinks();
      final real = await f.resolveSymbolicLinks();
      final sep = Platform.pathSeparator;
      final prefix = base.endsWith(sep) ? base : '$base$sep';
      return Platform.isWindows ? real.toLowerCase().startsWith(prefix.toLowerCase()) : real.startsWith(prefix);
    } catch (_) {
      return false;
    }
  }

  static final _checked = <String, Future<bool>>{};

  static Widget image(String path, {BoxFit fit = BoxFit.cover}) => FutureBuilder<bool>(
        future: _checked.putIfAbsent(path, () => isOwnPhoto(path)),
        builder: (context, snap) {
          if (snap.data != true) {
            return Center(
              child: snap.connectionState == ConnectionState.done
                  ? const Icon(Icons.broken_image_outlined)
                  : const SizedBox.shrink(),
            );
          }
          return Image.file(
            File(path),
            fit: fit,
            errorBuilder: (context, error, stack) => const Center(child: Icon(Icons.broken_image_outlined)),
          );
        },
      );

  /// Cancella il file solo se è davvero una foto dell'app; altrimenti si toglie solo la voce.
  static Future<void> delete(String path) async {
    _checked.remove(path);
    try {
      if (!await isOwnPhoto(path)) {
        AppLog.w('foto', 'Cancellazione rifiutata: il file non è nella cartella delle foto');
        return;
      }
      await File(path).delete();
    } catch (_) {/* già cancellata */}
  }
}

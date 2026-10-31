import 'package:flutter/material.dart';

/// Versione web: niente foto (non c'è una cartella dove salvarle).
class LessonPhotos {
  static bool get supported => false;

  static Future<String?> take(BuildContext context, {bool camera = true}) async => null;

  static Widget image(String path, {BoxFit fit = BoxFit.cover}) => const SizedBox();

  static Future<void> delete(String path) async {}
}

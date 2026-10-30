import 'dart:convert';

import 'package:url_launcher/url_launcher.dart';

/// Versione web: apre il file come download (il browser lo salva o lo apre
/// direttamente con il calendario). Restituisce '' se avviato.
Future<String?> saveTextFile(String name, String content, {String mime = 'text/plain'}) async {
  final uri = Uri.dataFromString(content, mimeType: mime, encoding: utf8);
  final ok = await launchUrl(uri, webOnlyWindowName: '_blank');
  return ok ? '' : null;
}

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Repository da cui arrivano le release (installer Windows, APK Android).
const githubRepo = 'Andrea-nonloso/Easy-lesson-v2';

class UpdateInfo {
  const UpdateInfo({required this.version, required this.pageUrl, this.downloadUrl});

  final String version;
  final Uri pageUrl;

  /// File da scaricare per questa piattaforma (APK o installer), se presente.
  final Uri? downloadUrl;
}

/// Controlla su GitHub se esiste una versione più recente dell'app.
///
/// - Android e Windows: scarica il nuovo APK / installer, che si installa sopra.
/// - Web: si aggiorna da solo ricaricando la pagina.
class Updater {
  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.windows);

  static Future<String> currentVersion() async {
    try {
      return (await PackageInfo.fromPlatform()).version;
    } catch (_) {
      return '';
    }
  }

  /// Restituisce null se l'app è aggiornata o se il controllo non riesce.
  static Future<UpdateInfo?> check() async {
    try {
      final res = await http.get(
        Uri.parse('https://api.github.com/repos/$githubRepo/releases/latest'),
        headers: const {'Accept': 'application/vnd.github+json'},
      ).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return null;
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      final latest = '${j['tag_name'] ?? ''}'.replaceFirst(RegExp(r'^v'), '');
      final current = await currentVersion();
      if (latest.isEmpty || current.isEmpty || compareVersions(latest, current) <= 0) return null;

      final assets = (j['assets'] as List? ?? const []).whereType<Map>().toList();
      Uri? asset(bool Function(String name) match) {
        for (final a in assets) {
          final name = '${a['name']}'.toLowerCase();
          if (match(name)) return Uri.tryParse('${a['browser_download_url']}');
        }
        return null;
      }

      final download = defaultTargetPlatform == TargetPlatform.android
          ? asset((n) => n.endsWith('.apk'))
          : asset((n) => n.endsWith('.exe')) ?? asset((n) => n.contains('windows') && n.endsWith('.zip'));
      return UpdateInfo(
        version: latest,
        pageUrl: Uri.parse(j['html_url'] is String
            ? j['html_url'] as String
            : 'https://github.com/$githubRepo/releases/latest'),
        downloadUrl: download,
      );
    } catch (_) {
      return null;
    }
  }

  /// Apre il download nel browser (Android: poi si tocca il file per installarlo;
  /// Windows: si avvia l'installer, che chiude e sostituisce la versione vecchia).
  static Future<void> open(UpdateInfo info) =>
      launchUrl(info.downloadUrl ?? info.pageUrl, mode: LaunchMode.externalApplication);
}

/// Confronta versioni "2.1.0" / "2.0.10": >0 se a è più recente di b.
int compareVersions(String a, String b) {
  List<int> parts(String v) =>
      v.split(RegExp(r'[.+-]')).map((p) => int.tryParse(p) ?? 0).toList();
  final pa = parts(a), pb = parts(b);
  for (var i = 0; i < 3; i++) {
    final x = i < pa.length ? pa[i] : 0;
    final y = i < pb.length ? pb[i] : 0;
    if (x != y) return x.compareTo(y);
  }
  return 0;
}

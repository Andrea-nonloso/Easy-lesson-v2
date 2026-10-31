import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Repository da cui arrivano le release (installer Windows, APK Android).
const githubRepo = 'Andrea-nonloso/Easy-lesson-v2';

class UpdateInfo {
  const UpdateInfo({required this.version, required this.pageUrl, this.downloadUrl, this.prerelease = false});

  final String version;

  /// true = versione beta (pre-release su GitHub).
  final bool prerelease;
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

  /// Tag della release da cui viene questa build (es. "v2.5.0-beta.1"), passato dalla CI
  /// con --dart-define=EL_TAG=... ; vuoto nelle build fatte a mano.
  static const buildTag = String.fromEnvironment('EL_TAG');

  /// Opzioni sviluppatore: fa finta di avere una versione vecchia per provare l'aggiornamento.
  static bool pretendOld = false;

  /// Ultimo controllo fatto (per ricontrollare quando si torna nell'app).
  static DateTime? lastCheck;

  /// Risposta grezza dell'ultimo controllo (per le opzioni sviluppatore).
  static String? lastResponse;

  /// Versione installata: quella del tag se c'è (così le beta si distinguono), altrimenti pubspec.
  static Future<String> currentVersion() async {
    if (buildTag.isNotEmpty) return buildTag.replaceFirst(RegExp(r'^v'), '');
    try {
      return (await PackageInfo.fromPlatform()).version;
    } catch (_) {
      return '';
    }
  }

  /// Restituisce null se l'app è aggiornata o se il controllo non riesce.
  /// [beta] = canale "Beta": considera anche le pre-release (tag con il trattino).
  static Future<UpdateInfo?> check({bool beta = false}) async {
    try {
      final res = await http.get(
        Uri.parse(beta
            ? 'https://api.github.com/repos/$githubRepo/releases?per_page=20'
            : 'https://api.github.com/repos/$githubRepo/releases/latest'),
        headers: const {'Accept': 'application/vnd.github+json'},
      ).timeout(const Duration(seconds: 15));
      lastCheck = DateTime.now();
      lastResponse = 'HTTP ${res.statusCode} · limite GitHub: ${res.headers['x-ratelimit-remaining'] ?? '?'}'
          '/${res.headers['x-ratelimit-limit'] ?? '?'}\n${res.body.length > 4000 ? '${res.body.substring(0, 4000)}…' : res.body}';
      if (res.statusCode != 200) return null;
      final body = jsonDecode(res.body);
      Map<String, dynamic>? j;
      if (body is List) {
        // La release con la versione più alta (stabile o pre-release, mai bozze).
        for (final r in body.whereType<Map>()) {
          if (r['draft'] == true) continue;
          final tag = '${r['tag_name'] ?? ''}'.replaceFirst(RegExp(r'^v'), '');
          final best = j == null ? '' : '${j['tag_name'] ?? ''}'.replaceFirst(RegExp(r'^v'), '');
          if (tag.isNotEmpty && (j == null || compareVersions(tag, best) > 0)) j = Map<String, dynamic>.from(r);
        }
      } else if (body is Map) {
        j = Map<String, dynamic>.from(body);
      }
      if (j == null) return null;
      final latest = '${j['tag_name'] ?? ''}'.replaceFirst(RegExp(r'^v'), '');
      final current = pretendOld ? '0.0.1' : await currentVersion();
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
        prerelease: j['prerelease'] == true,
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

/// Confronta versioni "2.1.0" / "2.0.10" / "2.5.0-beta.2": >0 se a è più recente di b.
/// Come semver: "2.5.0-beta.1" < "2.5.0-beta.2" < "2.5.0" (la stabile vince sulla beta).
int compareVersions(String a, String b) {
  String core(String v) => v.split('+').first.split('-').first;
  String pre(String v) {
    final noBuild = v.split('+').first;
    final i = noBuild.indexOf('-');
    return i < 0 ? '' : noBuild.substring(i + 1);
  }

  List<int> parts(String v) => core(v).split('.').map((p) => int.tryParse(p) ?? 0).toList();
  final pa = parts(a), pb = parts(b);
  for (var i = 0; i < 3; i++) {
    final x = i < pa.length ? pa[i] : 0;
    final y = i < pb.length ? pb[i] : 0;
    if (x != y) return x.compareTo(y);
  }
  final ra = pre(a), rb = pre(b);
  if (ra == rb) return 0;
  if (ra.isEmpty) return 1; // stabile > beta
  if (rb.isEmpty) return -1;
  final xa = ra.split('.'), xb = rb.split('.');
  for (var i = 0; i < xa.length && i < xb.length; i++) {
    final na = int.tryParse(xa[i]), nb = int.tryParse(xb[i]);
    final c = (na != null && nb != null) ? na.compareTo(nb) : xa[i].compareTo(xb[i]);
    if (c != 0) return c;
  }
  return xa.length.compareTo(xb.length);
}

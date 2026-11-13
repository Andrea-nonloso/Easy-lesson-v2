import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart' show SecretKey;
import 'package:http/http.dart' as http;

import 'crypto_box.dart';
import 'live_sync.dart';
import 'log.dart';
import 'native.dart';
import 'progress.dart';
import 'store.dart';
import 'i18n.dart';

export 'crypto_box.dart' show normalizeAccountCode, looksLikeAccountCode, generateAccountCode;

/// Indirizzo del server (Cloudflare Worker). Si può cambiare SOLO in compilazione con
/// --dart-define=EL_CLOUD=https://… (sicurezza EL-01: nessun backup o opzione lo cambia).
const cloudDefaultUrl = String.fromEnvironment('EL_CLOUD', defaultValue: 'https://easylesson-api.khugudvjan.cc');

class CloudException implements Exception {
  CloudException(this.message, [this.status]);
  final String message;
  final int? status;
  @override
  String toString() => message;
}

/// Chiamate al server Easy Lesson Cloud. Il codice non viene mai mandato: solo il suo token.
class Cloud {
  Cloud._();

  /// Solo per i test e il codice: nessuna opzione lo imposta (null = quello predefinito).
  /// Il token dell'account va comunque solo a [cloudDefaultUrl] (vedi [raw]).
  static String? overrideUrl;
  static String get baseUrl => (overrideUrl == null || overrideUrl!.trim().isEmpty) ? cloudDefaultUrl : overrideUrl!.trim();

  /// Ultima risposta grezza (per il menu sviluppatore).
  static String? lastResponse;

  static http.Client client = http.Client();
  static const _timeout = Duration(seconds: 20);

  static Uri _u(String path, [String? base]) => Uri.parse('${(base ?? baseUrl).replaceAll(RegExp(r'/+$'), '')}/v1$path');

  /// Chiamata generica: restituisce il corpo, o lancia CloudException con un messaggio chiaro.
  /// [code] = codice dell'account (si manda il suo token).
  /// [base] = un nostro server diretto (casa, nodo 2: lo dice /v1/health in "live"), per il canale in diretta e le
  /// chat: così non si consumano le richieste del Worker. Il token ci va solo se è [isTrustedLiveServer].
  static Future<String> raw(String method, String path, {String? code, String? bearer, Object? body, String? base}) async {
    final uri = _u(path, base);
    final trusted = base == null ? isTrustedServer(uri) : isTrustedLiveServer(uri);
    if ((code != null || bearer != null) && !trusted) {
      AppLog.w('cloud', 'Token NON mandato a un server diverso da quello ufficiale: ${uri.host}');
      throw CloudException(tr('Server non attendibile: il codice dell\'account non viene usato', 'Untrusted server: the account code isn\'t used'));
    }
    final req = http.Request(method, uri);
    if (code != null) req.headers['authorization'] = 'Bearer ${await authToken(code)}';
    if (bearer != null) req.headers['authorization'] = 'Bearer $bearer';
    if (body != null) {
      req.headers['content-type'] = 'application/json';
      req.body = body is String ? body : jsonEncode(body);
    }
    http.Response res;
    try {
      res = await http.Response.fromStream(await client.send(req).timeout(_timeout)).timeout(_timeout);
    } on TimeoutException {
      throw CloudException(tr('Il server non risponde: riprova più tardi', 'The server isn\'t responding: try again later'));
    } catch (e) {
      throw CloudException(tr('Niente connessione al server ($e)', 'No connection to the server ($e)'));
    }
    final text = utf8.decode(res.bodyBytes, allowMalformed: true);
    lastResponse = '$method $path → HTTP ${res.statusCode}\n\n${text.length > 4000 ? '${text.substring(0, 4000)}…' : text}';
    if (res.statusCode >= 200 && res.statusCode < 300) return text;
    var msg = tr('Errore del server (HTTP ${res.statusCode})', 'Server error (HTTP ${res.statusCode})');
    try {
      final j = jsonDecode(text);
      if (j is Map && j['error'] is String) msg = j['error'] as String;
    } catch (_) {}
    AppLog.w('cloud', '$method $path: ${res.statusCode} $msg');
    throw CloudException(msg, res.statusCode);
  }

  /// Il token si manda solo al server ufficiale, in HTTPS (http solo per un server di prova
  /// sul computer, se l'indirizzo ufficiale stesso è localhost).
  static bool isTrustedServer(Uri u) {
    final official = Uri.parse(cloudDefaultUrl);
    if (u.host != official.host || u.port != official.port) return false;
    if (u.scheme == 'https') return true;
    return u.scheme == 'http' && official.scheme == 'http' && (u.host == 'localhost' || u.host == '127.0.0.1');
  }

  /// Come [raw] ma con byte (immagini dei grandi): [body] = byte da mandare, risposta = byte.
  static Future<Uint8List> bytes(String method, String path,
      {required String code, Uint8List? body, String contentType = 'application/octet-stream', String? base}) async {
    final uri = _u(path, base);
    final trusted = base == null ? isTrustedServer(uri) : isTrustedLiveServer(uri);
    if (!trusted) throw CloudException(tr('Server non attendibile: il codice dell\'account non viene usato', 'Untrusted server: the account code isn\'t used'));
    final req = http.Request(method, uri)..headers['authorization'] = 'Bearer ${await authToken(code)}';
    if (body != null) {
      req.headers['content-type'] = contentType;
      req.bodyBytes = body;
    }
    http.Response res;
    try {
      res = await http.Response.fromStream(await client.send(req).timeout(const Duration(seconds: 60))).timeout(const Duration(seconds: 60));
    } on TimeoutException {
      throw CloudException(tr('Il server non risponde: riprova più tardi', 'The server isn\'t responding: try again later'));
    } catch (e) {
      throw CloudException(tr('Niente connessione al server ($e)', 'No connection to the server ($e)'));
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return res.bodyBytes;
    var msg = tr('Errore del server (HTTP ${res.statusCode})', 'Server error (HTTP ${res.statusCode})');
    try {
      final j = jsonDecode(utf8.decode(res.bodyBytes, allowMalformed: true));
      if (j is Map && j['error'] is String) msg = j['error'] as String;
    } catch (_) {}
    throw CloudException(msg, res.statusCode);
  }

  /// I nostri server diretti: https://easylesson-<qualcosa>.<stesso dominio di quello ufficiale>
  /// (es. easylesson-casa.khugudvjan.cc), oppure quello ufficiale stesso. Per le prove in locale: come [isTrustedServer].
  static bool isTrustedLiveServer(Uri u) {
    if (isTrustedServer(u)) return true;
    final official = Uri.parse(cloudDefaultUrl);
    final dot = official.host.indexOf('.');
    if (dot < 0 || u.scheme != 'https' || u.hasPort && u.port != 443) return false;
    final parent = official.host.substring(dot + 1);
    if (!parent.contains('.')) return false; // mai un dominio di primo livello da solo
    final label = u.host.endsWith('.$parent') ? u.host.substring(0, u.host.length - parent.length - 1) : null;
    return label != null && RegExp(r'^easylesson-[a-z0-9-]{1,40}$').hasMatch(label);
  }

  /// /v1/health completo: chi risponde (node), dove aprire il canale in diretta (live), chat accese (chat).
  static Future<Map<String, dynamic>> healthInfo() => _json('GET', '/health');

  /// Biglietto monouso (60 s) per aprire il canale in diretta su [base], senza mettere il token nell'indirizzo.
  static Future<String> liveTicket(String base, String code) async {
    final j = jsonDecode(await raw('POST', '/live/ticket', code: code, base: base));
    final t = j is Map ? j['ticket'] : null;
    if (t is! String || t.isEmpty) throw CloudException('Risposta strana dal server');
    return t;
  }

  /// "Sta scrivendo" ([chat] = "class:<id>" o "adult"). Non si salva da nessuna parte.
  static Future<void> liveTyping(String base, String code, String chat) =>
      raw('POST', '/live/typing', code: code, base: base, body: {'chat': chat});

  /// 3.8: notifiche push (Firebase): il token di questo telefono, sul nostro server [base].
  static Future<void> pushRegister(String base, String code, String token) =>
      raw('POST', '/social/push', code: code, base: base, body: {'token': token});

  /// 3.9: blocchi di lezione in cui il server non manda notifiche push dei messaggi (riassunto alla fine).
  static Future<void> pushQuiet(String base, String code, List<List<int>> windows) =>
      raw('PUT', '/social/push/quiet', code: code, base: base, body: {'windows': windows});

  static Future<void> pushUnregister(String base, String code, String token) =>
      raw('DELETE', '/social/push', code: code, base: base, body: {'token': token});

  static Future<Map<String, dynamic>> _json(String method, String path, {String? code, String? bearer, Object? body}) async {
    final t = await raw(method, path, code: code, bearer: bearer, body: body);
    try {
      final j = jsonDecode(t);
      return j is Map<String, dynamic> ? j : <String, dynamic>{};
    } catch (_) {
      throw CloudException('Risposta strana dal server');
    }
  }

  static Future<bool> health() async {
    try {
      return (await _json('GET', '/health'))['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Registra un codice generato dal telefono (al server va solo il token).
  static Future<void> createAccount(String code) async {
    await _json('POST', '/account', body: {'token': await authToken(code)});
  }

  /// Info sull'account: lancia CloudException(401) se il codice non esiste.
  static Future<Map<String, dynamic>> me(String code) => _json('GET', '/me', code: code);

  static Future<void> deleteAccount(String code) => raw('DELETE', '/account', code: code);

  /// Chiavi avvolte dell'account (null = non ancora create).
  static Future<KeyBundle?> getKeys(String code) async {
    try {
      return KeyBundle.fromJson(await _json('GET', '/keys', code: code));
    } on CloudException catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  static Future<void> putKeys(String code, KeyBundle keys, {String? recoveryCode}) async {
    await _json('PUT', '/keys', code: code, body: {
      'keys': keys.toJson(),
      if (recoveryCode != null) 'recoveryToken': await authToken(recoveryCode),
    });
  }

  /// Entra con il codice di recupero e imposta [newCode] come nuovo codice. Restituisce le chiavi.
  static Future<KeyBundle?> recover(String recoveryCode, String newCode) async {
    final j = await _json('POST', '/account/recover', code: recoveryCode, body: {'newToken': await authToken(newCode)});
    return KeyBundle.fromJson(j['keys']);
  }

  /// Ora (ms) dell'ultimo azzeramento dei progressi fatto dalla moderazione (0 = mai), dall'ultima risposta.
  static int lastResetAt = 0;

  static int _resetOf(Map<String, dynamic> j) => (j['resetAt'] as num?)?.toInt() ?? 0;

  static Future<ProgressData> pullProgress(String code) async {
    final j = await _json('GET', '/progress', code: code);
    lastResetAt = _resetOf(j);
    return ProgressData.fromJson(j);
  }

  /// Manda i progressi e riceve l'unione con quelli del server. [resetSeen] = ultimo azzeramento già applicato qui:
  /// se il server ne ha uno più nuovo, non unisce quello che mandiamo e ci rimanda i progressi azzerati.
  static Future<ProgressData> pushProgress(String code, ProgressData p, {int resetSeen = 0}) async {
    final j = await _json('PUT', '/progress', code: code, body: {...p.toJson(), 'resetSeen': resetSeen});
    lastResetAt = _resetOf(j);
    return ProgressData.fromJson(j);
  }

  /// Ora (del server, ms) dell'ultimo backup caricato da qui.
  static int? lastUploadAt;

  static Future<int> uploadBackup(String code, String backupJson) async {
    final j = await _json('PUT', '/backup', code: code, body: backupJson);
    lastUploadAt = (j['at'] as num?)?.toInt();
    return (j['size'] as num?)?.toInt() ?? backupJson.length;
  }

  static Future<String> downloadBackup(String code) => raw('GET', '/backup', code: code);

  static Future<void> deleteBackup(String code) => raw('DELETE', '/backup', code: code);

  static Future<List<Map<String, dynamic>>> rewards() async {
    final j = await _json('GET', '/rewards');
    final list = j['rewards'];
    return list is List ? [for (final r in list) if (r is Map) Map<String, dynamic>.from(r)] : const [];
  }

  /// Eventi speciali delle missioni (in corso e in arrivo), come JSON grezzo.
  static Future<List<Map<String, dynamic>>> events() async {
    final j = await _json('GET', '/events');
    final list = j['events'];
    return list is List ? [for (final e in list) if (e is Map) Map<String, dynamic>.from(e)] : const [];
  }

  /// Avvisi in corso per questa versione e piattaforma.
  static Future<List<Map<String, dynamic>>> announcements({String? version, String? platform}) async {
    final q = [
      if (version != null && version.isNotEmpty) 'v=${Uri.encodeQueryComponent(version)}',
      if (platform != null) 'p=$platform',
    ].join('&');
    final j = await _json('GET', '/announcements${q.isEmpty ? '' : '?$q'}');
    final list = j['announcements'];
    return list is List ? [for (final a in list) if (a is Map) Map<String, dynamic>.from(a)] : const [];
  }

  static String rewardFileUrl(String file) => _u('/rewards/file/${Uri.encodeComponent(file)}').toString();
}

/// La chiave dei dati (DEK) dell'account, tenuta solo in memoria.
class CloudKeys {
  CloudKeys._();

  static SecretKey? _dek;
  static String? _forCode;

  static void remember(SecretKey dek, String code) {
    _dek = dek;
    _forCode = code;
  }

  static void forget() {
    _dek = null;
    _forCode = null;
  }

  /// Apre la DEK con il codice. Se l'account non ha ancora chiavi, le crea con un codice di
  /// recupero nuovo (salvato sul dispositivo e da mostrare all'utente: 'cloud.recoveryPending').
  static Future<SecretKey> dek(AppStore store) async {
    final code = store.accountCode;
    if (code == null) throw CloudException(tr('Nessun account', 'No account'));
    if (_dek != null && _forCode == code) return _dek!;
    final bundle = await Cloud.getKeys(code);
    if (bundle == null) {
      final rec = generateAccountCode();
      final (fresh, dek) = await KeyBundle.create(code, rec);
      await Cloud.putKeys(code, fresh, recoveryCode: rec);
      await store.setRecoveryCode(rec);
      await store.setOpt('cloud.recoveryPending', true);
      remember(dek, code);
      return dek;
    }
    try {
      final dek = await bundle.openWithCode(code);
      remember(dek, code);
      return dek;
    } on CryptoFailure {
      throw CloudException(tr('Non riesco ad aprire le chiavi con questo codice: usa il codice di recupero', 'Can\'t open the keys with this code: use the recovery code'));
    }
  }
}

/// Le operazioni dell'account, dall'inizio alla fine.
class CloudAccount {
  CloudAccount._();

  /// Crea l'account: codice e codice di recupero generati qui, chiavi create e salvate.
  static Future<(String, String)> create(AppStore store) async {
    var code = generateAccountCode();
    try {
      await Cloud.createAccount(code);
    } on CloudException catch (e) {
      // Codice già esistente: praticamente impossibile, ma si riprova una volta.
      if (e.status != 409) rethrow;
      code = generateAccountCode();
      await Cloud.createAccount(code);
    }
    final rec = generateAccountCode();
    final (bundle, dek) = await KeyBundle.create(code, rec);
    await Cloud.putKeys(code, bundle, recoveryCode: rec);
    CloudKeys.remember(dek, code);
    await store.setAccountCode(code);
    await store.setRecoveryCode(rec);
    await CloudVault.save(store);
    return (code, rec);
  }

  /// Entra con un codice esistente (controlla che esista e unisce i progressi).
  static Future<Map<String, dynamic>> login(AppStore store, String code) async {
    final me = await Cloud.me(code);
    CloudKeys.forget();
    await store.setAccountCode(code);
    await store.setRecoveryCode(null);
    await store.applyProgress(await Cloud.pullProgress(code), resetAt: Cloud.lastResetAt);
    await CloudSync.syncNow(store, quiet: true);
    await CloudVault.save(store);
    return me;
  }

  /// Ho perso il codice: entra con quello di recupero, crea un codice nuovo e lo restituisce.
  static Future<String> recover(AppStore store, String recoveryCode) async {
    final newCode = generateAccountCode();
    final bundle = await Cloud.recover(recoveryCode, newCode);
    if (bundle != null) {
      final SecretKey dek;
      try {
        dek = await bundle.openWithRecovery(recoveryCode);
      } on CryptoFailure {
        throw CloudException(tr('Il codice di recupero non apre le chiavi', 'The recovery code doesn\'t open the keys'));
      }
      await Cloud.putKeys(newCode, await bundle.withNewCode(dek, newCode));
      CloudKeys.remember(dek, newCode);
    }
    await store.setAccountCode(newCode);
    await store.setRecoveryCode(recoveryCode);
    await store.applyProgress(await Cloud.pullProgress(newCode), resetAt: Cloud.lastResetAt);
    await CloudVault.save(store);
    AppLog.i('cloud', 'Account recuperato con il codice di recupero');
    return newCode;
  }

  /// Codice di recupero nuovo (quello vecchio smette di funzionare).
  static Future<String> newRecoveryCode(AppStore store) async {
    final code = store.accountCode;
    if (code == null) throw CloudException(tr('Nessun account', 'No account'));
    final dek = await CloudKeys.dek(store);
    final bundle = await Cloud.getKeys(code);
    if (bundle == null) throw CloudException(tr('Chiavi non trovate', 'Keys not found'));
    final rec = generateAccountCode();
    await Cloud.putKeys(code, await bundle.withNewRecovery(dek, rec), recoveryCode: rec);
    await store.setRecoveryCode(rec);
    await store.setOpt('cloud.recoveryPending', null);
    await CloudVault.save(store);
    return rec;
  }

  /// Scollega il dispositivo (l'account resta sul server).
  static Future<void> logout(AppStore store) async {
    CloudKeys.forget();
    await store.setAccountCode(null);
    await store.setRecoveryCode(null);
    await CloudVault.clear();
    // Classe e amici appartengono all'account.
    for (final k in ['social.nick', 'social.classes', 'social.at']) {
      await store.setOpt(k, null);
    }
  }
}

/// Copia dei codici nel "Block Store" di Android: Google la salva cifrata nel backup del
/// telefono e la rimette da sola su un telefono nuovo con lo stesso account Google.
class CloudVault {
  CloudVault._();

  static bool get supported => NativeBridge.supported;

  static Future<void> save(AppStore store) async {
    final code = store.accountCode;
    if (!supported || code == null || !store.opt('cloud.vault', true)) return;
    final ok = await NativeBridge.vaultSave(jsonEncode({'code': code, if (store.recoveryCode != null) 'recovery': store.recoveryCode}));
    AppLog.i('cloud', ok ? 'Codice salvato nel backup di Google' : 'Backup di Google non disponibile');
  }

  /// Codici trovati nel backup di Google: (codice, recupero) oppure null.
  static Future<(String, String?)?> read() async {
    if (!supported) return null;
    final raw = await NativeBridge.vaultRead();
    if (raw == null || raw.isEmpty) return null;
    try {
      final j = jsonDecode(raw);
      if (j is Map && j['code'] is String && looksLikeAccountCode(j['code'] as String)) {
        return (j['code'] as String, j['recovery'] as String?);
      }
    } catch (_) {}
    return null;
  }

  static Future<void> clear() async {
    if (supported) await NativeBridge.vaultDelete();
  }
}

/// Sincronizzazione automatica: progressi poco dopo ogni cambiamento, backup al massimo una volta al giorno.
class CloudSync {
  CloudSync._();

  static Timer? _timer;
  static bool _busy = false;
  static DateTime? _lastEnd;

  /// Da chiamare quando cambiano i progressi: si sincronizza dopo qualche secondo di calma.
  /// I cambiamenti fatti dalla sincronizzazione stessa non ne fanno partire un'altra.
  static void schedule(AppStore store, {Duration delay = const Duration(seconds: 15)}) {
    if (store.accountCode == null) return;
    if (_busy || (_lastEnd != null && DateTime.now().difference(_lastEnd!) < const Duration(seconds: 5))) return;
    _timer?.cancel();
    _timer = Timer(delay, () => syncNow(store, quiet: true));
  }

  /// Sincronizzazione completa tra dispositivi accesa (serve anche il consenso al backup online).
  static bool live(AppStore store) =>
      store.accountCode != null && store.opt('cloud.live', false) && store.opt('cloud.consent', false);

  /// All'avvio e quando si torna nell'app: sincronizza solo se sono passate almeno 2 ore
  /// (2 minuti con la sincronizzazione completa).
  static void maybeSync(AppStore store) {
    if (store.accountCode == null) return;
    final last = DateTime.tryParse(store.opt('cloud.lastSync', ''));
    final every = live(store) ? const Duration(minutes: 2) : const Duration(hours: 2);
    if (last == null || DateTime.now().difference(last) > every) {
      schedule(store, delay: const Duration(seconds: 6));
    }
  }

  /// Progressi (sempre) e backup automatico (se attivo e passato un giorno). Restituisce un messaggio.
  static Future<String> syncNow(AppStore store, {bool quiet = false}) async {
    final code = store.accountCode;
    if (code == null) return tr('Nessun account', 'No account');
    if (_busy) return tr('Sincronizzazione già in corso', 'Sync already in progress');
    _busy = true;
    try {
      var merged = await Cloud.pushProgress(code, store.progressData, resetSeen: store.opt('cloud.resetSeen', 0));
      if (Cloud.lastResetAt > store.opt('cloud.resetSeen', 0)) {
        // La moderazione ha azzerato i progressi: si azzera qui e si rimanda la versione pulita.
        await store.applyProgress(merged, resetAt: Cloud.lastResetAt);
        merged = await Cloud.pushProgress(code, store.progressData, resetSeen: store.opt('cloud.resetSeen', 0));
      }
      await store.applyProgress(merged);
      await store.setOpt('cloud.lastSync', DateTime.now().toIso8601String());
      var msg = 'Progressi sincronizzati';
      if (live(store)) {
        final got = await _pullOther(store);
        if (got > 0) msg += ' · $got cambiamenti dall\'altro dispositivo';
        final sent = await uploadBackupIfChanged(store);
        if (sent) msg += ' · dati inviati';
        await store.setOpt('cloud.syncBase', jsonEncode(syncHashes(store.backupPrefs(sections(store)))));
      } else if (store.opt('cloud.auto', false)) {
        final last = DateTime.tryParse(store.opt('cloud.backupAt', ''));
        if (last == null || DateTime.now().difference(last) > const Duration(hours: 20)) {
          final sent = await uploadBackupIfChanged(store);
          if (sent) msg += tr(' · backup aggiornato', ' · backup updated');
        }
      }
      return msg;
    } on CloudException catch (e) {
      if (!quiet) rethrow;
      AppLog.w('cloud', 'Sincronizzazione non riuscita: ${e.message}');
      return e.message;
    } catch (e) {
      // Risposta strana: mai far cadere l'app.
      if (!quiet) throw CloudException('Errore: $e');
      AppLog.w('cloud', 'Sincronizzazione non riuscita: $e');
      return '$e';
    } finally {
      _busy = false;
      _lastEnd = DateTime.now();
    }
  }

  /// Codice di questo dispositivo (resta qui: le opzioni cloud.* non viaggiano).
  static Future<String> deviceId(AppStore store) async {
    var id = store.opt('cloud.device', '');
    if (id.isEmpty) {
      id = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
      await store.setOpt('cloud.device', id);
    }
    return id;
  }

  /// Se sul server c'è un backup più nuovo fatto da un ALTRO dispositivo, lo unisce a quello di qui.
  /// Restituisce quante chiavi sono cambiate.
  static Future<int> _pullOther(AppStore store) async {
    final code = store.accountCode!;
    final me = await Cloud.me(code);
    final b = me['backup'];
    final at = b is Map ? (b['at'] as num?)?.toInt() : null;
    if (at == null || at <= store.opt('cloud.seenAt', 0)) return 0;
    final m = Map<String, dynamic>.from(jsonDecode(await Cloud.downloadBackup(code)) as Map);
    await store.setOpt('cloud.seenAt', at);
    if (m['from'] == await deviceId(store)) return 0;
    final remote = withoutPlainSensitive(Map<String, Object?>.from((m['prefs'] as Map?) ?? const {}));
    if (m['secret'] != null) {
      try {
        remote.addAll(await openJson(m['secret'], await CloudKeys.dek(store)));
      } on CryptoFailure catch (e) {
        AppLog.w('cloud', 'Sincronizzazione: parte cifrata illeggibile (${e.message})');
        return 0;
      }
    }
    final secs = sections(store);
    remote.removeWhere((k, _) => !secs.contains(backupSectionOf(k)));
    Map<String, int> base;
    try {
      base = Map<String, int>.from(jsonDecode(store.opt('cloud.syncBase', '{}')) as Map);
    } catch (_) {
      base = {};
    }
    final merged = mergeSync(local: store.backupPrefs(secs), remote: remote, base: base);
    if (merged.changed.isEmpty) return 0;
    final keys = {for (final k in merged.changed) k.startsWith('$extrasKey/') ? extrasKey : k};
    // Le opzioni di questo dispositivo (cloud.*…) restano: mergeSync parte da quelle di qui.
    await store.restore(jsonEncode({
      'easyLessonBackup': 3,
      'prefs': {for (final k in keys) k: merged.prefs[k]},
    }));
    AppLog.i('cloud', 'Sincronizzazione: ${merged.changed.length} cambiamenti da un altro dispositivo');
    return merged.changed.length;
  }

  /// Sicurezza EL-04: i dati sensibili si accettano solo dalla parte cifrata e autenticata
  /// (AES-GCM). Se arrivano in chiaro in "prefs" (server manomesso, backup sostituito) si scartano.
  static Map<String, T> withoutPlainSensitive<T>(Map<String, T> prefs) {
    final bad = prefs.keys.where(isSensitiveKey).toList();
    if (bad.isNotEmpty) {
      AppLog.w('cloud', 'Backup: ${bad.length} dati sensibili in chiaro scartati (${bad.join(', ')})');
      prefs.removeWhere((k, _) => isSensitiveKey(k));
    }
    return prefs;
  }

  /// Sezioni del backup scelte dall'utente.
  static Set<String> sections(AppStore store) {
    final s = store.opt('cloud.sections', '');
    return s.isEmpty ? {...defaultBackupSections} : s.split(',').where((x) => x.isNotEmpty).toSet();
  }

  /// Carica il backup solo se è cambiato dall'ultima volta. true = caricato.
  /// Le parti sensibili (voti, assenze, agenda, nome…) partono già cifrate.
  static Future<bool> uploadBackupIfChanged(AppStore store, {bool force = false}) async {
    final code = store.accountCode;
    if (code == null || !store.opt('cloud.consent', false)) return false;
    final secs = sections(store);
    final prefs = store.backupPrefs(secs);
    final plain = {for (final e in prefs.entries) if (!isSensitiveKey(e.key)) e.key: e.value};
    final secret = {for (final e in prefs.entries) if (isSensitiveKey(e.key)) e.key: e.value};
    final clear = jsonEncode({'s': (secs.toList()..sort()), 'p': plain, 'x': secret});
    final sign = '${clear.length}:${clear.hashCode}';
    if (!force && sign == store.opt('cloud.backupSign', '')) return false;
    final doc = <String, dynamic>{
      'easyLessonBackup': 3,
      'at': DateTime.now().toIso8601String(),
      'from': await deviceId(store),
      'sections': (secs.toList()..sort()),
      'prefs': plain,
      if (secret.isNotEmpty) 'secret': await sealJson(secret, await CloudKeys.dek(store)),
    };
    final size = await Cloud.uploadBackup(code, jsonEncode(doc));
    await store.setOpt('cloud.backupSign', sign);
    await store.setOpt('cloud.backupAt', DateTime.now().toIso8601String());
    await store.setOpt('cloud.backupSize', size);
    if (Cloud.lastUploadAt != null) await store.setOpt('cloud.seenAt', Cloud.lastUploadAt);
    await store.setOpt('ach.cloudBackup', true);
    AppLog.i('cloud', 'Backup caricato: $size byte, ${secret.length} chiavi cifrate (${secs.join(', ')})');
    return true;
  }

  /// Scarica il backup, apre la parte cifrata e lo rimette sul dispositivo. Restituisce le chiavi ripristinate.
  static Future<int> restoreFromServer(AppStore store) async {
    final code = store.accountCode;
    if (code == null) throw CloudException(tr('Nessun account', 'No account'));
    final Map<String, dynamic> m;
    try {
      m = Map<String, dynamic>.from(jsonDecode(await Cloud.downloadBackup(code)) as Map);
    } on CloudException {
      rethrow;
    } catch (_) {
      throw CloudException(tr('Il backup sul server è rovinato', 'The backup on the server is damaged'));
    }
    final prefs = withoutPlainSensitive(Map<String, dynamic>.from((m['prefs'] as Map?) ?? const {}));
    if (m['secret'] != null) {
      try {
        prefs.addAll(await openJson(m['secret'], await CloudKeys.dek(store)));
      } on CryptoFailure catch (e) {
        throw CloudException(tr('Non riesco ad aprire la parte cifrata: ${e.message}', 'Can\'t open the encrypted part: ${e.message}'));
      }
    }
    final n = await store.restore(jsonEncode({'easyLessonBackup': m['easyLessonBackup'] ?? 3, 'prefs': prefs}));
    // Il ripristino porta anche i vecchi "cloud.*": si ricalcola tutto alla prossima volta.
    await store.setOpt('cloud.backupSign', null);
    return n;
  }
}

/// Cifratura dei backup e dei codici (Dart, uguale su Android, Windows e web).
///
/// Come funziona:
///  - Il CODICE e il CODICE DI RECUPERO li genera il telefono ([generateAccountCode]).
///  - Al server si manda solo il token = SHA-256("easylesson-auth-v1:" + codice) ([authToken]):
///    serve per entrare, ma non permette di risalire al codice.
///  - Le parti sensibili del backup si cifrano con una chiave casuale (DEK, AES-256-GCM).
///  - La DEK si "chiude" (avvolge) due volte: con una chiave ricavata dal codice e con una ricavata
///    dal codice di recupero (HKDF-SHA256 con un sale casuale). Il server conserva solo le DEK chiuse.
///  - Chi ha il codice (o quello di recupero) apre la DEK e quindi i dati. Il server no.
///
/// Il formato è verificato con un vettore di prova calcolato da Node.js (test/crypto_box_test.dart):
/// se cambia qualcosa qui, i backup vecchi non si aprono più.
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'i18n.dart';

/// Alfabeto dei codici: niente 0/O, 1/l/I (si confondono) e niente "-" (separa i gruppi).
const accountCodeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789@#\$€/&%!?*+=';

/// Codice nuovo: [length] caratteri a caso (circa 6 bit l'uno), a gruppi da 5: "Ab3\$k-9€xQ#-…".
String generateAccountCode({int length = 20, Random? random}) {
  final rnd = random ?? Random.secure();
  final chars = accountCodeAlphabet.runes.toList();
  final buf = StringBuffer();
  for (var i = 0; i < length; i++) {
    if (i > 0 && i % 5 == 0) buf.write('-');
    buf.writeCharCode(chars[rnd.nextInt(chars.length)]);
  }
  return buf.toString();
}

/// Toglie spazi e trattini: "Ab3\$k-9€xQ#" e "Ab3\$k9€xQ#" sono lo stesso codice.
String normalizeAccountCode(String code) => code.replaceAll(RegExp(r'[\s\-]'), '');

/// Il codice ha l'aspetto giusto? (tra 12 e 64 caratteri, senza contare spazi e trattini)
bool looksLikeAccountCode(String code) {
  final n = normalizeAccountCode(code).runes.length;
  return n >= 12 && n <= 64;
}

String _b64url(List<int> bytes) => base64Url.encode(bytes).replaceAll('=', '');

/// Il "token" che si manda al server al posto del codice (43 caratteri base64url).
Future<String> authToken(String code) async {
  final h = await Sha256().hash(utf8.encode('easylesson-auth-v1:${normalizeAccountCode(code)}'));
  return _b64url(h.bytes);
}

final _aes = AesGcm.with256bits();
final _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

List<int> _randomBytes(int n) {
  final r = Random.secure();
  return Uint8List.fromList([for (var i = 0; i < n; i++) r.nextInt(256)]);
}

/// Chiave che "chiude" la DEK, ricavata dal codice e dal sale.
Future<SecretKey> deriveKek(String code, List<int> salt) => _hkdf.deriveKey(
      secretKey: SecretKey(utf8.encode(normalizeAccountCode(code))),
      nonce: salt,
      info: utf8.encode('easylesson-kek-v1'),
    );

/// AES-256-GCM: restituisce base64(nonce 12 | testo cifrato | mac 16).
Future<String> sealBytes(List<int> clear, SecretKey key, {List<int>? nonce}) async {
  final box = await _aes.encrypt(clear, secretKey: key, nonce: nonce ?? _aes.newNonce());
  return base64.encode(box.concatenation());
}

/// Apre quello che ha chiuso [sealBytes]. Lancia [CryptoFailure] se la chiave è sbagliata.
Future<List<int>> openBytes(String sealed, SecretKey key) async {
  try {
    final box = SecretBox.fromConcatenation(base64.decode(sealed), nonceLength: 12, macLength: 16);
    return await _aes.decrypt(box, secretKey: key);
  } catch (_) {
    throw CryptoFailure('Chiave sbagliata o dati rovinati');
  }
}

class CryptoFailure implements Exception {
  CryptoFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Le chiavi come stanno sul server: la DEK chiusa con il codice e con il codice di recupero.
class KeyBundle {
  KeyBundle({required this.salt, required this.code, this.recovery});

  final String salt; // base64
  final String code; // DEK chiusa con il codice
  final String? recovery; // DEK chiusa con il codice di recupero

  Map<String, dynamic> toJson() => {'v': 1, 'salt': salt, 'code': code, if (recovery != null) 'recovery': recovery};

  static KeyBundle? fromJson(dynamic j) {
    if (j is! Map || j['v'] != 1 || j['salt'] is! String || j['code'] is! String) return null;
    return KeyBundle(salt: j['salt'] as String, code: j['code'] as String, recovery: j['recovery'] as String?);
  }

  /// Apre la DEK con il codice normale.
  Future<SecretKey> openWithCode(String accountCode) async =>
      SecretKey(await openBytes(code, await deriveKek(accountCode, base64.decode(salt))));

  /// Apre la DEK con il codice di recupero.
  Future<SecretKey> openWithRecovery(String recoveryCode) async {
    if (recovery == null) throw CryptoFailure(tr('Per questo account non c\'è un codice di recupero', 'There\'s no recovery code for this account'));
    return SecretKey(await openBytes(recovery!, await deriveKek(recoveryCode, base64.decode(salt))));
  }

  /// Stessa DEK, richiusa con un codice nuovo (dopo il recupero).
  Future<KeyBundle> withNewCode(SecretKey dek, String newCode) async => KeyBundle(
        salt: salt,
        code: await sealBytes(await dek.extractBytes(), await deriveKek(newCode, base64.decode(salt))),
        recovery: recovery,
      );

  /// Stessa DEK, richiusa con un codice di recupero nuovo.
  Future<KeyBundle> withNewRecovery(SecretKey dek, String newRecovery) async => KeyBundle(
        salt: salt,
        code: code,
        recovery: await sealBytes(await dek.extractBytes(), await deriveKek(newRecovery, base64.decode(salt))),
      );

  /// Chiavi nuove: DEK casuale chiusa con [accountCode] e [recoveryCode].
  static Future<(KeyBundle, SecretKey)> create(String accountCode, String recoveryCode) async {
    final salt = _randomBytes(16);
    final dek = _randomBytes(32);
    final bundle = KeyBundle(
      salt: base64.encode(salt),
      code: await sealBytes(dek, await deriveKek(accountCode, salt)),
      recovery: await sealBytes(dek, await deriveKek(recoveryCode, salt)),
    );
    return (bundle, SecretKey(dek));
  }
}

/// Cifra un oggetto JSON con la DEK: {"v":1,"alg":"A256GCM","data":"…"}.
Future<Map<String, dynamic>> sealJson(Map<String, dynamic> value, SecretKey dek) async =>
    {'v': 1, 'alg': 'A256GCM', 'data': await sealBytes(utf8.encode(jsonEncode(value)), dek)};

/// Apre quello che ha chiuso [sealJson].
Future<Map<String, dynamic>> openJson(dynamic sealed, SecretKey dek) async {
  if (sealed is! Map || sealed['v'] != 1 || sealed['data'] is! String) throw CryptoFailure('Formato sconosciuto');
  final clear = await openBytes(sealed['data'] as String, dek);
  return Map<String, dynamic>.from(jsonDecode(utf8.decode(clear)) as Map);
}

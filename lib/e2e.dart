/// 3.11: messaggi privati cifrati tra grandi autorizzati dalla moderazione.
///
/// Come funziona:
///  - Ogni telefono crea una coppia di chiavi X25519. La privata resta qui, nella memoria sicura del sistema
///    (flutter_secure_storage: Keystore su Android, Credential Manager su Windows, libsecret su Linux).
///    Al server va solo la pubblica (base64url, 43 caratteri).
///  - Per ogni conversazione la chiave dei messaggi è HKDF-SHA256 del segreto X25519 condiviso, con sale = le due
///    chiavi pubbliche in ordine e info = "easylesson-e2e-v1:<id conversazione>". Tutti e due la calcolano uguale.
///  - Ogni messaggio: AES-256-GCM con un nonce casuale di 12 byte; i dati aggiuntivi (AAD) sono l'id della
///    conversazione, così un messaggio non si può spostare in un'altra. Formato: "v1.<nonce>.<cifrato+tag>".
///  - Codice di sicurezza: 12 cifre ricavate dalle due chiavi pubbliche. Se i due telefoni vedono lo stesso codice,
///    nessuno (nemmeno il server) ha messo in mezzo una chiave sua.
///
/// Limite voluto: niente "forward secrecy" (come Signal): chi rubasse la chiave privata di un telefono potrebbe
/// leggere anche i messaggi vecchi che ha intercettato. I messaggi sul server durano comunque 7 giorni.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class E2e {
  E2e._();

  static final _x = X25519();
  static final _aes = AesGcm.with256bits();
  static final _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

  static String b64(List<int> b) => base64Url.encode(b).replaceAll('=', '');
  static Uint8List unb64(String s) => base64Url.decode(s.padRight((s.length + 3) ~/ 4 * 4, '='));

  /// Formato di una chiave pubblica e di un messaggio (uguale al server).
  static final keyFormat = RegExp(r'^[A-Za-z0-9_-]{43}$');
  static final textFormat = RegExp(r'^v1\.[A-Za-z0-9_-]{16}\.[A-Za-z0-9_-]{22,5600}$');

  /// Testo in chiaro più lungo che sta nel formato (4096 + 16 di tag = 5483 caratteri base64).
  static const maxBytes = 4096;

  // ---------------------------------------------------------------- chiavi

  /// Nuova coppia di chiavi: (privata, pubblica) in base64url.
  static Future<(String, String)> newKeyPair() async {
    final kp = await _x.newKeyPair();
    final priv = await kp.extractPrivateKeyBytes();
    final pub = (await kp.extractPublicKey()).bytes;
    return (b64(priv), b64(pub));
  }

  /// Chiave pubblica di una privata (per controllare quella salvata).
  static Future<String> publicOf(String priv) async {
    final kp = await _x.newKeyPairFromSeed(unb64(priv));
    return b64((await kp.extractPublicKey()).bytes);
  }

  static Future<SecretKey> _threadKey(String threadId, String myPriv, String myPub, String peerPub) async {
    final kp = await _x.newKeyPairFromSeed(unb64(myPriv));
    final shared = await _x.sharedSecretKey(keyPair: kp, remotePublicKey: SimplePublicKey(unb64(peerPub), type: KeyPairType.x25519));
    final pubs = [myPub, peerPub]..sort();
    return _hkdf.deriveKey(
      secretKey: shared,
      nonce: [...unb64(pubs[0]), ...unb64(pubs[1])],
      info: utf8.encode('easylesson-e2e-v1:$threadId'),
    );
  }

  // ---------------------------------------------------------------- messaggi

  static Future<String> encrypt({
    required String threadId,
    required String myPriv,
    required String myPub,
    required String peerPub,
    required String text,
  }) async {
    final key = await _threadKey(threadId, myPriv, myPub, peerPub);
    final box = await _aes.encrypt(utf8.encode(text), secretKey: key, nonce: _aes.newNonce(), aad: utf8.encode(threadId));
    return 'v1.${b64(box.nonce)}.${b64([...box.cipherText, ...box.mac.bytes])}';
  }

  /// Testo in chiaro, oppure null se non si può aprire (chiave cambiata, messaggio rovinato…).
  static Future<String?> decrypt({
    required String threadId,
    required String myPriv,
    required String myPub,
    required String peerPub,
    required String text,
  }) async {
    if (!textFormat.hasMatch(text)) return null;
    try {
      final parts = text.split('.');
      final nonce = unb64(parts[1]);
      final all = unb64(parts[2]);
      if (all.length < 16) return null;
      final key = await _threadKey(threadId, myPriv, myPub, peerPub);
      final clear = await _aes.decrypt(
        SecretBox(all.sublist(0, all.length - 16), nonce: nonce, mac: Mac(all.sublist(all.length - 16))),
        secretKey: key,
        aad: utf8.encode(threadId),
      );
      return utf8.decode(clear);
    } catch (_) {
      return null;
    }
  }

  /// 12 cifre in tre gruppi ("1234 5678 9012"), uguali sui due telefoni.
  static Future<String> safetyCode(String pubA, String pubB) async {
    final pubs = [pubA, pubB]..sort();
    final h = (await Sha256().hash(utf8.encode('easylesson-e2e-safety-v1|${pubs[0]}|${pubs[1]}'))).bytes;
    final digits = StringBuffer();
    for (var i = 0; digits.length < 12; i += 2) {
      digits.write((((h[i] << 8) | h[i + 1]) % 100).toString().padLeft(2, '0'));
    }
    final d = digits.toString();
    return '${d.substring(0, 4)} ${d.substring(4, 8)} ${d.substring(8, 12)}';
  }

  // ---------------------------------------------------------------- memoria sicura

  static const _storage = FlutterSecureStorage();

  /// Nome della chiave salvata: una per account ([account] = un'impronta dell'account, mai il codice).
  static String _name(String account) => 'e2e.priv.$account';

  /// La mia coppia di chiavi per questo account (la crea la prima volta). null = memoria sicura non disponibile.
  static Future<(String, String)?> myKeys(String account) async {
    try {
      var priv = await _storage.read(key: _name(account));
      if (priv == null) {
        final (p, _) = await newKeyPair();
        await _storage.write(key: _name(account), value: p);
        priv = p;
      }
      return (priv, await publicOf(priv));
    } catch (_) {
      return null;
    }
  }

  /// Cancella la chiave di questo account (uscita dall'account, permesso tolto).
  static Future<void> forget(String account) async {
    try {
      await _storage.delete(key: _name(account));
    } catch (_) {}
  }
}

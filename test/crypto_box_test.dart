import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:easy_lesson/crypto_box.dart';
import 'package:flutter_test/flutter_test.dart';

/// Vettore di prova calcolato con Node.js (crypto di sistema), lo stesso formato del server.
const _code = 'Ab3\$k-9€xQ#-zz/@7-aaaaa';
const _token = 'B_DkpXSwEVpbylpWEbbLEwZ-FAMLTCU8dG3GTZBloSU';
const _salt = 'AAECAwQFBgcICQoLDA0ODw==';
const _kekHex = 'd63e8ac4b2821e7f84795ded9579e3792e49819aae9996b4360f964a83a91c56';
const _wrapped = 'AQIDBAUGBwgJCgsMqk5PrAFS3pzIQMX6XcfDYyEuH8ILBvNo0zXQ0JnFbtQrIayXrFQhAjKnbOWKMlSA';
const _data = 'DQ4PEBESExQVFhcYsPT31B5ofEcyh04JDSJK/BPpRcAJmN8nHKBAbJ8XQNDKROllA5jO3jj02mM=';

String _hex(List<int> b) => b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

void main() {
  test('codice generato: 20 caratteri a gruppi da 5, solo alfabeto', () {
    final c = generateAccountCode(random: Random(1));
    expect(c.split('-').length, 4);
    expect(normalizeAccountCode(c).runes.length, 20);
    for (final r in normalizeAccountCode(c).runes) {
      expect(accountCodeAlphabet.runes.contains(r), isTrue);
    }
    expect(generateAccountCode(), isNot(generateAccountCode()));
    expect(looksLikeAccountCode(c), isTrue);
    expect(looksLikeAccountCode('corto'), isFalse);
  });

  test('token uguale a quello calcolato da Node', () async {
    expect(await authToken(_code), _token);
    expect(await authToken(_code.replaceAll('-', '')), _token);
    expect((await authToken('x')).length, 43);
  });

  test('chiave e dati uguali a Node (compatibilità del formato)', () async {
    final kek = await deriveKek(_code, base64.decode(_salt));
    expect(_hex(await kek.extractBytes()), _kekHex);
    final dek = await openBytes(_wrapped, kek);
    expect(dek, [for (var i = 32; i < 64; i++) i]);
    final clear = await openBytes(_data, SecretKey(dek));
    expect(utf8.decode(clear), '{"el.username":"Andrea €"}');
  });

  test('chiavi: apri con codice, con recupero, dopo il recupero con il codice nuovo', () async {
    const code = 'Codice-Primo-12345-abcde';
    const rec = 'Recup-Ero€€-12345-zzzzz';
    final (bundle, dek) = await KeyBundle.create(code, rec);
    final secret = await sealJson({'el.grades': '[8,9]'}, dek);

    final viaCode = await bundle.openWithCode(code);
    expect(await openJson(secret, viaCode), {'el.grades': '[8,9]'});
    final viaRec = await bundle.openWithRecovery(rec);
    expect(await openJson(secret, viaRec), {'el.grades': '[8,9]'});

    await expectLater(bundle.openWithCode('Codice-Sbagliato-0000'), throwsA(isA<CryptoFailure>()));

    // Recupero: codice nuovo, stessa DEK
    const nuovo = 'Nuovo-Codice-99999-qqqqq';
    final b2 = KeyBundle.fromJson(jsonDecode(jsonEncode((await bundle.withNewCode(viaRec, nuovo)).toJson())))!;
    expect(await openJson(secret, await b2.openWithCode(nuovo)), {'el.grades': '[8,9]'});
    expect(await openJson(secret, await b2.openWithRecovery(rec)), {'el.grades': '[8,9]'});
    await expectLater(b2.openWithCode(code), throwsA(isA<CryptoFailure>()));

    // Recupero nuovo
    final b3 = await b2.withNewRecovery(viaRec, 'Altro-Recupero-77777');
    expect(await openJson(secret, await b3.openWithRecovery('Altro-Recupero-77777')), {'el.grades': '[8,9]'});
  });

  test('JSON delle chiavi', () {
    expect(KeyBundle.fromJson({'v': 2}), isNull);
    expect(KeyBundle.fromJson('boh'), isNull);
    final b = KeyBundle(salt: 'cw==', code: 'Yw==');
    expect(KeyBundle.fromJson(b.toJson())!.recovery, isNull);
  });
}

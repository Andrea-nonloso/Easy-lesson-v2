import 'package:easy_lesson/e2e.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cifrati: Anna cifra, Bruno legge; formato uguale a quello che accetta il server', () async {
    final (aPriv, aPub) = await E2e.newKeyPair();
    final (bPriv, bPub) = await E2e.newKeyPair();
    expect(E2e.keyFormat.hasMatch(aPub), isTrue);
    expect(await E2e.publicOf(aPriv), aPub);

    const tid = '0123456789abcdef';
    final box = await E2e.encrypt(threadId: tid, myPriv: aPriv, myPub: aPub, peerPub: bPub, text: 'ciao Bruno, è segreto 🤫');
    expect(E2e.textFormat.hasMatch(box), isTrue);
    expect(box.contains('Bruno'), isFalse);
    expect(await E2e.decrypt(threadId: tid, myPriv: bPriv, myPub: bPub, peerPub: aPub, text: box), 'ciao Bruno, è segreto 🤫');
    // Anna rilegge il suo messaggio con la stessa chiave
    expect(await E2e.decrypt(threadId: tid, myPriv: aPriv, myPub: aPub, peerPub: bPub, text: box), 'ciao Bruno, è segreto 🤫');
  });

  test('cifrati: altra conversazione, altra chiave o messaggio toccato = non si apre', () async {
    final (aPriv, aPub) = await E2e.newKeyPair();
    final (bPriv, bPub) = await E2e.newKeyPair();
    final (cPriv, cPub) = await E2e.newKeyPair();
    const tid = '0123456789abcdef';
    final box = await E2e.encrypt(threadId: tid, myPriv: aPriv, myPub: aPub, peerPub: bPub, text: 'ciao');
    expect(await E2e.decrypt(threadId: 'fedcba9876543210', myPriv: bPriv, myPub: bPub, peerPub: aPub, text: box), isNull);
    expect(await E2e.decrypt(threadId: tid, myPriv: cPriv, myPub: cPub, peerPub: aPub, text: box), isNull);
    final last = box[box.length - 1] == 'A' ? 'B' : 'A';
    expect(await E2e.decrypt(threadId: tid, myPriv: bPriv, myPub: bPub, peerPub: aPub, text: box.substring(0, box.length - 1) + last), isNull);
    expect(await E2e.decrypt(threadId: tid, myPriv: bPriv, myPub: bPub, peerPub: aPub, text: 'in chiaro'), isNull);
  });

  test('cifrati: un messaggio lungo 1000 caratteri entra nel limite del server', () async {
    final (aPriv, aPub) = await E2e.newKeyPair();
    final (_, bPub) = await E2e.newKeyPair();
    final box = await E2e.encrypt(threadId: '0123456789abcdef', myPriv: aPriv, myPub: aPub, peerPub: bPub, text: '😀' * 1000);
    expect(E2e.textFormat.hasMatch(box), isTrue);
    // Il massimo che l'app lascia passare (maxBytes) sta ancora nel formato del server.
    final full = await E2e.encrypt(threadId: '0123456789abcdef', myPriv: aPriv, myPub: aPub, peerPub: bPub, text: 'a' * E2e.maxBytes);
    expect(E2e.textFormat.hasMatch(full), isTrue);
  });

  test('codice di sicurezza: 12 cifre, uguale per tutti e due, diverso con un\'altra chiave', () async {
    final (_, aPub) = await E2e.newKeyPair();
    final (_, bPub) = await E2e.newKeyPair();
    final (_, cPub) = await E2e.newKeyPair();
    final ab = await E2e.safetyCode(aPub, bPub);
    expect(ab, matches(RegExp(r'^\d{4} \d{4} \d{4}$')));
    expect(await E2e.safetyCode(bPub, aPub), ab);
    expect(await E2e.safetyCode(aPub, cPub), isNot(ab));
  });
}

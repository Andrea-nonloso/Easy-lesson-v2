import 'package:easy_lesson/flashcards.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime(2026, 11, 12);

  test('sapere una carta la fa salire di scatola', () {
    final c = FlashCard(id: '1', front: 'go', back: 'went', due: today);
    reviewCard(c, knew: true, today: today);
    expect(c.box, 1);
    expect(c.due, DateTime(2026, 11, 13));
    reviewCard(c, knew: true, today: DateTime(2026, 11, 13));
    expect(c.box, 2);
    expect(c.due, DateTime(2026, 11, 16));
    expect(c.seen, 2);
    expect(c.right, 2);
  });

  test('sbagliare la riporta alla scatola 0, da rivedere oggi', () {
    final c = FlashCard(id: '1', front: 'a', back: 'b', box: 4, due: today);
    reviewCard(c, knew: false, today: today);
    expect(c.box, 0);
    expect(c.isDue(today), isTrue);
    expect(c.right, 0);
  });

  test('la scatola non supera il massimo', () {
    final c = FlashCard(id: '1', front: 'a', back: 'b', box: maxBox, due: today);
    reviewCard(c, knew: true, today: today);
    expect(c.box, maxBox);
    expect(c.due, today.add(const Duration(days: 30)));
  });

  test('parseCards legge i separatori e salta le righe senza', () {
    final r = parseCards('go ; went\nbe - was/were\nH2O = acqua\nsenza separatore\n\nx\ty');
    expect(r, [('go', 'went'), ('be', 'was/were'), ('H2O', 'acqua'), ('x', 'y')]);
  });

  test('parseCards non spezza le parole col trattino', () {
    expect(parseCards('well-known ; famoso'), [('well-known', 'famoso')]);
  });

  test('JSON andata e ritorno', () {
    final d = Deck(id: 'd', name: 'Inglese', subject: 'INGLESE', emoji: '🇬🇧', cards: [
      FlashCard(id: 'c', front: 'go', back: 'went', box: 3, due: today, seen: 5, right: 4),
    ]);
    final back = Deck.fromJson(d.toJson())!;
    expect(back.name, 'Inglese');
    expect(back.emoji, '🇬🇧');
    final c = back.cards.single;
    expect((c.front, c.back, c.box, c.due, c.seen, c.right), ('go', 'went', 3, today, 5, 4));
  });

  test('dati rovinati non rompono niente', () {
    expect(Deck.fromJson('x'), isNull);
    expect(Deck.fromJson({'id': 'd', 'n': 'n', 'c': [1, {'id': 'x'}]})!.cards, isEmpty);
    expect(FlashCard.fromJson({'id': 'c', 'f': 'a', 'b': 'b', 'x': 99})!.box, maxBox);
  });
}

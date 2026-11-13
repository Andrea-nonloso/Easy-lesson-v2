import 'agenda.dart' show dateOnly;
import 'progress.dart' show isoDay;
import 'store.dart';

/// Flashcard con ripasso a intervalli (3.9), metodo Leitner a 6 scatole.
///
/// Ogni carta sta in una scatola (0-5). Se la sai sale di una scatola e torna dopo più giorni; se la sbagli torna
/// nella scatola 0 e la rivedi oggi stesso. Tutto resta sul dispositivo (documento "el.flashcards", nel backup cifrato).

/// Giorni di attesa per scatola: 0 = oggi, poi 1, 3, 7, 14, 30.
const leitnerDays = [0, 1, 3, 7, 14, 30];
const maxBox = 5;

/// Carte per mazzo e mazzi in tutto: bastano e tengono piccola la memoria.
const maxCardsPerDeck = 500;
const maxDecks = 60;
const maxSideLength = 300;

class FlashCard {
  FlashCard({required this.id, required this.front, required this.back, this.box = 0, DateTime? due, this.seen = 0, this.right = 0})
      : due = dateOnly(due ?? DateTime.now());

  final String id;
  String front;
  String back;
  int box;
  DateTime due;

  /// Volte che l'hai ripassata / che l'hai saputa.
  int seen;
  int right;

  bool get mastered => box >= 4;
  bool isDue(DateTime today) => !due.isAfter(dateOnly(today));

  Map<String, dynamic> toJson() => {'id': id, 'f': front, 'b': back, 'x': box, 'd': isoDay(due), 's': seen, 'r': right};

  static FlashCard? fromJson(Object? j) {
    if (j is! Map || j['id'] is! String || j['f'] is! String || j['b'] is! String) return null;
    final box = j['x'];
    return FlashCard(
      id: j['id'] as String,
      front: _clip(j['f'] as String),
      back: _clip(j['b'] as String),
      box: box is int ? box.clamp(0, maxBox) : 0,
      due: DateTime.tryParse('${j['d']}'),
      seen: j['s'] is int ? j['s'] as int : 0,
      right: j['r'] is int ? j['r'] as int : 0,
    );
  }
}

class Deck {
  Deck({required this.id, required this.name, this.subject = '', this.emoji = '🃏', List<FlashCard>? cards}) : cards = cards ?? [];

  final String id;
  String name;
  String subject;
  String emoji;
  final List<FlashCard> cards;

  List<FlashCard> dueCards(DateTime today) => [for (final c in cards) if (c.isDue(today)) c];
  int get masteredCount => cards.where((c) => c.mastered).length;

  Map<String, dynamic> toJson() => {'id': id, 'n': name, 's': subject, 'e': emoji, 'c': [for (final c in cards) c.toJson()]};

  static Deck? fromJson(Object? j) {
    if (j is! Map || j['id'] is! String || j['n'] is! String) return null;
    return Deck(
      id: j['id'] as String,
      name: _clip(j['n'] as String, 60),
      subject: j['s'] is String ? j['s'] as String : '',
      emoji: j['e'] is String && (j['e'] as String).isNotEmpty ? j['e'] as String : '🃏',
      cards: [
        for (final c in (j['c'] is List ? j['c'] as List : const []).take(maxCardsPerDeck))
          if (FlashCard.fromJson(c) case final card?) card,
      ],
    );
  }
}

String _clip(String s, [int max = maxSideLength]) => s.length > max ? s.substring(0, max) : s;

/// Risposta a una carta: aggiorna scatola e prossimo ripasso.
void reviewCard(FlashCard c, {required bool knew, DateTime? today}) {
  final t = dateOnly(today ?? DateTime.now());
  c.seen++;
  if (knew) {
    c.right++;
    c.box = (c.box + 1).clamp(0, maxBox);
    c.due = t.add(Duration(days: leitnerDays[c.box]));
  } else {
    c.box = 0;
    c.due = t;
  }
}

/// Legge carte incollate, una per riga: "domanda ; risposta" (vanno bene anche " - ", tab e " = ").
/// Le righe senza separatore si saltano.
List<(String, String)> parseCards(String text) {
  final out = <(String, String)>[];
  for (final raw in text.split(RegExp(r'\r?\n'))) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    final m = RegExp(r'^(.+?)\s*(?:;|\t| = | - | – )\s*(.+)$').firstMatch(line);
    if (m == null) continue;
    final f = m.group(1)!.trim();
    final b = m.group(2)!.trim();
    if (f.isNotEmpty && b.isNotEmpty) out.add((_clip(f), _clip(b)));
  }
  return out;
}

/// Carica e salva i mazzi nello store.
class Flashcards {
  Flashcards._();

  static List<Deck> decks(AppStore s) {
    final raw = s.doc('flashcards');
    return [
      for (final d in (raw is List ? raw : const []).take(maxDecks))
        if (Deck.fromJson(d) case final deck?) deck,
    ];
  }

  static Future<void> save(AppStore s, List<Deck> decks) => s.setDoc('flashcards', [for (final d in decks) d.toJson()]);

  static int dueCount(AppStore s, [DateTime? today]) {
    final t = today ?? DateTime.now();
    return decks(s).fold(0, (n, d) => n + d.dueCards(t).length);
  }

  static String newId() => '${DateTime.now().microsecondsSinceEpoch}';
}

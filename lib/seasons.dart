import 'i18n.dart';

/// Eventi stagionali (3.9): per qualche giorno l'anno il negozio ha oggetti a tempo e c'è una missione a tema.
/// Tutto dipende solo dalla data, quindi è uguale per tutti e funziona offline.

class Season {
  const Season(this.id, this.emoji, this.it, this.en, this.from, this.to);
  final String id;
  final String emoji;
  final String it;
  final String en;

  /// (mese, giorno) di inizio e fine, compresi. Se [to] viene prima di [from] l'evento passa il capodanno.
  final (int, int) from;
  final (int, int) to;

  String get name => tr(it, en);

  bool isActive(DateTime now) {
    final d = now.month * 100 + now.day;
    final a = from.$1 * 100 + from.$2;
    final b = to.$1 * 100 + to.$2;
    return a <= b ? d >= a && d <= b : d >= a || d <= b;
  }

  /// Ultimo giorno dell'evento in corso (per "fino al …").
  DateTime endFor(DateTime now) {
    final crossesYear = (to.$1 * 100 + to.$2) < (from.$1 * 100 + from.$2);
    final year = crossesYear && now.month >= from.$1 ? now.year + 1 : now.year;
    return DateTime(year, to.$1, to.$2);
  }
}

const seasons = [
  Season('halloween', '🎃', 'Halloween', 'Halloween', (10, 20), (11, 5)),
  Season('natale', '🎄', 'Natale', 'Christmas', (12, 1), (1, 6)),
  Season('sanvalentino', '💘', 'San Valentino', 'Valentine\'s Day', (2, 7), (2, 16)),
  Season('finescuola', '🏖️', 'Fine della scuola', 'End of school', (5, 25), (6, 15)),
];

Season? activeSeason(DateTime now) {
  for (final s in seasons) {
    if (s.isActive(now)) return s;
  }
  return null;
}

Season? seasonById(String? id) {
  for (final s in seasons) {
    if (s.id == id) return s;
  }
  return null;
}

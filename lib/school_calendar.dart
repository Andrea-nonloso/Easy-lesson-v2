import 'i18n.dart';
/// Calendario scolastico: inizio e fine delle lezioni, vacanze e festività.
/// Dart puro (riusabile dal bot). Dati della Regione Lazio; i giorni decisi dalla
/// scuola (ponti, sospensioni) si aggiungono dalle impostazioni.
class Closure {
  const Closure(this.from, this.to, this.name, [this.emoji = '🎉']);

  final DateTime from;
  final DateTime to; // compreso
  final String name;
  final String emoji;

  bool contains(DateTime d) {
    final x = DateTime(d.year, d.month, d.day);
    return !x.isBefore(from) && !x.isAfter(to);
  }

  /// Giorno in cui si torna a scuola (il giorno dopo la fine, salvo weekend).
  DateTime get backOn {
    var d = DateTime(to.year, to.month, to.day + 1);
    while (d.weekday > 5) {
      d = DateTime(d.year, d.month, d.day + 1);
    }
    return d;
  }

  Map<String, dynamic> toJson() => {
        'from': '${from.year}-${from.month}-${from.day}',
        'to': '${to.year}-${to.month}-${to.day}',
        'name': name,
      };

  static Closure? fromJson(dynamic j) {
    try {
      final m = Map<String, dynamic>.from(j as Map);
      DateTime p(String s) {
        final v = s.split('-').map(int.parse).toList();
        return DateTime(v[0], v[1], v[2]);
      }

      return Closure(p(m['from'] as String), p(m['to'] as String), m['name'] as String? ?? tr('Niente scuola', 'No school'), '📌');
    } catch (_) {
      return null;
    }
  }
}

class SchoolYear {
  const SchoolYear(this.label, this.start, this.end, this.closures);

  final String label;
  final DateTime start;
  final DateTime end; // ultimo giorno di lezione
  final List<Closure> closures;
}

DateTime _d(int y, int m, int d) => DateTime(y, m, d);

/// Giorni tra due date (senza sorprese con l'ora legale).
int daysBetween(DateTime a, DateTime b) =>
    DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

/// Calendari noti. Ogni anno se ne aggiunge uno (delibera della Regione Lazio).
List<SchoolYear> get schoolYears => <SchoolYear>[
  SchoolYear('2025/26', _d(2025, 9, 15), _d(2026, 6, 8), [
    Closure(_d(2025, 11, 1), _d(2025, 11, 1), 'Ognissanti', '🕯️'),
    Closure(_d(2025, 12, 8), _d(2025, 12, 8), 'Immacolata', '✨'),
    Closure(_d(2025, 12, 23), _d(2026, 1, 6), tr('Vacanze di Natale', 'Christmas holidays'), '🎄'),
    Closure(_d(2026, 4, 2), _d(2026, 4, 7), tr('Vacanze di Pasqua', 'Easter holidays'), '🐣'),
    Closure(_d(2026, 4, 25), _d(2026, 4, 25), tr('Festa della Liberazione', 'Liberation Day'), '🇮🇹'),
    Closure(_d(2026, 5, 1), _d(2026, 5, 1), tr('Festa dei lavoratori', 'Labour Day'), '🛠️'),
    Closure(_d(2026, 6, 2), _d(2026, 6, 2), tr('Festa della Repubblica', 'Republic Day'), '🇮🇹'),
  ]),
  SchoolYear('2026/27', _d(2026, 9, 15), _d(2027, 6, 8), [
    Closure(_d(2026, 9, 29), _d(2026, 9, 29), tr('San Michele, patrono di Aprilia', 'St. Michael, patron of Aprilia'), '⛪'),
    Closure(_d(2026, 11, 1), _d(2026, 11, 1), 'Ognissanti', '🕯️'),
    Closure(_d(2026, 12, 8), _d(2026, 12, 8), 'Immacolata', '✨'),
    Closure(_d(2026, 12, 23), _d(2027, 1, 6), tr('Vacanze di Natale', 'Christmas holidays'), '🎄'),
    Closure(_d(2027, 3, 25), _d(2027, 3, 30), tr('Vacanze di Pasqua', 'Easter holidays'), '🐣'),
    Closure(_d(2027, 4, 25), _d(2027, 4, 25), tr('Festa della Liberazione', 'Liberation Day'), '🇮🇹'),
    Closure(_d(2027, 5, 1), _d(2027, 5, 1), tr('Festa dei lavoratori', 'Labour Day'), '🛠️'),
    Closure(_d(2027, 6, 2), _d(2027, 6, 2), tr('Festa della Repubblica', 'Republic Day'), '🇮🇹'),
  ]),
];

/// Il calendario per una data e i giorni senza scuola aggiunti dall'utente.
class SchoolCalendar {
  SchoolCalendar([this.extra = const []]);

  final List<Closure> extra;

  SchoolYear? yearOf(DateTime d) {
    final x = DateTime(d.year, d.month, d.day);
    for (final y in schoolYears) {
      // L'anno vale dal 1° settembre al 31 agosto.
      if (!x.isBefore(DateTime(y.start.year, 9, 1)) && x.isBefore(DateTime(y.start.year + 1, 9, 1))) return y;
    }
    return null;
  }

  /// Vacanza o festa in quel giorno (null = giorno normale, anche se è weekend).
  Closure? closureOn(DateTime d) {
    for (final c in extra) {
      if (c.contains(d)) return c;
    }
    final y = yearOf(d);
    if (y == null) return null;
    final x = DateTime(d.year, d.month, d.day);
    if (x.isBefore(y.start)) {
      return Closure(DateTime(y.start.year, 6, 9), DateTime(y.start.year, y.start.month, y.start.day - 1),
          'Vacanze estive', '🏖️');
    }
    if (x.isAfter(y.end)) {
      return Closure(DateTime(y.end.year, y.end.month, y.end.day + 1), DateTime(y.end.year, 9, 14), 'Vacanze estive', '🏖️');
    }
    for (final c in y.closures) {
      if (c.contains(d)) return c;
    }
    return null;
  }

  /// Giorno di lezione: non è weekend (oltre [daysPerWeek]) e non è vacanza.
  bool isSchoolDay(DateTime d, {int daysPerWeek = 5}) => d.weekday <= daysPerWeek && closureOn(d) == null;

  /// Prossimi eventi da conto alla rovescia: vacanze, feste e fine della scuola.
  List<({String name, String emoji, int days})> countdowns(DateTime now, {int max = 3}) {
    final today = DateTime(now.year, now.month, now.day);
    final y = yearOf(today);
    final out = <({String name, String emoji, int days})>[];
    final all = [...extra, ...?y?.closures]..sort((a, b) => a.from.compareTo(b.from));
    for (final c in all) {
      final days = daysBetween(today, c.from);
      if (days > 0) out.add((name: c.name, emoji: c.emoji, days: days));
    }
    if (y != null) {
      final toEnd = daysBetween(today, y.end);
      if (toEnd > 0) out.add((name: tr('Fine della scuola', 'End of school'), emoji: '🏁', days: toEnd));
      if (today.isAfter(y.end)) {
        final next = schoolYears.where((s) => s.start.isAfter(today)).toList();
        if (next.isNotEmpty) {
          out.add((name: tr('Primo giorno di scuola', 'First day of school'), emoji: '🎒', days: daysBetween(today, next.first.start)));
        }
      }
    }
    out.sort((a, b) => a.days.compareTo(b.days));
    // Una festa singola vicina e la fine della scuola sono sempre utili; niente doppioni.
    final seen = <String>{};
    return out.where((e) => seen.add(e.name)).take(max).toList();
  }
}

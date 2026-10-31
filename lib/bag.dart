import 'models.dart';

/// Regola dello zaino: se nell'orario del giorno c'è [match] (nella materia o
/// nel laboratorio), porta [item].
class BagRule {
  const BagRule(this.match, this.item);

  final String match;
  final String item;

  Map<String, String> toJson() => {'match': match, 'item': item};

  static BagRule? fromJson(dynamic j) {
    try {
      final m = Map<String, dynamic>.from(j as Map);
      final match = (m['match'] as String).trim();
      final item = (m['item'] as String).trim();
      return match.isEmpty || item.isEmpty ? null : BagRule(match, item);
    } catch (_) {
      return null;
    }
  }
}

const defaultBagRules = <BagRule>[
  BagRule('chim', 'Camice 🥼'),
  BagRule('microb', 'Camice 🥼'),
  BagRule('bioc', 'Camice 🥼'),
  BagRule('scienze motorie', 'Tuta e scarpe da ginnastica 👟'),
  BagRule('palestra', 'Tuta e scarpe da ginnastica 👟'),
  BagRule('matematica', 'Calcolatrice 🧮'),
  BagRule('fisica', 'Calcolatrice 🧮'),
  BagRule('disegno', 'Squadre, compasso e matite ✏️'),
  BagRule('costruzioni', 'Squadre, compasso e matite ✏️'),
  BagRule('ttrg', 'Squadre, compasso e matite ✏️'),
];

/// Materie del giorno (senza ripetizioni, nell'ordine delle ore).
List<String> subjectsOfDay(DaySchedule day) {
  final out = <String>[];
  for (final l in day.lessons) {
    if (!l.isEmpty && !out.contains(l.title)) out.add(l.title);
  }
  return out;
}

/// Cose da portare per quel giorno secondo le regole (senza ripetizioni).
List<String> bagItems(DaySchedule day, List<BagRule> rules) {
  final out = <String>[];
  for (final l in day.lessons) {
    if (l.isEmpty) continue;
    final text = ' ${[l.rawTitle, l.title, l.lab].join(' ').toLowerCase()} ';
    for (final r in rules) {
      if (text.contains(r.match.toLowerCase()) && !out.contains(r.item)) out.add(r.item);
    }
  }
  return out;
}

import 'agenda.dart' show dateOnly;
import 'i18n.dart';
import 'progress.dart' show isoDay;
import 'store.dart';

/// Abitudini quotidiane e umore (3.9). Tutto solo sul telefono, nei documenti "el.habits" e "el.mood"
/// (finiscono nella sezione cifrata "scuola" del backup), mai al server.

const maxHabits = 12;

/// Giorni tenuti in memoria per abitudini e umore (poco più di un anno).
const keepDays = 400;

class Habit {
  Habit({required this.id, required this.name, required this.emoji, Set<String>? days}) : days = days ?? {};
  final String id;
  String name;
  String emoji;

  /// Giorni fatti, come "2026-11-12".
  final Set<String> days;

  bool doneOn(DateTime d) => days.contains(isoDay(d));

  /// Serie attuale: giorni di fila fino a oggi (o fino a ieri, se oggi non è ancora fatta).
  int streak(DateTime today) {
    var d = dateOnly(today);
    if (!doneOn(d)) d = d.subtract(const Duration(days: 1));
    var n = 0;
    while (doneOn(d)) {
      n++;
      d = d.subtract(const Duration(days: 1));
    }
    return n;
  }

  /// Serie più lunga di sempre.
  int get bestStreak {
    final sorted = [for (final s in days) DateTime.tryParse(s)].whereType<DateTime>().map(dateOnly).toList()..sort();
    var best = 0, cur = 0;
    DateTime? prev;
    for (final d in sorted) {
      cur = prev != null && d.difference(prev).inDays == 1 ? cur + 1 : 1;
      if (cur > best) best = cur;
      prev = d;
    }
    return best;
  }

  Map<String, dynamic> toJson() => {'id': id, 'n': name, 'e': emoji, 'd': days.toList()..sort()};

  static Habit? fromJson(Object? j) {
    if (j is! Map || j['id'] is! String || j['n'] is! String) return null;
    final raw = j['d'] is List ? j['d'] as List : const [];
    final days = [for (final x in raw) if (x is String && x.length == 10) x]..sort();
    return Habit(
      id: j['id'] as String,
      name: (j['n'] as String).length > 40 ? (j['n'] as String).substring(0, 40) : j['n'] as String,
      emoji: j['e'] is String && (j['e'] as String).isNotEmpty ? j['e'] as String : '✅',
      days: days.skip(days.length > keepDays ? days.length - keepDays : 0).toSet(),
    );
  }
}

/// Abitudini già pronte (emoji, it, en).
List<(String, String)> get habitPresets => [
      ('😴', tr('Dormire 8 ore', 'Sleep 8 hours')),
      ('💧', tr('Bere 8 bicchieri d\'acqua', 'Drink 8 glasses of water')),
      ('📖', tr('Leggere 20 minuti', 'Read for 20 minutes')),
      ('🏃', tr('Fare sport', 'Exercise')),
      ('📵', tr('Niente telefono a letto', 'No phone in bed')),
      ('🎒', tr('Preparare lo zaino la sera', 'Pack the bag the night before')),
      ('🍎', tr('Mangiare frutta', 'Eat fruit')),
      ('🧘', tr('5 minuti di respiro', '5 minutes of breathing')),
      ('🇬🇧', tr('10 minuti di inglese', '10 minutes of English')),
      ('🛏️', tr('Rifare il letto', 'Make the bed')),
    ];

class Habits {
  Habits._();

  static List<Habit> all(AppStore s) {
    final raw = s.doc('habits');
    return [
      for (final h in (raw is List ? raw : const []).take(maxHabits))
        if (Habit.fromJson(h) case final habit?) habit,
    ];
  }

  static Future<void> save(AppStore s, List<Habit> list) => s.setDoc('habits', [for (final h in list) h.toJson()]);

  /// Quante abitudini sono fatte oggi / quante sono.
  static (int, int) today(AppStore s, [DateTime? now]) {
    final list = all(s);
    final t = now ?? DateTime.now();
    return (list.where((h) => h.doneOn(t)).length, list.length);
  }
}

// ---------------------------------------------------------------------------- umore

class MoodEntry {
  const MoodEntry(this.mood, this.stress);

  /// 1 (malissimo) … 5 (benissimo).
  final int mood;

  /// 1 (tranquillo) … 5 (stressatissimo).
  final int stress;
}

const moodEmojis = ['😫', '😕', '😐', '🙂', '😄'];
const stressEmojis = ['😌', '🙂', '😬', '😰', '🤯'];

class Mood {
  Mood._();

  static Map<String, MoodEntry> all(AppStore s) => parse(s.doc('mood'));

  static Map<String, MoodEntry> parse(Object? raw) {
    if (raw is! Map) return {};
    final out = <String, MoodEntry>{};
    for (final e in raw.entries) {
      final v = e.value;
      if (e.key is! String || (e.key as String).length != 10 || v is! List || v.length < 2) continue;
      final m = v[0], st = v[1];
      if (m is! int || st is! int || m < 1 || m > 5 || st < 1 || st > 5) continue;
      out[e.key as String] = MoodEntry(m, st);
    }
    return out;
  }

  static Future<void> set(AppStore s, DateTime day, MoodEntry? e) async {
    final map = all(s);
    final k = isoDay(day);
    if (e == null) {
      map.remove(k);
    } else {
      map[k] = e;
    }
    final keys = map.keys.toList()..sort();
    final keep = keys.skip(keys.length > keepDays ? keys.length - keepDays : 0);
    await s.setDoc('mood', {for (final k in keep) k: [map[k]!.mood, map[k]!.stress]});
  }
}

/// Stress medio nei giorni "di verifica" (il giorno stesso e quello prima) e negli altri giorni,
/// guardando solo i giorni segnati. null se non ci sono dati per uno dei due gruppi.
({double nearTests, double other})? stressNearTests(Map<String, MoodEntry> moods, Iterable<DateTime> testDays) {
  final near = <String>{};
  for (final d in testDays) {
    near.add(isoDay(d));
    near.add(isoDay(dateOnly(d).subtract(const Duration(days: 1))));
  }
  var a = 0, na = 0, b = 0, nb = 0;
  for (final e in moods.entries) {
    if (near.contains(e.key)) {
      a += e.value.stress;
      na++;
    } else {
      b += e.value.stress;
      nb++;
    }
  }
  if (na == 0 || nb == 0) return null;
  return (nearTests: a / na, other: b / nb);
}

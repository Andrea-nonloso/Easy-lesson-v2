/// Livelli, XP e progressi (Dart puro, testato in test/progress_test.dart).
///
/// L'XP non si salva da solo: si ricalcola sempre da obiettivi sbloccati e contatori.
/// Così unire i progressi di due telefoni (o del server) è facile: unione degli obiettivi
/// e, per ogni contatore, il valore più alto.
library;

/// Rarità di un obiettivo: decide quanta XP vale.
enum Tier {
  bronze('Bronzo', 10),
  silver('Argento', 25),
  gold('Oro', 50),
  platinum('Platino', 100);

  const Tier(this.label, this.xp);
  final String label;
  final int xp;
}

/// XP per ogni giorno diverso in cui si apre l'app.
const xpPerDay = 5;

/// XP che servono per passare dal livello [level] al successivo: 50, 75, 100, 125…
int xpToNext(int level) => 50 + 25 * (level - 1);

/// XP totali per arrivare al livello [level] (il livello 1 parte da 0).
int xpForLevel(int level) {
  if (level <= 1) return 0;
  final n = level - 1;
  return 50 * n + 25 * n * (n - 1) ~/ 2;
}

/// Livello raggiunto con [xp] punti.
int levelForXp(int xp) {
  var level = 1;
  while (xpForLevel(level + 1) <= xp) {
    level++;
  }
  return level;
}

/// Nome del livello, cambia ogni qualche livello.
String levelTitle(int level) {
  const titles = [
    (1, 'Matricola'),
    (3, 'Primino'),
    (5, 'Studente'),
    (8, 'Secchione'),
    (10, 'Rappresentante'),
    (13, 'Veterano'),
    (16, 'Maturando'),
    (20, 'Leggenda'),
    (25, 'Preside'),
    (30, 'Mito'),
    (40, 'Divinità dell\'orario'),
  ];
  var t = titles.first.$2;
  for (final (from, name) in titles) {
    if (level >= from) t = name;
  }
  return t;
}

/// Ogni 5 livelli si sale di "grado": colore del distintivo e ricompensa.
int levelRank(int level) => (level ~/ 5).clamp(0, 6);

/// Situazione del livello, pronta per l'interfaccia.
class LevelInfo {
  LevelInfo(this.xp) : level = levelForXp(xp);

  final int xp;
  final int level;

  int get from => xpForLevel(level);
  int get to => xpForLevel(level + 1);

  /// XP fatte nel livello attuale e XP che servono in tutto per il prossimo.
  int get inLevel => xp - from;
  int get needed => to - from;
  double get fraction => needed == 0 ? 0 : (inLevel / needed).clamp(0.0, 1.0);
  String get title => levelTitle(level);

  /// Prossimo livello multiplo di 5 (quello della prossima ricompensa).
  int get nextReward => (level ~/ 5 + 1) * 5;
}

/// Progressi da sincronizzare: obiettivi sbloccati + contatori (solo numeri, niente dati personali).
class ProgressData {
  ProgressData({Set<String>? achievements, Map<String, int>? counters})
      : achievements = achievements ?? <String>{},
        counters = counters ?? <String, int>{};

  final Set<String> achievements;
  final Map<String, int> counters;

  static final _id = RegExp(r'^[\w.\-]{1,40}$');

  Map<String, dynamic> toJson() => {
        'achievements': (achievements.where(_id.hasMatch).toList()..sort()),
        'counters': {
          for (final e in counters.entries)
            if (_id.hasMatch(e.key) && e.value >= 0) e.key: e.value,
        },
      };

  static ProgressData fromJson(dynamic j) {
    final out = ProgressData();
    if (j is! Map) return out;
    final a = j['achievements'];
    if (a is List) {
      for (final x in a) {
        if (x is String && _id.hasMatch(x)) out.achievements.add(x);
      }
    }
    final c = j['counters'];
    if (c is Map) {
      for (final e in c.entries) {
        final v = e.value;
        final n = v is int ? v : (v is num ? v.floor() : int.tryParse('$v'));
        if (n != null && n >= 0 && _id.hasMatch('${e.key}')) out.counters['${e.key}'] = n;
      }
    }
    return out;
  }

  /// Unione: tutti gli obiettivi e, per ogni contatore, il valore più alto.
  ProgressData merge(ProgressData other) {
    final c = {...counters};
    for (final e in other.counters.entries) {
      final old = c[e.key];
      if (old == null || e.value > old) c[e.key] = e.value;
    }
    return ProgressData(achievements: {...achievements, ...other.achievements}, counters: c);
  }

  bool sameAs(ProgressData o) =>
      achievements.length == o.achievements.length &&
      achievements.containsAll(o.achievements) &&
      counters.length == o.counters.length &&
      counters.entries.every((e) => o.counters[e.key] == e.value);
}

/// "2026-11-02"
String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Serie di giorni di fila: dato l'ultimo giorno attivo e la serie, restituisce la serie di oggi.
/// Stesso giorno = invariata; ieri = +1; più indietro (o mai) = 1.
int nextStreak(String? lastDay, int streak, DateTime now) {
  final today = dayKey(now);
  if (lastDay == today) return streak < 1 ? 1 : streak;
  final y = dayKey(DateTime(now.year, now.month, now.day - 1));
  return lastDay == y ? streak + 1 : 1;
}

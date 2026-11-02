/// Missioni giornaliere e settimanali (Dart puro, testato in test/missions_test.dart).
///
/// Ogni giorno escono 3 missioni giornaliere, ogni lunedì 3 settimanali. La scelta dipende solo
/// dalla data, quindi è uguale per tutti. Il progresso di una missione = quanto è cresciuto un
/// contatore ("metrica") da quando la missione è uscita.
library;

import 'progress.dart' show dayKey;

class MissionDef {
  const MissionDef(
    this.id,
    this.emoji,
    this.title,
    this.metric,
    this.goal,
    this.xp, {
    this.schoolDay = false,
    this.notOnWeb = false,
  });

  final String id;
  final String emoji;
  final String title;

  /// Contatore da guardare (vedi missionMetric in mission_engine.dart).
  final String metric;
  final int goal;
  final int xp;

  /// Solo nei giorni di scuola (ricreazione, prima campanella…).
  final bool schoolDay;

  /// Non sul web (foto).
  final bool notOnWeb;
}

const dailyMissions = <MissionDef>[
  MissionDef('d_prof', '🧑‍🏫', 'Apri l\'orario di un prof', 'profViews', 1, 10),
  MissionDef('d_class', '🏫', 'Guarda l\'orario di 2 classi', 'classViews', 2, 10),
  MissionDef('d_views5', '👀', 'Apri 5 orari', 'views', 5, 15),
  MissionDef('d_done', '✅', 'Segna un compito come fatto', 'agendaDone', 1, 15),
  MissionDef('d_agenda', '📝', 'Aggiungi qualcosa in agenda', 'agendaAdded', 1, 10),
  MissionDef('d_study25', '🍅', 'Studia 25 minuti con il timer', 'studied', 25, 20),
  MissionDef('d_study50', '📖', 'Studia 50 minuti con il timer', 'studied', 50, 30),
  MissionDef('d_break', '🥪', 'Apri l\'app durante la ricreazione', 'breakOpens', 1, 15, schoolDay: true),
  MissionDef('d_bell', '🔔', 'Controlla l\'orario prima della prima campanella', 'beforeBell', 1, 15, schoolDay: true),
  MissionDef('d_last', '🏁', 'Apri l\'app durante l\'ultima ora', 'lastHourOpens', 1, 15, schoolDay: true),
  MissionDef('d_sessions3', '🔁', 'Apri l\'app 3 volte oggi', 'sessions', 3, 10),
  MissionDef('d_settings', '⚙️', 'Dai un\'occhiata alle impostazioni', 'settingsOpens', 1, 10),
  MissionDef('d_theme', '🎨', 'Cambia tema', 'themeChanges', 1, 10),
  MissionDef('d_grade', '📊', 'Segna un voto', 'gradesAdded', 1, 15),
  MissionDef('d_bag', '🎒', 'Spunta qualcosa nello zaino', 'bagTicks', 1, 10),
  MissionDef('d_photo', '📸', 'Fotografa la lavagna', 'photosAdded', 1, 15, notOnWeb: true),
  MissionDef('d_countdown', '⏳', 'Aggiungi un conto alla rovescia', 'countdowns', 1, 10),
  MissionDef('d_teacher', '👩‍🏫', 'Salva un\'informazione su un prof', 'teachers', 1, 10),
];

const weeklyMissions = <MissionDef>[
  MissionDef('w_days5', '📅', 'Apri l\'app in 5 giorni diversi', 'days', 5, 75),
  MissionDef('w_study120', '⏱️', 'Studia 2 ore con il timer', 'studied', 120, 100),
  MissionDef('w_done5', '🏆', 'Segna 5 compiti come fatti', 'agendaDone', 5, 60),
  MissionDef('w_grades3', '🗃️', 'Segna 3 voti', 'gradesAdded', 3, 60),
  MissionDef('w_views30', '🔭', 'Apri 30 orari', 'views', 30, 50),
  MissionDef('w_prof15', '🕵️', 'Apri 15 volte orari di prof', 'profViews', 15, 50),
  MissionDef('w_dailies10', '🎯', 'Completa 10 missioni giornaliere', 'missionsDone', 10, 100),
  MissionDef('w_break3', '🥤', 'Apri l\'app in 3 ricreazioni', 'breakOpens', 3, 60),
];

/// Bonus quando si completano tutte e 3.
const dailyBonusXp = 25;
const weeklyBonusXp = 100;

/// Chiave della settimana: il lunedì ("2026-11-02").
String weekKey(DateTime d) => dayKey(DateTime(d.year, d.month, d.day - (d.weekday - 1)));

/// Numero "a caso" ma uguale su ogni dispositivo per lo stesso testo (FNV-1a a 32 bit).
int stableHash(String s) {
  var h = 0x811c9dc5;
  for (final c in s.codeUnits) {
    h ^= c;
    // h * 0x01000193 senza superare i 53 bit (sul web gli int sono double): 0x01000193 = 2^24 + 0x193.
    h = (((h << 24) & 0xffffffff) + h * 0x193) & 0xffffffff;
  }
  return h;
}

/// Sceglie [n] missioni dal [pool] per il periodo [seedKey]: prima quelle [forced] (eventi), poi a caso.
List<MissionDef> pickMissions(
  List<MissionDef> pool,
  String seedKey,
  int n, {
  bool Function(MissionDef m)? allowed,
  List<String> forced = const [],
}) {
  final ok = [for (final m in pool) if (allowed == null || allowed(m)) m];
  final out = <MissionDef>[
    for (final id in forced)
      for (final m in ok)
        if (m.id == id) m,
  ];
  final rest = [for (final m in ok) if (!out.contains(m)) m];
  // Mescolamento con un generatore semplice (xorshift) che dà gli stessi numeri ovunque, anche sul web.
  var x = stableHash(seedKey) | 1;
  int next(int max) {
    x ^= (x << 13) & 0xffffffff;
    x ^= x >> 17;
    x ^= (x << 5) & 0xffffffff;
    return x % max;
  }

  for (var i = rest.length - 1; i > 0; i--) {
    final j = next(i + 1);
    final t = rest[i];
    rest[i] = rest[j];
    rest[j] = t;
  }
  // Niente due missioni sulla stessa metrica nello stesso giorno.
  for (final m in rest) {
    if (out.length >= n) break;
    if (out.any((o) => o.metric == m.metric)) continue;
    out.add(m);
  }
  return out.take(n).toList();
}

/// Evento speciale (dal server): moltiplica le XP delle missioni e può imporre missioni.
class MissionEvent {
  MissionEvent({
    required this.id,
    required this.title,
    this.description = '',
    this.emoji = '🎉',
    required this.starts,
    required this.ends,
    this.multiplier = 1,
    this.daily = const [],
  });

  final String id;
  final String title;
  final String description;
  final String emoji;
  final DateTime starts;
  final DateTime ends;
  final double multiplier;
  final List<String> daily;

  bool activeAt(DateTime t) => !t.isBefore(starts) && t.isBefore(ends);

  static MissionEvent? fromJson(dynamic j) {
    if (j is! Map || j['id'] is! String || j['title'] is! String) return null;
    final s = j['starts'];
    final e = j['ends'];
    if (s is! num || e is! num) return null;
    final m = j['multiplier'];
    return MissionEvent(
      id: j['id'] as String,
      title: j['title'] as String,
      description: '${j['description'] ?? ''}',
      emoji: (j['emoji'] is String && (j['emoji'] as String).isNotEmpty) ? j['emoji'] as String : '🎉',
      starts: DateTime.fromMillisecondsSinceEpoch(s.toInt()),
      ends: DateTime.fromMillisecondsSinceEpoch(e.toInt()),
      multiplier: m is num ? m.toDouble().clamp(1.0, 5.0) : 1.0,
      daily: [
        for (final x in (j['daily'] is List ? j['daily'] as List : const []))
          if (x is String) x,
      ],
    );
  }
}

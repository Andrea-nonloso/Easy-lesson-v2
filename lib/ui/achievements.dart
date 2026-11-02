import 'package:flutter/material.dart';

import '../agenda.dart' show dateOnly;
import '../cloud.dart';
import '../models.dart';
import '../progress.dart';
import '../school_calendar.dart';
import '../school_life.dart' show Grade;
import '../store.dart';

/// Categorie degli obiettivi (per la pagina e i filtri).
const achievementCategories = [
  ('inizio', '🚀', 'Primi passi'),
  ('costanza', '🔥', 'Costanza'),
  ('orario', '🔭', 'Orario'),
  ('organizza', '🗂️', 'Organizzazione'),
  ('studio', '📚', 'Studio e voti'),
  ('stile', '🎨', 'Stile e collezione'),
  ('segreti', '🤫', 'Segreti'),
];

/// Obiettivi e medaglie. Si sbloccano da soli guardando cosa c'è nello store.
/// [secret] = non si vede cosa bisogna fare finché non si sblocca.
/// [goal]/[progress] = barra di avanzamento (es. 37/100).
class Achievement {
  const Achievement(
    this.id,
    this.emoji,
    this.title,
    this.how,
    this.check, {
    this.tier = Tier.bronze,
    this.category = 'inizio',
    this.secret = false,
    this.progress,
    this.goal,
  });
  final String id;
  final String emoji;
  final String title;
  final String how;
  final bool Function(AppStore s) check;
  final Tier tier;
  final String category;
  final bool secret;
  final int Function(AppStore s)? progress;
  final int? goal;
}

bool _flag(AppStore s, String k) => s.opt(k, false);

int _studied(AppStore s) => s.studyMinutes.values.fold(0, (a, b) => a + b);

double? _average(List<Grade> grades) {
  var sum = 0.0;
  var w = 0.0;
  for (final g in grades) {
    sum += g.value * g.weight;
    w += g.weight;
  }
  return w == 0 ? null : sum / w;
}

/// Obiettivo "a contatore": si sblocca quando [value] arriva a [goal], con la barra.
Achievement _count(
  String id,
  String emoji,
  String title,
  String how,
  int goal,
  int Function(AppStore s) value, {
  Tier tier = Tier.bronze,
  required String category,
}) =>
    Achievement(id, emoji, title, how, (s) => value(s) >= goal,
        tier: tier, category: category, progress: value, goal: goal);

/// Rimonta: dopo un voto sotto il 6, un voto da 8 in su nella stessa materia.
bool _comeback(AppStore s) {
  final byDate = [...s.grades]..sort((a, b) => a.date.compareTo(b.date));
  final low = <String>{};
  for (final g in byDate) {
    if (g.value < 6) {
      low.add(g.subject);
    } else if (g.value >= 8 && low.contains(g.subject)) {
      return true;
    }
  }
  return false;
}

int _bestStudyDay(AppStore s) => s.studyLog.values.fold(0, (a, b) => a > b ? a : b);

int _doneCount(AppStore s) => s.agenda.where((a) => a.done).length;

int _named(AppStore s) => {...nicknames.keys, ...subjectEmojis.keys}.length;

final achievements = <Achievement>[
  // ------------------------------------------------------------ primi passi
  Achievement('first', '👋', 'Benvenuto!', 'Apri Easy Lesson', (s) => s.launches >= 1),
  Achievement('mine', '🏠', 'Casa dolce casa', 'Imposta il tuo orario', (s) => s.myMainRef != null),
  Achievement('named', '😊', 'Piacere!', 'Scrivi il tuo nome per il saluto', (s) => (s.username ?? '').isNotEmpty),
  Achievement('account', '🔑', 'Chiave del forziere', 'Crea il tuo codice Easy Lesson', (s) => s.accountCode != null,
      tier: Tier.silver),
  Achievement('sync', '☁️', 'Tra le nuvole', 'Sincronizza i progressi con il server',
      (s) => s.opt('cloud.lastSync', '') != '', tier: Tier.silver),
  Achievement('cloudBackup', '🛟', 'Paracadute', 'Fai un backup online', (s) => _flag(s, 'ach.cloudBackup'),
      tier: Tier.silver),
  Achievement('backup', '💾', 'Prudente', 'Fai una copia di sicurezza', (s) => _flag(s, 'ach.backup')),
  Achievement('qr', '📲', 'Generoso', 'Condividi qualcosa con il QR', (s) => _flag(s, 'ach.qr')),
  Achievement('pdf', '📄', 'Burocrate', 'Crea il resoconto PDF', (s) => _flag(s, 'ach.pdf')),
  _count('settings20', '⚙️', 'Smanettone', 'Apri le impostazioni 20 volte', 20, (s) => s.stat('settingsOpens'),
      category: 'inizio'),

  // ------------------------------------------------------------ costanza
  _count('ten', '🔟', 'Affezionato', 'Apri l\'app 10 volte', 10, (s) => s.launches, category: 'costanza'),
  _count('fifty', '🎟️', 'Habitué', 'Apri l\'app 50 volte', 50, (s) => s.launches, tier: Tier.silver, category: 'costanza'),
  _count('hundred', '💯', 'Fan sfegatato', 'Apri l\'app 100 volte', 100, (s) => s.launches,
      tier: Tier.gold, category: 'costanza'),
  _count('fiveHundred', '🏛️', 'Monumento', 'Apri l\'app 500 volte', 500, (s) => s.launches,
      tier: Tier.platinum, category: 'costanza'),
  _count('days7', '📅', 'Una settimana insieme', 'Usa l\'app in 7 giorni diversi', 7, (s) => s.stat('days'),
      category: 'costanza'),
  _count('days30', '🗓️', 'Un mese insieme', 'Usa l\'app in 30 giorni diversi', 30, (s) => s.stat('days'),
      tier: Tier.silver, category: 'costanza'),
  _count('days100', '🏅', 'Centenario', 'Usa l\'app in 100 giorni diversi', 100, (s) => s.stat('days'),
      tier: Tier.gold, category: 'costanza'),
  _count('days200', '👑', 'Tutto l\'anno', 'Usa l\'app in 200 giorni diversi', 200, (s) => s.stat('days'),
      tier: Tier.platinum, category: 'costanza'),
  _count('streak3', '🔥', 'In fiamme', 'Apri l\'app 3 giorni di fila', 3, (s) => s.stat('bestStreak'), category: 'costanza'),
  _count('streak7', '☄️', 'Settimana di fuoco', 'Apri l\'app 7 giorni di fila', 7, (s) => s.stat('bestStreak'),
      tier: Tier.silver, category: 'costanza'),
  _count('streak30', '🌋', 'Inarrestabile', 'Apri l\'app 30 giorni di fila', 30, (s) => s.stat('bestStreak'),
      tier: Tier.gold, category: 'costanza'),
  _count('streak100', '♾️', 'Infinito', 'Apri l\'app 100 giorni di fila', 100, (s) => s.stat('bestStreak'),
      tier: Tier.platinum, category: 'costanza'),
  _count('hours4', '⏰', 'Sentinella', 'Apri l\'app in 4 ore di lezione diverse lo stesso giorno', 4,
      (s) => s.stat('hoursInDay'), tier: Tier.silver, category: 'costanza'),
  _count('hours6', '🛡️', 'Guardiano del tempo', 'Apri l\'app in 6 ore di lezione diverse lo stesso giorno', 6,
      (s) => s.stat('hoursInDay'), tier: Tier.gold, category: 'costanza'),

  // ------------------------------------------------------------ orario
  _count('views10', '👀', 'Curioso', 'Apri 10 orari', 10, (s) => s.stat('views'), category: 'orario'),
  _count('views100', '🔭', 'Osservatore', 'Apri 100 orari', 100, (s) => s.stat('views'),
      tier: Tier.silver, category: 'orario'),
  _count('views500', '🛰️', 'Satellite', 'Apri 500 orari', 500, (s) => s.stat('views'), tier: Tier.gold, category: 'orario'),
  _count('views2000', '🧿', 'Occhio di falco', 'Apri 2000 orari', 2000, (s) => s.stat('views'),
      tier: Tier.platinum, category: 'orario'),
  _count('profs5', '🧑‍🏫', 'Conosci i prof', 'Guarda l\'orario di 5 docenti diversi', 5, (s) => s.stat('profDistinct'),
      category: 'orario'),
  _count('profs20', '📇', 'Annuario', 'Guarda l\'orario di 20 docenti diversi', 20, (s) => s.stat('profDistinct'),
      tier: Tier.silver, category: 'orario'),
  _count('classes5', '🏫', 'Giro della scuola', 'Guarda l\'orario di 5 classi diverse', 5,
      (s) => s.stat('classDistinct'), category: 'orario'),
  _count('classes20', '🗺️', 'Esploratore', 'Guarda l\'orario di 20 classi diverse', 20, (s) => s.stat('classDistinct'),
      tier: Tier.silver, category: 'orario'),
  _count('stalker10', '🕵️', 'Fan del prof', 'Guarda 10 volte l\'orario dello stesso prof', 10, (s) => s.stat('profTop'),
      category: 'orario'),
  _count('stalker50', '🔎', 'Investigatore', 'Guarda 50 volte l\'orario dello stesso prof', 50, (s) => s.stat('profTop'),
      tier: Tier.silver, category: 'orario'),
  _count('stalker100', '🕶️', 'Stalker professionista', 'Guarda 100 volte l\'orario dello stesso prof', 100,
      (s) => s.stat('profTop'), tier: Tier.gold, category: 'orario'),
  _count('fav3', '⭐', 'Collezionista', 'Salva 3 orari', 3, (s) => s.favorites.length, category: 'orario'),
  _count('fav8', '🌌', 'Costellazione', 'Salva 8 orari', 8, (s) => s.favorites.length,
      tier: Tier.silver, category: 'orario'),
  Achievement('abWeek', '🔀', 'Doppia vita', 'Imposta la settimana A/B', (s) => s.altRef != null, category: 'orario'),
  Achievement('bells', '🔔', 'Campanaro', 'Correggi gli orari delle campanelle', (s) => s.customBells != null,
      category: 'orario'),
  Achievement('excel', '📗', 'Offline totale', 'Importa il file Excel dell\'orario', (s) => s.usingExcel,
      tier: Tier.silver, category: 'orario'),

  // ------------------------------------------------------------ organizzazione
  Achievement('agenda', '📝', 'Organizzato', 'Scrivi qualcosa in agenda', (s) => s.agenda.isNotEmpty,
      category: 'organizza'),
  _count('agenda10', '📒', 'Diario pieno', 'Scrivi 10 cose in agenda', 10, (s) => s.agenda.length,
      tier: Tier.silver, category: 'organizza'),
  _count('done10', '✅', 'Macchina da compiti', '10 cose fatte in agenda', 10, _doneCount,
      tier: Tier.silver, category: 'organizza'),
  _count('done50', '🏆', 'Re dei compiti', '50 cose fatte in agenda', 50, _doneCount, tier: Tier.gold, category: 'organizza'),
  _count('done150', '⚡', 'Instancabile', '150 cose fatte in agenda', 150, _doneCount,
      tier: Tier.platinum, category: 'organizza'),
  Achievement('countdown', '⏳', 'Non vedo l\'ora', 'Aggiungi un conto alla rovescia', (s) => s.countdowns.isNotEmpty,
      category: 'organizza'),
  _count('countdown5', '🎆', 'Contatutto', 'Aggiungi 5 conti alla rovescia', 5, (s) => s.countdowns.length,
      tier: Tier.silver, category: 'organizza'),
  Achievement('teacher', '👩‍🏫', 'Rubrica', 'Salva le info di un prof', (s) => s.teachers.isNotEmpty,
      category: 'organizza'),
  _count('teachers5', '👥', 'Rubrica completa', 'Salva le info di 5 prof', 5, (s) => s.teachers.length,
      tier: Tier.silver, category: 'organizza'),
  Achievement('materials', '📚', 'Bibliotecario', 'Segna libri e materiale di una materia', (s) => s.materials.isNotEmpty,
      category: 'organizza'),
  Achievement('weekly', '🔁', 'Abitudinario', 'Aggiungi un promemoria settimanale', (s) => s.weeklyItems.isNotEmpty,
      category: 'organizza'),
  Achievement('planner', '🗓️', 'Stratega', 'Attiva il piano di studio', (s) => s.opt('n.plan', false),
      category: 'organizza'),
  Achievement('closure', '🌉', 'Ponte!', 'Aggiungi un giorno senza scuola al calendario',
      (s) => s.extraClosures.isNotEmpty, category: 'organizza'),
  Achievement('bagReady', '🎒', 'Zaino pronto', 'Spunta le cose da mettere nello zaino', (s) => s.bagChecked.isNotEmpty,
      category: 'organizza'),
  Achievement('notify', '📣', 'Sempre puntuale', 'Attiva le notifiche delle lezioni', (s) => s.notifyMinutes != null,
      category: 'organizza'),

  // ------------------------------------------------------------ studio e voti
  Achievement('grade', '📊', 'Primo voto', 'Segna un voto', (s) => s.grades.isNotEmpty, category: 'studio'),
  _count('grades10', '🗃️', 'Pagellone', 'Segna 10 voti', 10, (s) => s.grades.length, tier: Tier.silver, category: 'studio'),
  _count('grades30', '🗄️', 'Archivista', 'Segna 30 voti', 30, (s) => s.grades.length, tier: Tier.gold, category: 'studio'),
  Achievement('pass', '✔️', 'Promosso', 'Prendi almeno 6', (s) => s.grades.any((g) => g.value >= 6), category: 'studio'),
  Achievement('ten10', '🌟', 'DIECI!', 'Prendi un 10', (s) => s.grades.any((g) => g.value >= 9.99),
      tier: Tier.gold, category: 'studio'),
  Achievement('comeback', '📈', 'Rimonta', 'Dopo un voto sotto il 6, prendi almeno 8 nella stessa materia', _comeback,
      tier: Tier.silver, category: 'studio'),
  Achievement('avg8', '🧠', 'Cervellone', 'Media dell\'8 con almeno 5 voti',
      (s) => s.grades.length >= 5 && (_average(s.grades) ?? 0) >= 8, tier: Tier.gold, category: 'studio'),
  Achievement('avg9', '🎓', 'Genio', 'Media del 9 con almeno 10 voti',
      (s) => s.grades.length >= 10 && (_average(s.grades) ?? 0) >= 9, tier: Tier.platinum, category: 'studio'),
  _count('study1', '⏱️', 'Concentrato', 'Studia 1 ora con il timer (minuti)', 60, _studied, category: 'studio'),
  _count('study10', '📖', 'Topo di biblioteca', 'Studia 10 ore con il timer (minuti)', 600, _studied,
      tier: Tier.silver, category: 'studio'),
  _count('study50', '🧘', 'Monaco zen', 'Studia 50 ore con il timer (minuti)', 3000, _studied,
      tier: Tier.gold, category: 'studio'),
  _count('study100', '🏔️', 'Vetta', 'Studia 100 ore con il timer (minuti)', 6000, _studied,
      tier: Tier.platinum, category: 'studio'),
  _count('studyDay', '🍅', 'Maratona', 'Studia 2 ore in un giorno con il timer (minuti)', 120, _bestStudyDay,
      tier: Tier.silver, category: 'studio'),
  Achievement('exam', '⏰', 'Sotto pressione', 'Usa la modalità verifica', (s) => _flag(s, 'ach.exam'), category: 'studio'),
  Achievement('photo', '📸', 'Fotografo', 'Fotografa la lavagna', (s) => s.photos.isNotEmpty, category: 'studio'),
  _count('photos20', '🖼️', 'Galleria', 'Salva 20 foto delle lezioni', 20, (s) => s.photos.length,
      tier: Tier.silver, category: 'studio'),
  Achievement('absence', '🤒', 'Capita a tutti', 'Segna la prima assenza', (s) => s.absences.isNotEmpty,
      category: 'studio'),
  Achievement('perfect', '🎯', 'Sempre presente', 'Nessuna assenza segnata per 30 giorni (dopo un mese di app)', (s) {
    final first = s.firstRun;
    if (first == null || DateTime.now().difference(first).inDays < 30) return false;
    final from = DateTime.now().subtract(const Duration(days: 30));
    return !s.absences.any((a) => a.date.isAfter(from) && !a.date.isAfter(DateTime.now()));
  }, tier: Tier.gold, category: 'studio'),

  // ------------------------------------------------------------ stile e collezione
  Achievement('theme', '🎨', 'Stilista', 'Crea un tema tutto tuo', (s) => s.hasCustomTheme,
      tier: Tier.silver, category: 'stile'),
  _count('themes5', '🌈', 'Camaleonte', 'Cambia tema 5 volte', 5, (s) => s.stat('themeChanges'), category: 'stile'),
  _count('themes25', '🦎', 'Trasformista', 'Cambia tema 25 volte', 25, (s) => s.stat('themeChanges'),
      tier: Tier.silver, category: 'stile'),
  Achievement('nick', '🏷️', 'Battezzatore', 'Dai un soprannome', (s) => _named(s) > 0, category: 'stile'),
  _count('nick10', '📛', 'Battezzatore seriale', 'Personalizza 10 nomi', 10, _named, tier: Tier.silver, category: 'stile'),
  Achievement('a11y', '👓', 'Su misura', 'Cambia testo o leggibilità in Accessibilità',
      (s) => s.opt('a11y.text', 100) != 100 || s.opt('a11y.font', false) || s.opt('a11y.contrast', false),
      category: 'stile'),
  Achievement('english', '🇬🇧', 'Hello!', 'Metti l\'app in inglese', (s) => s.opt('lang', 'it') == 'en',
      category: 'stile'),
  _count('level5', '🥉', 'Livello 5', 'Arriva al livello 5', 5, (s) => levelOf(s).level,
      tier: Tier.silver, category: 'stile'),
  _count('level10', '🥈', 'Livello 10', 'Arriva al livello 10', 10, (s) => levelOf(s).level,
      tier: Tier.gold, category: 'stile'),
  _count('level20', '🥇', 'Livello 20', 'Arriva al livello 20', 20, (s) => levelOf(s).level,
      tier: Tier.platinum, category: 'stile'),
  _count('collect25', '🧩', 'Metà strada', 'Sblocca 25 obiettivi', 25, (s) => unlockedIds(s).length,
      tier: Tier.silver, category: 'stile'),
  _count('collect50', '💎', 'Collezionista d\'oro', 'Sblocca 50 obiettivi', 50, (s) => unlockedIds(s).length,
      tier: Tier.gold, category: 'stile'),
  _count('collect75', '🏵️', 'Completista', 'Sblocca 75 obiettivi', 75, (s) => unlockedIds(s).length,
      tier: Tier.platinum, category: 'stile'),

  // ------------------------------------------------------------ segreti
  Achievement('dev', '🧑‍💻', 'Hacker', 'Sblocca le opzioni sviluppatore', (s) => s.devMode || _flag(s, 'ach.dev'),
      tier: Tier.silver, category: 'segreti', secret: true),
  Achievement('deepDev', '🕳️', 'Nella tana del Bianconiglio', 'Entra nel menu nascosto delle opzioni sviluppatore',
      (s) => _flag(s, 'ach.deepDev'), tier: Tier.platinum, category: 'segreti', secret: true),
  Achievement('night', '🦉', 'Gufo', 'Apri l\'app tra mezzanotte e le 5', (s) => _flag(s, 'egg.night'),
      tier: Tier.silver, category: 'segreti', secret: true),
  Achievement('early', '🐓', 'Mattiniero', 'Apri l\'app tra le 4 e le 6:30', (s) => _flag(s, 'egg.early'),
      category: 'segreti', secret: true),
  Achievement('sunday', '🛋️', 'Nostalgia della scuola', 'Apri l\'app di domenica', (s) => s.stat('sundays') >= 1,
      category: 'segreti', secret: true),
  Achievement('lastDay', '🏖️', 'Libertà!', 'Apri l\'app l\'ultimo giorno di scuola', (s) => _flag(s, 'egg.lastDay'),
      tier: Tier.gold, category: 'segreti', secret: true),
  Achievement('firstDay', '🎒', 'Si ricomincia', 'Apri l\'app il primo giorno di scuola', (s) => _flag(s, 'egg.firstDay'),
      tier: Tier.silver, category: 'segreti', secret: true),
  Achievement('xmas', '🎄', 'Panettone', 'Apri l\'app a Natale', (s) => _flag(s, 'egg.xmas'),
      tier: Tier.silver, category: 'segreti', secret: true),
  Achievement('newYear', '🥂', 'Anno nuovo, orario nuovo', 'Apri l\'app il primo gennaio', (s) => _flag(s, 'egg.newYear'),
      tier: Tier.silver, category: 'segreti', secret: true),
  Achievement('aprilFool', '🐟', 'Pesce d\'aprile', 'Apri l\'app il primo aprile', (s) => _flag(s, 'egg.april'),
      category: 'segreti', secret: true),
  Achievement('halloween', '🎃', 'Dolcetto o interrogazione', 'Apri l\'app ad Halloween', (s) => _flag(s, 'egg.halloween'),
      category: 'segreti', secret: true),
  Achievement('friday17', '🐈‍⬛', 'Sfortunato', 'Apri l\'app di venerdì 17', (s) => _flag(s, 'egg.fri17'),
      tier: Tier.silver, category: 'segreti', secret: true),
  Achievement('leaf', '🍃', 'Pollice verde', 'Tocca la foglia nelle impostazioni 50 volte', (s) => s.stat('leafTaps') >= 50,
      category: 'segreti', secret: true),
];

/// Obiettivi sbloccati.
Set<String> unlockedIds(AppStore s) => s.opt('ach.done', '').split(',').where((x) => x.isNotEmpty).toSet();

/// XP totali: obiettivi sbloccati + 5 per ogni giorno di utilizzo + bonus.
int totalXp(AppStore s) {
  final done = unlockedIds(s);
  var xp = 0;
  for (final a in achievements) {
    if (done.contains(a.id)) xp += a.tier.xp;
  }
  return xp + s.stat('days') * xpPerDay + s.stat('xpBonus');
}

LevelInfo levelOf(AppStore s) => LevelInfo(totalXp(s));

/// Controlla se ci sono obiettivi nuovi e li annuncia. Da chiamare ogni tanto (es. quando cambia lo store).
Future<void> checkAchievements(BuildContext context) async {
  final store = StoreScope.read(context);
  _eggFlags(store);
  final before = levelOf(store).level;
  final done = unlockedIds(store);
  final fresh = <Achievement>[];
  // Più giri: sbloccare obiettivi fa salire di livello, e questo può sbloccarne altri.
  for (var round = 0; round < 4; round++) {
    final now = achievements.where((a) => !done.contains(a.id) && a.check(store)).toList();
    if (now.isEmpty) break;
    done.addAll(now.map((a) => a.id));
    fresh.addAll(now);
    await store.setOpt('ach.done', done.join(','));
  }
  if (fresh.isEmpty) return;
  CloudSync.schedule(store);
  if (!context.mounted) return;
  final messenger = ScaffoldMessenger.maybeOf(context);
  // Al primo avvio non si festeggia "Benvenuto" sopra a tutto il resto.
  final show = fresh.where((a) => a.id != 'first').toList();
  if (show.length > 2) {
    messenger?.showSnackBar(SnackBar(
      content: Text('🏆 ${show.length} obiettivi sbloccati · +${show.fold(0, (a, b) => a + b.tier.xp)} XP'),
      action: SnackBarAction(label: 'Vedi', onPressed: () => openAchievements(context)),
    ));
  } else {
    for (final a in show) {
      messenger?.showSnackBar(SnackBar(
        content: Text('${a.emoji} ${a.title} · +${a.tier.xp} XP'),
        action: SnackBarAction(label: 'Vedi', onPressed: () => openAchievements(context)),
      ));
    }
  }
  final after = levelOf(store).level;
  if (after > before && before > 1 && context.mounted) await showLevelUp(context, after);
}

/// Festa per il livello nuovo.
Future<void> showLevelUp(BuildContext context, int level) => showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        icon: LevelBadge(level: level, size: 72),
        title: Text('Livello $level!'),
        content: Text(
          'Ora sei "${levelTitle(level)}".\n\n'
          '${level % 5 == 0 ? '🎁 Hai sbloccato una ricompensa: guardala in Profilo → Ricompense.' : 'Prossima ricompensa al livello ${(level ~/ 5 + 1) * 5}.'}',
          textAlign: TextAlign.center,
        ),
        actions: [FilledButton(onPressed: () => Navigator.pop(c), child: const Text('Grande!'))],
      ),
    );

/// Distintivo rotondo con il numero del livello; il colore cambia ogni 5 livelli.
class LevelBadge extends StatelessWidget {
  const LevelBadge({super.key, required this.level, this.size = 48});
  final int level;
  final double size;

  static const rankColors = [
    Color(0xFF8D6E63), // 1-4 legno
    Color(0xFFCD7F32), // 5-9 bronzo
    Color(0xFF9E9E9E), // 10-14 argento
    Color(0xFFFFB300), // 15-19 oro
    Color(0xFF26C6DA), // 20-24 platino
    Color(0xFF7C4DFF), // 25-29 diamante
    Color(0xFFE91E63), // 30+ leggenda
  ];

  @override
  Widget build(BuildContext context) {
    final c = rankColors[levelRank(level)];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color.lerp(c, Colors.white, 0.35)!, c],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [BoxShadow(color: c.withAlpha(90), blurRadius: size / 5, offset: Offset(0, size / 16))],
      ),
      child: Text(
        '$level',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: size * 0.42),
      ),
    );
  }
}

/// Barra del livello: distintivo, nome, XP.
class LevelCard extends StatelessWidget {
  const LevelCard({super.key, this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final lv = levelOf(store);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              LevelBadge(level: lv.level, size: 52),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Livello ${lv.level} · ${lv.title}',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(value: lv.fraction, minHeight: 8),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${lv.inLevel}/${lv.needed} XP · ${unlockedIds(store).length}/${achievements.length} obiettivi'
                      '${store.accountCode == null ? '' : ' · ☁️'}',
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (onTap != null) const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

void openAchievements(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AchievementsPage()));

class AchievementsPage extends StatefulWidget {
  const AchievementsPage({super.key});

  @override
  State<AchievementsPage> createState() => _AchievementsPageState();
}

class _AchievementsPageState extends State<AchievementsPage> {
  String? _category;
  bool _onlyLocked = false;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final done = unlockedIds(store);
    final list = [
      for (final a in achievements)
        if ((_category == null || a.category == _category) && (!_onlyLocked || !done.contains(a.id))) a,
    ]..sort((a, b) => (done.contains(a.id) ? 0 : 1).compareTo(done.contains(b.id) ? 0 : 1));
    return Scaffold(
      appBar: AppBar(
        title: Text('Obiettivi · ${done.length}/${achievements.length}'),
        actions: [
          IconButton(
            tooltip: _onlyLocked ? 'Mostra tutti' : 'Solo da sbloccare',
            onPressed: () => setState(() => _onlyLocked = !_onlyLocked),
            icon: Icon(_onlyLocked ? Icons.lock_rounded : Icons.lock_open_rounded),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
            sliver: SliverToBoxAdapter(child: LevelCard()),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: const Text('Tutti'),
                      selected: _category == null,
                      onSelected: (_) => setState(() => _category = null),
                    ),
                  ),
                  for (final (id, emoji, name) in achievementCategories)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text('$emoji $name '
                            '${achievements.where((a) => a.category == id && done.contains(a.id)).length}/'
                            '${achievements.where((a) => a.category == id).length}'),
                        selected: _category == id,
                        onSelected: (_) => setState(() => _category = id),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid.extent(
              maxCrossAxisExtent: 180,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.78,
              children: [
                for (final a in list) _AchievementCard(a, unlocked: done.contains(a.id), scheme: scheme, store: store),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard(this.a, {required this.unlocked, required this.scheme, required this.store});
  final Achievement a;
  final bool unlocked;
  final ColorScheme scheme;
  final AppStore store;

  static const _tierColors = {
    Tier.bronze: Color(0xFFCD7F32),
    Tier.silver: Color(0xFF9E9E9E),
    Tier.gold: Color(0xFFFFB300),
    Tier.platinum: Color(0xFF26C6DA),
  };

  @override
  Widget build(BuildContext context) {
    final hidden = a.secret && !unlocked;
    final p = a.progress == null || a.goal == null || unlocked ? null : a.progress!(store).clamp(0, a.goal!);
    return Card(
      color: unlocked ? scheme.primaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Opacity(
              opacity: unlocked ? 1 : 0.3,
              child: Text(unlocked ? a.emoji : (hidden ? '❓' : '🔒'), style: const TextStyle(fontSize: 36)),
            ),
            const SizedBox(height: 6),
            Text(hidden ? 'Segreto' : a.title,
                textAlign: TextAlign.center, maxLines: 2, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              hidden ? 'Scoprilo da solo…' : a.how,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
            ),
            const Spacer(),
            if (p != null && p > 0) ...[
              LinearProgressIndicator(value: p / a.goal!, minHeight: 4, borderRadius: BorderRadius.circular(4)),
              const SizedBox(height: 2),
              Text('$p/${a.goal}', style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
            ],
            Text(
              '${a.tier.label} · ${a.tier.xp} XP',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _tierColors[a.tier]),
            ),
          ],
        ),
      ),
    );
  }
}

/// Segna le sorprese legate al giorno e all'ora (gufo, feste, primo/ultimo giorno di scuola).
void _eggFlags(AppStore s) {
  final now = DateTime.now();
  void mark(String k) {
    if (!_flag(s, k)) s.setOpt(k, true);
  }

  if (now.hour < 5) mark('egg.night');
  if (now.month == 12 && now.day == 25) mark('egg.xmas');
  if (now.month == 1 && now.day == 1) mark('egg.newYear');
  if (now.month == 4 && now.day == 1) mark('egg.april');
  if (now.month == 10 && now.day == 31) mark('egg.halloween');
  if (now.weekday == DateTime.friday && now.day == 17) mark('egg.fri17');
  final y = s.calendar.yearOf(now);
  if (y != null) {
    if (dateOnly(now) == dateOnly(y.end)) mark('egg.lastDay');
    if (dateOnly(now) == dateOnly(y.start)) mark('egg.firstDay');
  }
}

/// Messaggio speciale per la home (sorprese di calendario), null se oggi è un giorno qualunque.
String? easterMessage(AppStore s, DateTime now) {
  final y = s.calendar.yearOf(now);
  final today = dateOnly(now);
  if (now.hour < 5) {
    return '🦉 Sono le ${TimeSlot.fmt(now.hour * 60 + now.minute)}… che ci fai sveglio? Domani hai scuola, vai a dormire!';
  }
  if (y != null && today == dateOnly(y.end)) return '🏖️ ULTIMO GIORNO DI SCUOLA! Ce l\'hai fatta, buone vacanze! 🎉';
  if (y != null && today == dateOnly(y.start)) return '🎒 Primo giorno di scuola: si ricomincia! Forza 💪';
  if (y != null) {
    final left = daysBetween(today, y.end);
    if (left > 0 && left <= 10) return '⏳ Mancano $left giorni alla fine della scuola!';
  }
  if (now.month == 12 && now.day == 25) return '🎄 Buon Natale! Oggi niente orario, solo panettone';
  if (now.month == 1 && now.day == 1) return '🎆 Buon anno! Che sia pieno di 10 (e di ponti)';
  if (now.month == 4 && now.day == 1) return '🐟 Oggi la scuola è chiusa per sempre! …pesce d\'aprile';
  if (now.month == 10 && now.day == 31) return '🎃 Dolcetto o interrogazione?';
  if (now.weekday == DateTime.friday && now.hour >= 14) return '😎 È venerdì pomeriggio: weekend in arrivo!';
  if (now.weekday == DateTime.monday && now.hour < 9) return '☕ Lunedì mattina. Coraggio.';
  return null;
}


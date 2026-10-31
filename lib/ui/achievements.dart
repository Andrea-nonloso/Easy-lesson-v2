import 'package:flutter/material.dart';

import '../agenda.dart' show dateOnly;
import '../models.dart';
import '../school_calendar.dart';
import '../store.dart';

/// Obiettivi e medaglie. Si sbloccano da soli guardando cosa c'è nello store.
class Achievement {
  const Achievement(this.id, this.emoji, this.title, this.how, this.check);
  final String id;
  final String emoji;
  final String title;
  final String how;
  final bool Function(AppStore s) check;
}

bool _flag(AppStore s, String k) => s.opt(k, false);

int _studied(AppStore s) => s.studyMinutes.values.fold(0, (a, b) => a + b);

final achievements = <Achievement>[
  Achievement('first', '👋', 'Benvenuto!', 'Apri Easy Lesson', (s) => s.launches >= 1),
  Achievement('ten', '🔟', 'Affezionato', 'Apri l\'app 10 volte', (s) => s.launches >= 10),
  Achievement('hundred', '💯', 'Fan sfegatato', 'Apri l\'app 100 volte', (s) => s.launches >= 100),
  Achievement('mine', '🏠', 'Casa dolce casa', 'Imposta il tuo orario', (s) => s.myMainRef != null),
  Achievement('agenda', '📝', 'Organizzato', 'Scrivi qualcosa in agenda', (s) => s.agenda.isNotEmpty),
  Achievement('done10', '✅', 'Macchina da compiti', '10 cose fatte in agenda',
      (s) => s.agenda.where((a) => a.done).length >= 10),
  Achievement('grade', '📊', 'Primo voto', 'Segna un voto', (s) => s.grades.isNotEmpty),
  Achievement('ten10', '🌟', 'DIECI!', 'Prendi un 10', (s) => s.grades.any((g) => g.value >= 9.99)),
  Achievement('avg8', '🧠', 'Cervellone', 'Media dell\'8 con almeno 5 voti', (s) {
    if (s.grades.length < 5) return false;
    var sum = 0.0;
    var w = 0.0;
    for (final g in s.grades) {
      sum += g.value * g.weight;
      w += g.weight;
    }
    return sum / w >= 8;
  }),
  Achievement('study1', '⏱️', 'Concentrato', 'Studia 1 ora con il timer', (s) => _studied(s) >= 60),
  Achievement('study10', '📚', 'Topo di biblioteca', 'Studia 10 ore con il timer', (s) => _studied(s) >= 600),
  Achievement('perfect', '🎯', 'Sempre presente', 'Nessuna assenza segnata per 30 giorni (dopo un mese di app)', (s) {
    final first = s.firstRun;
    if (first == null || DateTime.now().difference(first).inDays < 30) return false;
    final from = DateTime.now().subtract(const Duration(days: 30));
    return !s.absences.any((a) => a.date.isAfter(from) && !a.date.isAfter(DateTime.now()));
  }),
  Achievement('theme', '🎨', 'Stilista', 'Crea un tema tutto tuo', (s) => s.hasCustomTheme),
  Achievement('nick', '🏷️', 'Battezzatore', 'Dai un soprannome', (s) => nicknames.isNotEmpty || subjectEmojis.isNotEmpty),
  Achievement('photo', '📸', 'Fotografo', 'Fotografa la lavagna', (s) => s.photos.isNotEmpty),
  Achievement('bells', '🔔', 'Campanaro', 'Correggi gli orari delle campanelle', (s) => s.customBells != null),
  Achievement('qr', '📲', 'Generoso', 'Condividi qualcosa con il QR', (s) => _flag(s, 'ach.qr')),
  Achievement('backup', '💾', 'Prudente', 'Fai una copia di sicurezza', (s) => _flag(s, 'ach.backup')),
  Achievement('dev', '🧑‍💻', 'Hacker', 'Sblocca le opzioni sviluppatore', (s) => s.devMode || _flag(s, 'ach.dev')),
  Achievement('night', '🦉', 'Gufo', 'Apri l\'app tra mezzanotte e le 5', (s) => _flag(s, 'egg.night')),
  Achievement('lastDay', '🏖️', 'Libertà!', 'Apri l\'app l\'ultimo giorno di scuola', (s) => _flag(s, 'egg.lastDay')),
  Achievement('firstDay', '🎒', 'Si ricomincia', 'Apri l\'app il primo giorno di scuola', (s) => _flag(s, 'egg.firstDay')),
];

Set<String> unlockedIds(AppStore s) => s.opt('ach.done', '').split(',').where((x) => x.isNotEmpty).toSet();

/// Controlla se ci sono obiettivi nuovi e li annuncia. Da chiamare ogni tanto (es. quando cambia lo store).
Future<void> checkAchievements(BuildContext context) async {
  final store = StoreScope.read(context);
  _eggFlags(store);
  final done = unlockedIds(store);
  final fresh = achievements.where((a) => !done.contains(a.id) && a.check(store)).toList();
  if (fresh.isEmpty) return;
  done.addAll(fresh.map((a) => a.id));
  final messenger = ScaffoldMessenger.maybeOf(context);
  await store.setOpt('ach.done', done.join(','));
  // Al primo avvio non si festeggia "Benvenuto" sopra a tutto il resto.
  for (final a in fresh.where((a) => a.id != 'first')) {
    messenger?.showSnackBar(SnackBar(
      content: Text('${a.emoji} Obiettivo sbloccato: ${a.title}'),
      action: SnackBarAction(label: 'Vedi', onPressed: () => openAchievements(context)),
    ));
  }
}

/// Segna le sorprese legate al giorno e all'ora (gufo, primo/ultimo giorno di scuola).
void _eggFlags(AppStore s) {
  final now = DateTime.now();
  if (now.hour < 5 && !_flag(s, 'egg.night')) s.setOpt('egg.night', true);
  final y = s.calendar.yearOf(now);
  if (y != null) {
    if (dateOnly(now) == dateOnly(y.end) && !_flag(s, 'egg.lastDay')) s.setOpt('egg.lastDay', true);
    if (dateOnly(now) == dateOnly(y.start) && !_flag(s, 'egg.firstDay')) s.setOpt('egg.firstDay', true);
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

void openAchievements(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AchievementsPage()));

class AchievementsPage extends StatelessWidget {
  const AchievementsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final done = unlockedIds(store);
    final list = [...achievements]..sort((a, b) => (done.contains(a.id) ? 0 : 1).compareTo(done.contains(b.id) ? 0 : 1));
    return Scaffold(
      appBar: AppBar(title: Text('Obiettivi · ${done.length}/${achievements.length}')),
      body: GridView.extent(
        maxCrossAxisExtent: 180,
        padding: const EdgeInsets.all(16),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.9,
        children: [
          for (final a in list)
            Card(
              color: done.contains(a.id) ? scheme.primaryContainer : null,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Opacity(
                      opacity: done.contains(a.id) ? 1 : 0.25,
                      child: Text(done.contains(a.id) ? a.emoji : '🔒', style: const TextStyle(fontSize: 40)),
                    ),
                    const SizedBox(height: 8),
                    Text(a.title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(a.how, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

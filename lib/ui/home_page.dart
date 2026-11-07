import 'dart:async';

import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../agenda.dart';
import '../i18n.dart';
import '../school_extra.dart';
import 'achievements.dart';
import 'agenda_page.dart';
import 'announcement_banner.dart';
import 'bag_page.dart';
import 'fun.dart';
import 'more_pages.dart';
import 'school_shortcuts.dart';
import 'theme.dart';

/// Prima schermata dell'app (3.8 "minimal"): una cosa in evidenza.
///   - in alto: data, saluto, lente (Cerca) e segnalibro (Salvati);
///   - la card grande: la lezione di adesso o la prossima, con i conti alla rovescia delle lezioni dentro;
///   - "Dopo, oggi": le lezioni rimaste (o quelle del prossimo giorno di scuola);
///   - tre riquadri con un numero (Voti, Assenze, Agenda: si cambiano tenendo premuto) e "Altro".
/// Compiti in arrivo, zaino e conti alla rovescia delle feste si accendono da Impostazioni → Home e app.
/// Su schermi larghi le lezioni del giorno vanno in una colonna a destra.
class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.onSearch,
    required this.onOpenMine,
    required this.onOpenSaved,
  });

  final VoidCallback onSearch;
  final VoidCallback onOpenMine;
  final VoidCallback onOpenSaved;

  static const _monthsIt = [
    'gennaio', 'febbraio', 'marzo', 'aprile', 'maggio', 'giugno',
    'luglio', 'agosto', 'settembre', 'ottobre', 'novembre', 'dicembre',
  ];
  static const _monthsEn = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  static List<String> get _months => appEnglish ? _monthsEn : _monthsIt;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final now = DateTime.now();
    final peek = store.opt('home.next', true) ? _peekFor(store, now) : null;
    final todo = store.opt('home.agenda', false) ? store.agendaFrom(now, days: 7) : const <AgendaItem>[];
    final plan = store.opt('home.bag', false) ? bagPlanFor(store, now) : null;
    final showBag = plan != null && (peek == null || peek.title != tr('Oggi', 'Today'));

    final main = <Widget>[
      _header(context, store, now),
      const ScheduleChangedBanner(),
      const AnnouncementBanner(),
      const SizedBox(height: 20),
      // Si ridisegna ogni 30 s: barra dell'ora, minuti che mancano, ricreazione.
      _Every30s(builder: (now) => _TodayCard(store: store, now: now, onOpenMine: onOpenMine, onSearch: onSearch)),
      if (store.opt('home.countdown', false)) ...[const SizedBox(height: 12), _Countdowns(store: store)],
    ];
    final tiles = <Widget>[const SizedBox(height: 24), const SchoolTilesRow()];
    final side = <Widget>[
      if (peek != null && peek.items.isNotEmpty) ...[
        const SizedBox(height: 24),
        _DayPeek(peek: peek, max: peek.items.length, onOpen: onOpenMine),
      ],
      if (todo.isNotEmpty) ...[const SizedBox(height: 24), _AgendaPeek(items: todo, max: 5)],
      if (showBag) ...[const SizedBox(height: 24), _BagPeek(plan: plan)],
    ];

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) {
            // Tablet / finestra larga: le lezioni del giorno in una colonna a destra.
            if (box.maxWidth >= 840) {
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 6,
                        child: ListView(padding: const EdgeInsets.fromLTRB(28, 24, 14, 24), children: [...main, ...tiles]),
                      ),
                      Expanded(
                        flex: 5,
                        child: ListView(padding: const EdgeInsets.fromLTRB(14, 24, 28, 24), children: side),
                      ),
                    ],
                  ),
                ),
              );
            }
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
                  children: [...main, ...side, ...tiles],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Data, saluto, Cerca e Salvati.
  Widget _header(BuildContext context, AppStore store, DateTime now) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final day = dayNames[now.weekday - 1];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$day ${now.day} ${_months[now.month - 1]}',
                style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 2),
              Text(
                store.username != null ? tr('Ciao, ${store.username}', 'Hi, ${store.username}') : tr('Ciao!', 'Hi!'),
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3),
              ),
              // Sorprese del giorno (ultimo giorno di scuola, notte fonda, feste…).
              if (easterMessage(store, now) case final egg?)
                Text(
                  egg,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.primary, fontWeight: FontWeight.w600),
                ),
            ],
          ),
        ),
        _RoundIcon(icon: Icons.search_rounded, tooltip: tr('Cerca classe o docente', 'Search'), onTap: onSearch),
        const SizedBox(width: 8),
        _RoundIcon(icon: Icons.bookmark_border_rounded, tooltip: tr('Orari salvati', 'Saved'), onTap: onOpenSaved),
      ],
    );
  }
}

/// Pulsante tondo in alto (Cerca, Salvati).
class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.tooltip, required this.onTap});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: cardColor(context),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: 46, height: 46, child: Icon(icon, size: 22, semanticLabel: tooltip)),
        ),
      ),
    );
  }
}


class _PeekItem {
  const _PeekItem(this.hours, this.time, this.lesson, {this.now = false, this.note});
  final String hours;
  final String time;
  final Lesson lesson;
  final bool now;

  /// Emoji del compito / verifica di quel giorno per questa materia.
  final String? note;
}

class _Peek {
  const _Peek(this.title, this.items, this.date);
  final String title;
  final List<_PeekItem> items;
  final DateTime date;
}

/// Le lezioni rimaste oggi, oppure quelle del prossimo giorno di scuola.
_Peek? _peekFor(AppStore store, DateTime now) {
  final ref = store.myRef;
  if (ref == null) return null;
  final cached = store.cached(ref);
  if (cached == null) return null;
  final days = cached.week.days;
  if (days.isEmpty) return null;
  final slots = store.slots;
  final m = now.hour * 60 + now.minute;
  final ti = todayIndex(now, days.length);

  bool finished(int k) => k < slots.length && slots[k].end != null && slots[k].end! <= m;

  int? dayIdx;
  var title = '';
  var date = dateOnly(now);
  final cal = store.calendar;
  if (ti >= 0 && !days[ti].isEmpty && cal.closureOn(now) == null) {
    final lessons = days[ti].lessons;
    final left = [for (var k = 0; k < lessons.length; k++) if (!lessons[k].isEmpty && !finished(k)) k];
    if (left.isNotEmpty) {
      dayIdx = ti;
      title = tr('Oggi', 'Today');
    }
  }
  if (dayIdx == null) {
    // Il prossimo giorno con lezioni, saltando vacanze e feste.
    for (var off = 1; off <= 120; off++) {
      final d = DateTime(now.year, now.month, now.day + off);
      final wd = d.weekday - 1;
      if (wd < days.length && !days[wd].isEmpty && cal.closureOn(d) == null) {
        dayIdx = wd;
        title = off == 1 ? tr('Domani', 'Tomorrow') : (off < 7 ? dayNames[wd] : '${dayNames[wd]} ${d.day}/${d.month}');
        date = d;
        break;
      }
    }
  }
  if (dayIdx == null) return null;

  final today = dayIdx == ti && title == tr('Oggi', 'Today');
  final cur = today ? currentSlot(slots, now) : null;
  final lessons = days[dayIdx].lessons;
  final items = <_PeekItem>[];
  var i = 0;
  while (i < lessons.length) {
    final l = lessons[i];
    var j = i;
    while (j + 1 < lessons.length && lessons[j + 1].signature == l.signature) {
      j++;
    }
    if (!l.isEmpty && !(today && finished(j))) {
      final notes = store.agendaOn(date, l.title);
      items.add(_PeekItem(
        j > i ? '${i + 1}ª–${j + 1}ª' : '${i + 1}ª',
        i < slots.length ? slots[i].startText : '',
        l,
        now: cur != null && cur >= i && cur <= j,
        note: notes.isEmpty ? null : notes.first.emoji,
      ));
    }
    i = j + 1;
  }
  return _Peek(title, items, date);
}

/// "Zaino per domani": una riga con le cose da portare.
class _BagPeek extends StatelessWidget {
  const _BagPeek({required this.plan});

  final BagPlan plan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final store = StoreScope.of(context);
    final checked = store.bagChecked[AppStore.dayKey(plan.date)] ?? const <String>{};
    final todo = plan.checklist.where((x) => !checked.contains(x)).toList();
    final line = plan.checklist.isEmpty
        ? '📚 ${plan.subjects.join(', ')}'
        : (todo.isEmpty ? tr('✅ Zaino pronto!', '✅ Backpack ready!') : todo.join(' · '));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 34,
          child: Row(
            children: [
              Text(tr('🎒 Zaino', '🎒 Backpack'), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              Text(
                tr('per ${friendlyDate(plan.date, DateTime.now()).toLowerCase()}', 'for ${friendlyDate(plan.date, DateTime.now()).toLowerCase()}'),
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        Material(
          color: cardColor(context),
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => openBag(context),
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.centerLeft,
              child: Text(line, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium),
            ),
          ),
        ),
      ],
    );
  }
}

/// Compiti e verifiche dei prossimi giorni, in cima alla parte bassa della home.
class _AgendaPeek extends StatelessWidget {
  const _AgendaPeek({required this.items, required this.max});

  final List<AgendaItem> items;
  final int max;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final now = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 34,
          child: Row(
            children: [
              Text(tr('In arrivo', 'Coming up'), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              Text(
                '${items.length} in agenda',
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => openAgenda(context),
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 30),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                child: Text(tr('Agenda', 'Planner')),
              ),
            ],
          ),
        ),
        Material(
          color: cardColor(context),
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => openAgenda(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Column(
                children: [
                  for (final a in items.take(max))
                    SizedBox(
                      height: 36,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          children: [
                            SizedBox(width: 28, child: Text(a.emoji)),
                            SizedBox(
                              width: 74,
                              child: Text(
                                friendlyDate(a.date, now),
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: dateOnly(a.date) == dateOnly(now) ? scheme.error : scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                [a.subject, a.text].where((t) => t.isNotEmpty).join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DayPeek extends StatelessWidget {
  const _DayPeek({required this.peek, required this.max, required this.onOpen});

  final _Peek peek;
  final int max;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final shown = peek.items.take(max).toList();
    final hidden = peek.items.length - shown.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 34,
          child: Row(
            children: [
              Text(peek.title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              Text(
                hidden > 0 ? tr('+$hidden dopo', '+$hidden later') : '${peek.items.length} ${peek.items.length == 1 ? tr('lezione', 'lesson') : tr('lezioni', 'lessons')}',
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const Spacer(),
              TextButton(
                onPressed: onOpen,
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 30),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                child: Text(tr('Orario', 'Timetable')),
              ),
            ],
          ),
        ),
        Material(
          color: cardColor(context),
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Column(
              children: [
                for (final it in shown)
                  Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: it.now
                        ? BoxDecoration(color: scheme.primary.withAlpha(36), borderRadius: BorderRadius.circular(10))
                        : null,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 56,
                          child: Text(
                            it.hours,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: it.now ? scheme.primary : scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 46,
                          child: Text(it.time, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                        ),
                        Expanded(
                          child: Text(
                            it.lesson.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: it.now ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ),
                        if (it.note != null) Padding(padding: const EdgeInsets.only(left: 4), child: Text(it.note!)),
                        if (it.lesson.lab.isNotEmpty)
                          Tooltip(message: it.lesson.lab, child: Text(labInfo(it.lesson.lab).emoji)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

String _mins(int m) => m < 60 ? '$m min' : '${m ~/ 60} h${m % 60 == 0 ? '' : ' ${m % 60} min'}';

/// Conti alla rovescia delle lezioni di oggi (dentro la card grande): ricreazione e ultima campanella.
List<String> lessonCountdowns(AppStore store, DateTime now) {
  final out = <String>[];
  final m = now.hour * 60 + now.minute;
  final ref = store.myRef;
  final cached = ref == null ? null : store.cached(ref);
  if (cached == null || store.calendar.closureOn(now) != null) return out;
  final days = cached.week.days;
  final ti = todayIndex(now, days.length);
  if (ti < 0 || days[ti].isEmpty) return out;
  final slots = store.slots;
  final lessons = days[ti].lessons;
  int? lastEnd;
  int? firstStart;
  for (var k = 0; k < lessons.length && k < slots.length; k++) {
    if (lessons[k].isEmpty) continue;
    firstStart ??= slots[k].start;
    lastEnd = slots[k].end ?? lastEnd;
  }
  if (firstStart == null || lastEnd == null || m >= lastEnd) return out;
  for (final b in breaksOf(slots)) {
    if (b.afterIndex + 1 >= lessons.length) continue;
    if (m >= b.start && m < b.end) {
      out.add(tr('☕ Ricreazione: ancora ${_mins(b.end - m)}', '☕ Break: ${_mins(b.end - m)} left'));
      break;
    }
    if (b.start > m && m >= firstStart - 60) {
      out.add(tr('☕ Ricreazione tra ${_mins(b.start - m)}', '☕ Break in ${_mins(b.start - m)}'));
      break;
    }
  }
  if (m >= firstStart) {
    final h = lastEnd ~/ 60;
    final mm = (lastEnd % 60).toString().padLeft(2, '0');
    out.add(tr('🔔 Ultima campanella alle $h:$mm', '🔔 Last bell at $h:$mm'));
  }
  return out;
}

/// Ridisegna [builder] ogni 30 secondi (con l'ora giusta).
class _Every30s extends StatefulWidget {
  const _Every30s({required this.builder});
  final Widget Function(DateTime now) builder;
  @override
  State<_Every30s> createState() => _Every30sState();
}

class _Every30sState extends State<_Every30s> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(DateTime.now());
}

/// Conti alla rovescia delle feste (opzione: Impostazioni → Home e app): weekend, i tuoi, vacanze.
/// Si aggiorna da solo ogni 30 secondi.
class _Countdowns extends StatefulWidget {
  const _Countdowns({required this.store});

  final AppStore store;

  @override
  State<_Countdowns> createState() => _CountdownsState();
}

class _CountdownsState extends State<_Countdowns> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  List<String> _items(DateTime now) {
    final store = widget.store;
    final out = <String>[];
    // Weekend (lun-ven)
    final wd = now.weekday;
    if (wd <= 4) {
      final n = 6 - wd;
      out.add(tr('🎉 Weekend tra $n giorni', '🎉 Weekend in $n days'));
    } else if (wd == 5) {
      out.add(tr('🎉 Domani è sabato!', '🎉 Tomorrow is Saturday!'));
    }
    // Conti alla rovescia personali (gita, compleanno…), poi vacanze e feste.
    for (final e in store.countdowns) {
      final left = daysBetweenDates(now, e.date);
      if (left < 0 || left > 60) continue;
      out.add(left == 0 ? tr('${e.emoji} ${e.name}: è oggi!', '${e.emoji} ${e.name}: it\'s today!') : '${e.emoji} ${e.name} ${tr('tra', 'in')} $left ${left == 1 ? tr('giorno', 'day') : tr('giorni', 'days')}');
    }
    for (final c in store.calendar.countdowns(now, max: 2)) {
      out.add('${c.emoji} ${c.name} ${tr('tra', 'in')} ${c.days} ${c.days == 1 ? tr('giorno', 'day') : tr('giorni', 'days')}');
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final items = _items(DateTime.now());
    if (items.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (context, i) => const SizedBox(width: 8),
        itemBuilder: (context, i) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: cardColor(context),
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: scheme.outlineVariant.withAlpha(120)),
          ),
          child: Text(items[i], style: Theme.of(context).textTheme.labelLarge),
        ),
      ),
    );
  }
}

/// La card principale: cosa c'e' adesso (o dopo) nell'orario personale.
class _TodayCard extends StatelessWidget {
  const _TodayCard({
    required this.store,
    required this.now,
    required this.onOpenMine,
    required this.onSearch,
  });

  final AppStore store;
  final DateTime now;
  final VoidCallback onOpenMine;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ref = store.myRef;

    String overline;
    String title;
    String? subtitle;
    double? progress;
    String? footer; // "Mancano 21 min · poi Inglese"
    String? place; // laboratorio della lezione di adesso / prossima
    VoidCallback onTap = onOpenMine;

    if (ref == null) {
      overline = tr('INIZIA DA QUI', 'START HERE');
      title = tr('Imposta il tuo orario', 'Set your timetable');
      subtitle = tr('Scegli la tua classe o il tuo nome: lo troverai sempre in apertura.', 'Choose your class or your name: you\'ll always find it when you open the app.');
      onTap = onSearch;
    } else {
      final cached = store.cached(ref);
      if (cached == null) {
        overline = ref.displayName.toUpperCase();
        title = tr('Scarica l\'orario', 'Download the timetable');
        subtitle = tr('Tocca qui per scaricarlo e averlo sempre con te.', 'Tap here to download it and always have it with you.');
      } else {
        final days = cached.week.days;
        final ti = todayIndex(now, days.length);
        final closure = store.calendar.closureOn(now);
        if (closure != null && ti >= 0) {
          // Vacanza o festa in un giorno di scuola.
          final back = store.nextSchoolDay(now, daysPerWeek: days.length);
          overline = tr('OGGI NIENTE SCUOLA', 'NO SCHOOL TODAY');
          title = '${closure.emoji} ${closure.name}';
          subtitle = back == null
              ? tr('Goditi la giornata.', 'Enjoy the day.')
              : 'Si torna ${friendlyDate(back, now).toLowerCase()} (${dayNames[back.weekday - 1].toLowerCase()} ${back.day}/${back.month}).';
        } else if (ti < 0 || days[ti].isEmpty) {
          overline = tr('OGGI', 'TODAY');
          title = tr('Nessuna lezione oggi', 'No lessons today');
          subtitle = tr('Goditi la giornata.', 'Enjoy the day.');
        } else {
          final day = days[ti];
          final slots = store.slots;
          final n = day.lessons.length < slots.length ? day.lessons.length : slots.length;
          final m = now.hour * 60 + now.minute;
          final idx = currentSlot(slots, now);
          if (idx != null && idx < n) {
            final l = day.lessons[idx];
            final s = slots[idx];
            overline = tr('ADESSO · fino alle ${s.endText}', 'NOW · until ${s.endText}');
            title = l.isEmpty ? tr('Ora libera', 'Free period') : l.title;
            if (l.lab.isNotEmpty) place = l.lab;
            progress = ((m - s.start!) / (s.end! - s.start!)).clamp(0.0, 1.0).toDouble();
            if (!l.isEmpty && l.details.isNotEmpty) subtitle = l.details.join(' · ');
            // Quanto manca e cosa c'è dopo (la prima lezione diversa da questa).
            String? after;
            for (var k = idx + 1; k < n; k++) {
              final x = day.lessons[k];
              if (!x.isEmpty && x.signature != l.signature) {
                after = x.title;
                break;
              }
            }
            final left = s.end! - m;
            footer = [if (left > 0) tr('Mancano ${_mins(left)}', '${_mins(left)} left'), if (after != null) 'poi $after'].join(' · ');
            if (footer.isEmpty) footer = null;
          } else {
            int? nextIdx;
            for (var k = 0; k < n; k++) {
              if (!day.lessons[k].isEmpty && slots[k].start != null && slots[k].start! > m) {
                nextIdx = k;
                break;
              }
            }
            final lastEnd = n > 0 ? slots[n - 1].end : null;
            if (nextIdx != null) {
              overline = tr('PROSSIMA · ore ${slots[nextIdx].startText}', 'NEXT · at ${slots[nextIdx].startText}');
              title = day.lessons[nextIdx].title;
              if (day.lessons[nextIdx].lab.isNotEmpty) place = day.lessons[nextIdx].lab;
              final mins = slots[nextIdx].start! - m;
              subtitle = mins < 60 ? tr('Tra $mins min', 'In $mins min') : tr('Tra ${mins ~/ 60} h ${mins % 60} min', 'In ${mins ~/ 60} h ${mins % 60} min');
            } else if (lastEnd != null && m >= lastEnd) {
              overline = tr('OGGI', 'TODAY');
              title = tr('Lezioni finite!', 'Lessons are over!');
              subtitle = tr('Goditi il resto della giornata.', 'Enjoy the rest of the day.');
            } else {
              overline = tr('OGGI', 'TODAY');
              title = ref.displayName;
              subtitle = tr('Tocca per vedere l\'orario di oggi.', 'Tap to see today\'s timetable.');
            }
          }
        }
      }
    }

    final extra = ref == null ? const <String>[] : lessonCountdowns(store, now);
    final onCard = scheme.onPrimary;
    return Material(
      color: scheme.primary,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                overline,
                style: TextStyle(
                  color: onCard.withAlpha(215),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(color: onCard, fontSize: 22, fontWeight: FontWeight.w700, height: 1.15),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: onCard.withAlpha(225), fontSize: 14.5),
                ),
              ],
              if (place != null) ...[
                const SizedBox(height: 10),
                PlacePill(place, color: onCard),
              ],
              if (progress != null) ...[
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    color: onCard,
                    backgroundColor: onCard.withAlpha(60),
                  ),
                ),
              ],
              if (footer != null) ...[
                const SizedBox(height: 10),
                Text(footer, style: TextStyle(color: onCard.withAlpha(225), fontSize: 13.5)),
              ],
              // Conti alla rovescia delle lezioni (ricreazione, ultima campanella), dentro la card.
              if (extra.isNotEmpty) ...[
                SizedBox(height: footer == null ? 12 : 4),
                Text(extra.join('  ·  '), style: TextStyle(color: onCard.withAlpha(225), fontSize: 13.5)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

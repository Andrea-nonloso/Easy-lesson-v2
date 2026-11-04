import 'dart:async';
import 'dart:math' as math;

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
import 'now_page.dart';
import 'school_life_pages.dart';
import 'search_page.dart';
import 'school_shortcuts.dart';
import 'settings_sheet.dart';
import 'theme.dart';
import 'widgets.dart';

/// Prima schermata dell'app: data, saluto, ricerca rapida, la lezione di
/// adesso, le scorciatoie e (se c'e' spazio) le prossime lezioni.
/// La disposizione si adatta allo schermo: telefono, telefono in orizzontale,
/// tablet e finestra di Windows.
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

  static const _months = [
    'gen', 'feb', 'mar', 'apr', 'mag', 'giu',
    'lug', 'ago', 'set', 'ott', 'nov', 'dic',
  ];

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final now = DateTime.now();

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) {
            // Tablet / finestra larga: due colonne.
            if (box.maxWidth >= 840 && box.maxHeight >= 440) return _wide(context, store, now);
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: _narrow(context, store, now, box.maxHeight),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Saluto, ricerca e cambio rapido.
  List<Widget> _header(BuildContext context, AppStore store, DateTime now, {required bool tight}) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return [
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${dayShort[now.weekday - 1]} ${now.day} ${_months[now.month - 1]}',
                  style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant, letterSpacing: 0.6),
                ),
                const SizedBox(height: 2),
                Text(
                  store.username != null ? tr('Ciao, ${store.username}!', 'Hi, ${store.username}!') : tr('Ciao!', 'Hi!'),
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
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
          IconButton(
            tooltip: 'Impostazioni',
            onPressed: () => showSettingsSheet(context),
            icon: const Icon(Icons.tune_rounded),
          ),
          const SizedBox(width: 2),
          const AppLogo(size: 38),
        ],
      ),
      SizedBox(height: tight ? 4 : 8),
      // 3.6: Voti, Assenze… e "Altro" (scelti dall'utente; tenendo premuto si cambiano).
      const SchoolShortcutsRow(),
      SizedBox(height: tight ? 4 : 8),
      Material(
        color: cardColor(context),
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: onSearch,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                Icon(Icons.search_rounded, size: 20, color: scheme.onSurfaceVariant),
                const SizedBox(width: 10),
                Text(
                  'Cerca classe o docente…',
                  style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
      if (store.opt('home.shortcuts', true)) _QuickSwitch(store: store, onOpenMine: onOpenMine, onSearch: onSearch),
      const ScheduleChangedBanner(),
      const AnnouncementBanner(),
      SizedBox(height: tight ? 10 : 16),
      _TodayCard(store: store, now: now, onOpenMine: onOpenMine, onSearch: onSearch),
      if (!tight && store.opt('home.countdown', true)) ...[const SizedBox(height: 10), _Countdowns(store: store)],
    ];
  }

  /// Le tre scorciatoie. [inRow] = tutte e tre in fila (schermi bassi o larghi),
  /// altrimenti quella grande a sinistra e due impilate a destra.
  Widget _shortcuts(AppStore store, {required double height, required bool inRow}) {
    final compact = height < 120;
    final mine = _ShortcutCard(
      icon: Icons.today_rounded,
      title: 'Il mio orario',
      subtitle: store.myRef?.displayName ?? 'Da impostare',
      filled: true,
      compact: compact && inRow,
      onTap: store.myRef != null ? onOpenMine : onSearch,
    );
    final search = _ShortcutCard(
      icon: Icons.search_rounded,
      title: 'Cerca',
      subtitle: 'Classi e docenti',
      compact: inRow ? compact : height < 170,
      onTap: onSearch,
    );
    final saved = _ShortcutCard(
      icon: Icons.bookmark_rounded,
      title: 'Salvati',
      subtitle: '${store.favorites.length} offline',
      compact: inRow ? compact : height < 170,
      onTap: onOpenSaved,
    );
    if (inRow) {
      return SizedBox(
        height: height,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: mine),
            const SizedBox(width: 10),
            Expanded(child: search),
            const SizedBox(width: 10),
            Expanded(child: saved),
          ],
        ),
      );
    }
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 11, child: mine),
          const SizedBox(width: 12),
          Expanded(
            flex: 10,
            child: Column(
              // stretch: le due card occupano tutta la larghezza della colonna.
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: search),
                const SizedBox(height: 12),
                Expanded(child: saved),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _narrow(BuildContext context, AppStore store, DateTime now, double height) {
    final tight = height < 620;
    final header = _header(context, store, now, tight: tight);
    final gap = tight ? 12.0 : 16.0;

    // Schermo basso (es. telefono in orizzontale): si scorre.
    if (height < 440) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        children: [
          ...header,
          SizedBox(height: gap),
          _shortcuts(store, height: 100, inRow: true),
          SizedBox(height: gap),
          _HomeExtras(store: store, now: now, onOpenMine: onOpenMine, scrollable: true),
        ],
      );
    }

    // Altrimenti tutto in una schermata, senza scorrere: le scorciatoie hanno
    // proporzioni fisse (non si allungano piu' in altezza) e lo spazio che
    // avanza va alle prossime lezioni e agli orari recenti.
    return Padding(
      padding: EdgeInsets.fromLTRB(20, tight ? 10 : 18, 20, tight ? 10 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...header,
          SizedBox(height: gap),
          Expanded(
            child: LayoutBuilder(
              builder: (context, rest) {
                if (rest.maxHeight < 84) {
                  return SingleChildScrollView(child: _shortcuts(store, height: 92, inRow: true));
                }
                // Riquadri grandi solo se resta spazio anche per il resto.
                final big = math.min(rest.maxWidth * 0.46, 200.0);
                final inRow = rest.maxHeight < big + 100;
                final h = inRow ? math.min(rest.maxHeight, 112.0) : big;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _shortcuts(store, height: h, inRow: inRow),
                    if (rest.maxHeight - h > 90) ...[
                      SizedBox(height: gap),
                      Expanded(child: _HomeExtras(store: store, now: now, onOpenMine: onOpenMine)),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _wide(BuildContext context, AppStore store, DateTime now) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 18, 28, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 6,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ..._header(context, store, now, tight: false),
                      const SizedBox(height: 16),
                      _shortcuts(store, height: 120, inRow: true),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 28),
              Expanded(
                flex: 5,
                child: _HomeExtras(store: store, now: now, onOpenMine: onOpenMine),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Le lezioni di oggi (o del prossimo giorno di scuola) e gli orari recenti:
/// ne mostra quante entrano nello spazio disponibile.
class _HomeExtras extends StatelessWidget {
  const _HomeExtras({required this.store, required this.now, required this.onOpenMine, this.scrollable = false});

  final AppStore store;
  final DateTime now;
  final VoidCallback onOpenMine;

  /// true = dentro una lista che scorre: mostra tutto senza misurare.
  final bool scrollable;

  static const _peekTitle = 34.0;
  static const _peekPad = 12.0;
  static const _peekRow = 36.0;
  static const _recentTitle = 36.0;
  static const _recentRow = 74.0;

  @override
  Widget build(BuildContext context) {
    // Cosa mostrare si sceglie in Impostazioni → Home e app.
    final peek = store.opt('home.next', true) ? _peekFor(store, now) : null;
    final todo = store.opt('home.agenda', true) ? store.agendaFrom(now, days: 7) : const <AgendaItem>[];
    // Lo zaino compare quando le lezioni di oggi sono finite (o oggi non c'e' scuola).
    final plan = store.opt('home.bag', true) ? bagPlanFor(store, now) : null;
    final showBag = plan != null && (peek == null || peek.title != 'Oggi');
    final mine = store.myRef?.key;
    final others = store.opt('home.recents', true)
        ? [...store.favorites, ...store.recents].where((s) => s.ref.key != mine).toList()
        : const <CachedSchedule>[];

    if (scrollable) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (todo.isNotEmpty) ...[_AgendaPeek(items: todo, max: 5), const SizedBox(height: 16)],
          if (showBag) ...[_BagPeek(plan: plan), const SizedBox(height: 16)],
          if (peek != null && peek.items.isNotEmpty) _DayPeek(peek: peek, max: peek.items.length, onOpen: onOpenMine),
          if (peek != null && peek.items.isNotEmpty && others.isNotEmpty) const SizedBox(height: 16),
          if (others.isNotEmpty) _Recents(items: others, max: 5),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, box) {
        var h = box.maxHeight;
        final children = <Widget>[];
        // Prima i compiti e le verifiche in arrivo (max 3), poi le lezioni, poi i recenti.
        if (todo.isNotEmpty && h >= _peekTitle + _peekPad + _peekRow) {
          final k = math.min(math.min(todo.length, 3), ((h - _peekTitle - _peekPad) / _peekRow).floor());
          children.add(_AgendaPeek(items: todo, max: k));
          h -= _peekTitle + _peekPad + _peekRow * k + 16;
        }
        if (showBag && h >= _peekTitle + _peekPad + _peekRow) {
          if (children.isNotEmpty) children.add(const SizedBox(height: 16));
          children.add(_BagPeek(plan: plan));
          h -= _peekTitle + _peekPad + _peekRow + 16;
        }
        if (peek != null && peek.items.isNotEmpty && h >= _peekTitle + _peekPad + _peekRow) {
          final k = math.min(peek.items.length, ((h - _peekTitle - _peekPad) / _peekRow).floor());
          if (children.isNotEmpty) children.add(const SizedBox(height: 16));
          children.add(_DayPeek(peek: peek, max: k, onOpen: onOpenMine));
          h -= _peekTitle + _peekPad + _peekRow * k + 16;
        }
        if (others.isNotEmpty && h >= _recentTitle + _recentRow) {
          if (children.isNotEmpty) children.add(const SizedBox(height: 16));
          children.add(_Recents(items: others, max: ((h - _recentTitle) / _recentRow).floor()));
        }
        // Se la stima e' un po' larga, l'ultimo elemento viene tagliato invece di uscire dallo schermo.
        return ClipRect(
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
          ),
        );
      },
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
      title = 'Oggi';
    }
  }
  if (dayIdx == null) {
    // Il prossimo giorno con lezioni, saltando vacanze e feste.
    for (var off = 1; off <= 120; off++) {
      final d = DateTime(now.year, now.month, now.day + off);
      final wd = d.weekday - 1;
      if (wd < days.length && !days[wd].isEmpty && cal.closureOn(d) == null) {
        dayIdx = wd;
        title = off == 1 ? 'Domani' : (off < 7 ? dayNames[wd] : '${dayNames[wd]} ${d.day}/${d.month}');
        date = d;
        break;
      }
    }
  }
  if (dayIdx == null) return null;

  final today = dayIdx == ti && title == 'Oggi';
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
        : (todo.isEmpty ? '✅ Zaino pronto!' : todo.join(' · '));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 34,
          child: Row(
            children: [
              Text('🎒 Zaino', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              Text(
                'per ${friendlyDate(plan.date, DateTime.now()).toLowerCase()}',
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
              Text('In arrivo', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
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
                child: const Text('Agenda'),
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
                hidden > 0 ? '+$hidden dopo' : '${peek.items.length} ${peek.items.length == 1 ? 'lezione' : 'lezioni'}',
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
                child: const Text('Orario'),
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

/// Conti alla rovescia: ricreazione, ultima campanella, weekend, vacanze.
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

  static String _mins(int m) => m < 60 ? '$m min' : '${m ~/ 60} h${m % 60 == 0 ? '' : ' ${m % 60} min'}';

  List<String> _items(DateTime now) {
    final store = widget.store;
    final out = <String>[];
    final m = now.hour * 60 + now.minute;
    final ref = store.myRef;
    final cached = ref == null ? null : store.cached(ref);
    final cal = store.calendar;
    final schoolToday = cal.closureOn(now) == null;
    if (cached != null && schoolToday) {
      final days = cached.week.days;
      final ti = todayIndex(now, days.length);
      if (ti >= 0 && !days[ti].isEmpty) {
        final slots = store.slots;
        final lessons = days[ti].lessons;
        int? lastEnd;
        int? firstStart;
        for (var k = 0; k < lessons.length && k < slots.length; k++) {
          if (lessons[k].isEmpty) continue;
          firstStart ??= slots[k].start;
          lastEnd = slots[k].end ?? lastEnd;
        }
        if (firstStart != null && lastEnd != null && m < lastEnd) {
          // Ricreazione (adesso o la prossima)
          for (final b in breaksOf(slots)) {
            if (b.afterIndex + 1 >= lessons.length) continue;
            if (m >= b.start && m < b.end) {
              out.add('☕ Ricreazione: ancora ${_mins(b.end - m)}');
              break;
            }
            if (b.start > m && m >= firstStart - 60) {
              out.add('☕ Ricreazione tra ${_mins(b.start - m)}');
              break;
            }
          }
          out.add(m < firstStart
              ? '🔔 Si entra tra ${_mins(firstStart - m)}'
              : '🔔 Ultima campanella tra ${_mins(lastEnd - m)}');
        }
      }
    }
    // Weekend (lun-ven)
    final wd = now.weekday;
    if (wd <= 4) {
      final n = 6 - wd;
      out.add('🎉 Weekend tra $n giorni');
    } else if (wd == 5) {
      out.add('🎉 Domani è sabato!');
    }
    // Conti alla rovescia personali (gita, compleanno…), poi vacanze e feste.
    for (final e in store.countdowns) {
      final left = daysBetweenDates(now, e.date);
      if (left < 0 || left > 60) continue;
      out.add(left == 0 ? '${e.emoji} ${e.name}: è oggi!' : '${e.emoji} ${e.name} tra $left ${left == 1 ? 'giorno' : 'giorni'}');
    }
    for (final c in cal.countdowns(now, max: 2)) {
      out.add('${c.emoji} ${c.name} tra ${c.days} ${c.days == 1 ? 'giorno' : 'giorni'}');
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
    String? place; // laboratorio della lezione di adesso / prossima
    VoidCallback onTap = onOpenMine;

    if (ref == null) {
      overline = 'INIZIA DA QUI';
      title = 'Imposta il tuo orario';
      subtitle = 'Scegli la tua classe o il tuo nome: lo troverai sempre in apertura.';
      onTap = onSearch;
    } else {
      final cached = store.cached(ref);
      if (cached == null) {
        overline = ref.displayName.toUpperCase();
        title = 'Scarica l\'orario';
        subtitle = 'Tocca qui per scaricarlo e averlo sempre con te.';
      } else {
        final days = cached.week.days;
        final ti = todayIndex(now, days.length);
        final closure = store.calendar.closureOn(now);
        if (closure != null && ti >= 0) {
          // Vacanza o festa in un giorno di scuola.
          final back = store.nextSchoolDay(now, daysPerWeek: days.length);
          overline = 'OGGI NIENTE SCUOLA';
          title = '${closure.emoji} ${closure.name}';
          subtitle = back == null
              ? 'Goditi la giornata.'
              : 'Si torna ${friendlyDate(back, now).toLowerCase()} (${dayNames[back.weekday - 1].toLowerCase()} ${back.day}/${back.month}).';
        } else if (ti < 0 || days[ti].isEmpty) {
          overline = 'OGGI';
          title = 'Nessuna lezione oggi';
          subtitle = 'Goditi la giornata.';
        } else {
          final day = days[ti];
          final slots = store.slots;
          final n = day.lessons.length < slots.length ? day.lessons.length : slots.length;
          final m = now.hour * 60 + now.minute;
          final idx = currentSlot(slots, now);
          if (idx != null && idx < n) {
            final l = day.lessons[idx];
            final s = slots[idx];
            overline = 'ADESSO · fino alle ${s.endText}';
            title = l.isEmpty ? 'Ora libera' : l.title;
            if (l.lab.isNotEmpty) place = l.lab;
            progress = ((m - s.start!) / (s.end! - s.start!)).clamp(0.0, 1.0).toDouble();
            if (!l.isEmpty && l.details.isNotEmpty) subtitle = l.details.join(' · ');
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
              overline = 'PROSSIMA · ore ${slots[nextIdx].startText}';
              title = day.lessons[nextIdx].title;
              if (day.lessons[nextIdx].lab.isNotEmpty) place = day.lessons[nextIdx].lab;
              final mins = slots[nextIdx].start! - m;
              subtitle = mins < 60 ? 'Tra $mins min' : 'Tra ${mins ~/ 60} h ${mins % 60} min';
            } else if (lastEnd != null && m >= lastEnd) {
              overline = 'OGGI';
              title = 'Lezioni finite!';
              subtitle = 'Goditi il resto della giornata.';
            } else {
              overline = 'OGGI';
              title = ref.displayName;
              subtitle = 'Tocca per vedere l\'orario di oggi.';
            }
          }
        }
      }
    }

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
            ],
          ),
        ),
      ),
    );
  }
}

/// Scorciatoia quadrata nella sezione "Per te".
class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.filled = false,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  /// true = card piena colorata (quella grande a sinistra).
  final bool filled;

  /// true = versione bassa per schermi piccoli (meno margine, icona piu' piccola).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bg = filled ? scheme.tertiaryContainer : cardColor(context);
    final fg = filled ? scheme.onTertiaryContainer : scheme.onSurface;
    final sub = filled ? scheme.onTertiaryContainer.withAlpha(190) : scheme.onSurfaceVariant;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: LayoutBuilder(builder: (context, box) {
          // Troppo bassa per icona sopra e testo sotto: icona a sinistra.
          final flat = box.maxHeight.isFinite && box.maxHeight < 84;
          final ic = Icon(icon, color: fg, size: compact ? 22 : 26);
          final texts = Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: fg),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: sub),
              ),
            ],
          );
          return Padding(
            padding: EdgeInsets.all(compact || flat ? 12 : 16),
            child: flat
                ? Row(children: [ic, const SizedBox(width: 10), Expanded(child: texts)])
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [ic, texts],
                  ),
          );
        }),
      ),
    );
  }
}

/// Ultimi orari aperti e salvati (senza il proprio), in fondo alla home.
class _Recents extends StatelessWidget {
  const _Recents({required this.items, this.max = 5});

  final List<CachedSchedule> items;

  /// Quanti orari mostrare (in base allo spazio libero).
  final int max;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (items.isEmpty || max <= 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('I tuoi orari', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        for (final s in items.take(max))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: cardColor(context),
              borderRadius: BorderRadius.circular(18),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: SubjectColors.of(s.ref.name, theme.brightness).bg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    s.ref.prof ? Icons.person_rounded : Icons.groups_rounded,
                    size: 22,
                    color: SubjectColors.of(s.ref.name, theme.brightness).fg,
                  ),
                ),
                title: Text(
                  s.ref.displayName,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  s.ref.kindLabel,
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
                trailing: Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
                onTap: () => openSchedule(context, s.ref),
              ),
            ),
          ),
      ],
    );
  }
}

/// Cambio rapido tra il proprio orario, quelli salvati (classi o docenti) e la ricerca.
class _QuickSwitch extends StatelessWidget {
  const _QuickSwitch({required this.store, required this.onOpenMine, required this.onSearch});

  final AppStore store;
  final VoidCallback onOpenMine;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final mine = store.myRef;
    final others = store.favorites.where((s) => mine == null || s.ref.key != mine.key).take(6).toList();

    Widget chip(String label, IconData icon, VoidCallback onTap, {bool selected = false}) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ActionChip(
            avatar: Icon(icon, size: 18),
            label: Text(label),
            onPressed: onTap,
            side: selected ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5) : null,
          ),
        );

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SizedBox(
        height: 40,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            if (mine != null) chip(mine.displayName, Icons.home_rounded, onOpenMine, selected: true),
            for (final s in others)
              chip(
                s.ref.displayName,
                s.ref.prof ? Icons.person_rounded : Icons.groups_rounded,
                () => openSchedule(context, s.ref),
              ),
            chip('Docenti e classi', Icons.swap_horiz_rounded, onSearch),
            if (store.usingExcel) chip('Dov\'è il prof', Icons.person_search_rounded, () => openNowAtSchool(context)),
            if (store.usingExcel) chip('Lab liberi', Icons.science_outlined, () => openNowAtSchool(context, labs: true)),
            chip('Agenda', Icons.event_note_rounded, () => openAgenda(context)),
            chip('Zaino', Icons.backpack_outlined, () => openBag(context)),
            chip(tr('Calendario', 'Calendar'), Icons.calendar_month_outlined, () => openMonth(context)),
            chip(tr('Voti', 'Grades'), Icons.grade_outlined, () => openGrades(context)),
            chip(tr('Ripasso', 'Study plan'), Icons.menu_book_outlined, () => openStudyPlan(context)),
            chip('Assenze', Icons.event_busy_outlined, () => openAbsences(context)),
            chip('Studia', Icons.timer_outlined, () => openStudyTimer(context)),
            chip(tr('Verifica', 'Exam'), Icons.hourglass_bottom_rounded, () => openExamMode(context)),
            chip(tr('Obiettivi', 'Achievements'), Icons.emoji_events_outlined, () => openAchievements(context)),
          ],
        ),
      ),
    );
  }
}

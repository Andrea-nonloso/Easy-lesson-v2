import 'dart:async';

import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import 'settings_sheet.dart';
import 'theme.dart';
import 'widgets.dart';

/// Larghezza oltre la quale si mostra la griglia settimanale (tablet / desktop).
const kGridBreakpoint = 720.0;

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key, required this.ref, this.isHome = false});

  final ScheduleRef ref;

  /// true se mostrato nella scheda "Il mio orario".
  final bool isHome;

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  bool _loading = false;
  Object? _error;
  DateTime _now = DateTime.now();
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      StoreScope.read(context).touch(widget.ref);
      _refresh(silent: true);
    });
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _refresh({bool silent = false}) async {
    if (_loading) return;
    final store = StoreScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (!silent && store.usingExcel && store.excelUrl != null) await store.refreshLists();
      await store.fetchSchedule(widget.ref);
      if (!silent) {
        messenger.showSnackBar(const SnackBar(content: Text('Orario aggiornato')));
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
      if (!silent && store.cached(widget.ref) != null) {
        messenger.showSnackBar(SnackBar(content: Text('Aggiornamento non riuscito: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleFavorite(AppStore store) async {
    final messenger = ScaffoldMessenger.of(context);
    await store.toggleFavorite(widget.ref);
    final fav = store.cached(widget.ref)?.favorite ?? false;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(fav
            ? '${widget.ref.displayName} salvato: disponibile anche offline'
            : '${widget.ref.displayName} rimosso dai salvati'),
      ));
  }

  Future<void> _toggleMine(AppStore store) async {
    final messenger = ScaffoldMessenger.of(context);
    final mine = store.isMine(widget.ref);
    await store.setMine(mine ? null : widget.ref);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(mine
            ? 'Non è più il tuo orario'
            : '${widget.ref.displayName} è ora il tuo orario: lo trovi nella prima scheda'),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final cached = store.cached(widget.ref);
    final isFav = cached?.favorite ?? false;
    final isMine = store.isMine(widget.ref);
    final wide = MediaQuery.sizeOf(context).width >= kGridBreakpoint;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.isHome,
        titleSpacing: widget.isHome ? 16 : 0,
        title: Row(
          children: [
            if (widget.isHome && !wide) ...[const AppLogo(size: 36), const SizedBox(width: 12)],
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.ref.displayName,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, height: 1.1),
                  ),
                  Text(
                    widget.isHome ? 'Il mio orario · ${widget.ref.kindLabel}' : widget.ref.kindLabel,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2.4)),
            )
          else
            IconButton(
              tooltip: 'Aggiorna',
              onPressed: () => _refresh(),
              icon: const Icon(Icons.refresh_rounded),
            ),
          if (!widget.isHome && cached != null)
            IconButton(
              tooltip: isFav ? 'Rimuovi dai salvati' : 'Salva offline',
              onPressed: () => _toggleFavorite(store),
              icon: Icon(isFav ? Icons.bookmark_rounded : Icons.bookmark_border_rounded),
              color: isFav ? scheme.primary : null,
            ),
          PopupMenuButton<String>(
            tooltip: 'Altro',
            onSelected: (v) {
              switch (v) {
                case 'mine':
                  _toggleMine(store);
                case 'grid':
                  store.setPreferGrid(!store.preferGrid);
                case 'settings':
                  showSettingsSheet(context);
              }
            },
            itemBuilder: (_) => [
              if (cached != null)
                PopupMenuItem(
                  value: 'mine',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(isMine ? Icons.home_rounded : Icons.home_outlined),
                    title: Text(isMine ? 'Non è il mio orario' : 'Imposta come mio orario'),
                  ),
                ),
              if (wide)
                PopupMenuItem(
                  value: 'grid',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(store.preferGrid ? Icons.view_day_outlined : Icons.calendar_view_week_outlined),
                    title: Text(store.preferGrid ? 'Vista per giorno' : 'Vista settimana'),
                  ),
                ),
              const PopupMenuItem(
                value: 'settings',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.settings_outlined),
                  title: Text('Impostazioni'),
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _body(context, store, cached),
    );
  }

  Widget _body(BuildContext context, AppStore store, CachedSchedule? cached) {
    if (cached == null) {
      if (_error != null) {
        return EmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'Orario non disponibile',
          message: '$_error. Controlla la connessione e riprova.',
          action: FilledButton.icon(
            onPressed: () => _refresh(),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Riprova'),
          ),
        );
      }
      return const _LoadingSkeleton();
    }
    final week = cached.week;
    if (week.isEmpty) {
      return const EmptyState(
        icon: Icons.event_busy_rounded,
        title: 'Nessuna lezione',
        message: 'In questo orario non ci sono lezioni registrate.',
      );
    }
    return Column(
      children: [
        _StatusBar(
          cached: cached,
          offline: _error != null,
          showMineHint: store.myRef == null && !widget.isHome,
          onSetMine: () => _toggleMine(store),
        ),
        Expanded(
          child: LayoutBuilder(builder: (context, c) {
            final grid = c.maxWidth >= kGridBreakpoint && store.preferGrid;
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: grid
                  ? WeekGrid(key: const ValueKey('grid'), week: week, slots: store.slots, now: _now)
                  : DayPager(key: const ValueKey('days'), week: week, slots: store.slots, now: _now),
            );
          }),
        ),
      ],
    );
  }
}

// ----------------------------------------------------------------------------

class _StatusBar extends StatelessWidget {
  const _StatusBar({
    required this.cached,
    required this.offline,
    required this.showMineHint,
    required this.onSetMine,
  });

  final CachedSchedule cached;
  final bool offline;
  final bool showMineHint;
  final VoidCallback onSetMine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = offline ? scheme.error : scheme.onSurfaceVariant;
    final text = offline
        ? 'Offline · orario salvato ${relativeTime(cached.updatedAt)}'
        : '${cached.favorite ? 'Disponibile offline · ' : ''}aggiornato ${relativeTime(cached.updatedAt)}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                offline
                    ? Icons.cloud_off_rounded
                    : (cached.favorite ? Icons.offline_pin_rounded : Icons.cloud_done_outlined),
                size: 16,
                color: offline ? color : (cached.favorite ? scheme.primary : color),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(text, style: theme.textTheme.labelMedium?.copyWith(color: color)),
              ),
            ],
          ),
          if (showMineHint) ...[
            const SizedBox(height: 8),
            Material(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: onSetMine,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      Icon(Icons.home_rounded, color: scheme.onPrimaryContainer),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'È il tuo orario? Tocca qui per averlo sempre in apertura, anche offline.',
                          style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onPrimaryContainer),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(140);
    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        Container(height: 58, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(20))),
        const SizedBox(height: 16),
        for (var i = 0; i < 6; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 52,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Container(width: 38, height: 14, color: c),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 76,
                    decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(18)),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------- vista giorno

class DayPager extends StatefulWidget {
  const DayPager({super.key, required this.week, required this.slots, required this.now});

  final WeekSchedule week;
  final List<TimeSlot> slots;
  final DateTime now;

  @override
  State<DayPager> createState() => _DayPagerState();
}

class _DayPagerState extends State<DayPager> with TickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = _create();
  }

  TabController _create() {
    final n = widget.week.days.length;
    final t = todayIndex(widget.now, n);
    return TabController(length: n, vsync: this, initialIndex: t < 0 ? 0 : t);
  }

  @override
  void didUpdateWidget(DayPager old) {
    super.didUpdateWidget(old);
    if (old.week.days.length != widget.week.days.length) {
      _tabs.dispose();
      _tabs = _create();
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final n = widget.week.days.length;
    final today = todayIndex(widget.now, n);
    final start = weekStart(widget.now, n);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: cardColor(context),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: scheme.outlineVariant.withAlpha(90)),
              ),
              child: TabBar(
                controller: _tabs,
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(16)),
                labelColor: scheme.onPrimary,
                unselectedLabelColor: scheme.onSurfaceVariant,
                splashBorderRadius: BorderRadius.circular(16),
                labelPadding: EdgeInsets.zero,
                tabs: [
                  for (var i = 0; i < n; i++)
                    Tab(
                      height: 56,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            i == today ? 'OGGI' : dayShort[i].toUpperCase(),
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8),
                          ),
                          Text(
                            '${start.add(Duration(days: i)).day}',
                            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, height: 1.15),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  for (var i = 0; i < n; i++)
                    DayList(
                      day: widget.week.days[i],
                      dayIndex: i,
                      slots: widget.slots,
                      now: widget.now,
                      isToday: i == today,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LessonGroup {
  LessonGroup(this.lesson, this.from, this.to);
  final Lesson lesson;
  final int from;
  int to;
  int get hours => to - from + 1;
}

/// Unisce le ore consecutive uguali, ma non attraverso una ricreazione.
List<LessonGroup> groupLessons(List<Lesson> lessons, [List<BreakSlot> breaks = const []]) {
  final out = <LessonGroup>[];
  for (final l in lessons) {
    if (out.isNotEmpty &&
        out.last.lesson.signature == l.signature &&
        breakAfter(breaks, out.last.to) == null) {
      out.last.to = l.index;
    } else {
      out.add(LessonGroup(l, l.index, l.index));
    }
  }
  return out;
}

class DayList extends StatelessWidget {
  const DayList({
    super.key,
    required this.day,
    required this.dayIndex,
    required this.slots,
    required this.now,
    required this.isToday,
  });

  final DaySchedule day;
  final int dayIndex;
  final List<TimeSlot> slots;
  final DateTime now;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    if (day.isEmpty) {
      return EmptyState(
        icon: Icons.weekend_outlined,
        title: 'Giorno libero',
        message: 'Nessuna lezione ${dayIndex < dayNames.length ? 'il ${dayNames[dayIndex].toLowerCase()}' : ''}.',
      );
    }
    final breaks = breaksOf(slots);
    final groups = groupLessons(day.lessons, breaks);
    final nowIdx = isToday ? currentSlot(slots, now) : null;
    final m = now.hour * 60 + now.minute;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        if (isToday) NowCard(day: day, slots: slots, now: now),
        for (var i = 0; i < groups.length; i++) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: LessonTile(
              group: groups[i],
              slots: slots,
              active: nowIdx != null && nowIdx >= groups[i].from && nowIdx <= groups[i].to,
            ),
          ),
          if (i + 1 < groups.length && breakAfter(breaks, groups[i].to) != null)
            _BreakRow(
              slot: breakAfter(breaks, groups[i].to)!,
              active: isToday && m >= breakAfter(breaks, groups[i].to)!.start && m < breakAfter(breaks, groups[i].to)!.end,
            ),
        ],
      ],
    );
  }
}

/// Separatore "Ricreazione 10:20 – 10:30" tra due ore.
class _BreakRow extends StatelessWidget {
  const _BreakRow({required this.slot, this.active = false});

  final BreakSlot slot;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = active ? scheme.primary : scheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(left: 64, bottom: 10),
      child: Row(
        children: [
          Icon(Icons.local_cafe_outlined, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            active ? '${slot.label} · ora' : slot.label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Divider(color: scheme.outlineVariant, height: 1)),
        ],
      ),
    );
  }
}

/// Riquadro "Adesso / Prossima lezione" mostrato nel giorno corrente.
class NowCard extends StatelessWidget {
  const NowCard({super.key, required this.day, required this.slots, required this.now});

  final DaySchedule day;
  final List<TimeSlot> slots;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final lessons = day.lessons;
    final n = lessons.length < slots.length ? lessons.length : slots.length;
    if (n == 0 || slots.first.start == null) return const SizedBox.shrink();

    final m = now.hour * 60 + now.minute;
    final idx = currentSlot(slots, now);
    String overline;
    String title;
    String? subtitle;
    double? progress;

    Lesson? nextAfter(int i) {
      for (var k = i + 1; k < n; k++) {
        if (!lessons[k].isEmpty && lessons[k].signature != lessons[i].signature) return lessons[k];
      }
      return null;
    }

    if (idx != null && idx < n) {
      final l = lessons[idx];
      final s = slots[idx];
      overline = 'ADESSO · fino alle ${s.endText}';
      title = l.isEmpty ? 'Ora libera' : l.title;
      progress = ((m - s.start!) / (s.end! - s.start!)).clamp(0.0, 1.0).toDouble();
      final next = nextAfter(idx);
      subtitle = next != null ? 'Poi: ${next.title}' : (idx == n - 1 ? 'Ultima ora di oggi' : null);
    } else if (breaksOf(slots).any((b) =>
        m >= b.start && m < b.end && b.afterIndex + 1 < n && lessons.skip(b.afterIndex + 1).any((l) => !l.isEmpty))) {
      final b = breaksOf(slots).firstWhere((b) => m >= b.start && m < b.end);
      overline = 'RICREAZIONE · fino alle ${TimeSlot.fmt(b.end)}';
      title = 'Ricreazione';
      progress = ((m - b.start) / (b.end - b.start)).clamp(0.0, 1.0).toDouble();
      final next = lessons.skip(b.afterIndex + 1).firstWhere((l) => !l.isEmpty);
      subtitle = 'Poi: ${next.title}';
    } else {
      int? nextIdx;
      for (var k = 0; k < n; k++) {
        if (!lessons[k].isEmpty && slots[k].start != null && slots[k].start! > m) {
          nextIdx = k;
          break;
        }
      }
      final lastEnd = slots[n - 1].end;
      if (nextIdx != null) {
        overline = 'PROSSIMA LEZIONE · ore ${slots[nextIdx].startText}';
        title = lessons[nextIdx].title;
        final mins = slots[nextIdx].start! - m;
        subtitle = mins < 60 ? 'Tra $mins minuti' : 'Tra ${mins ~/ 60} h ${mins % 60} min';
      } else if (lastEnd != null && m >= lastEnd) {
        overline = 'OGGI';
        title = 'Lezioni finite!';
        subtitle = 'Goditi il resto della giornata.';
      } else {
        return const SizedBox.shrink();
      }
    }

    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [scheme.primary, Color.lerp(scheme.primary, scheme.tertiary, 0.55)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            overline,
            style: TextStyle(
              color: scheme.onPrimary.withAlpha(210),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(color: scheme.onPrimary, fontSize: 24, fontWeight: FontWeight.w700, height: 1.15),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(color: scheme.onPrimary.withAlpha(220), fontSize: 15)),
          ],
          if (progress != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                color: scheme.onPrimary,
                backgroundColor: scheme.onPrimary.withAlpha(60),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class LessonTile extends StatelessWidget {
  const LessonTile({super.key, required this.group, required this.slots, required this.active});

  final LessonGroup group;
  final List<TimeSlot> slots;
  final bool active;

  TimeSlot? _slot(int i) => i < slots.length ? slots[i] : null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l = group.lesson;
    final from = _slot(group.from);
    final to = _slot(group.to);
    final hoursLabel = group.hours > 1 ? '${group.from + 1}ª–${group.to + 1}ª ora' : '${group.from + 1}ª ora';

    final time = SizedBox(
      width: 52,
      child: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              from?.start != null ? from!.startText : '${group.from + 1}ª',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: active ? scheme.primary : scheme.onSurface,
              ),
            ),
            if (to?.end != null)
              Text(to!.endText, style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );

    Widget card;
    if (l.isEmpty) {
      card = Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Text(
          group.hours > 1 ? 'Libero · ${group.hours} ore' : 'Ora libera',
          style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
      );
    } else {
      final c = SubjectColors.of(l.title, theme.brightness);
      card = Container(
        decoration: BoxDecoration(
          color: c.bg,
          borderRadius: BorderRadius.circular(18),
          border: active ? Border.all(color: scheme.primary, width: 2) : null,
          boxShadow: active
              ? [BoxShadow(color: scheme.primary.withAlpha(50), blurRadius: 16, offset: const Offset(0, 6))]
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 5, color: c.accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            hoursLabel,
                            style: theme.textTheme.labelMedium?.copyWith(color: c.fg.withAlpha(170)),
                          ),
                          const Spacer(),
                          if (active)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: scheme.primary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'ADESSO',
                                style: TextStyle(
                                  color: scheme.onPrimary,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                        ],
                      ),
                      Text(
                        l.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: c.fg,
                          height: 1.2,
                        ),
                      ),
                      for (final d in l.details)
                        Text(d, style: theme.textTheme.bodyMedium?.copyWith(color: c.fg.withAlpha(200))),
                      if (l.lab.isNotEmpty || l.sostegno.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(spacing: 6, runSpacing: 6, children: lessonTags(l, c.fg)),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [time, const SizedBox(width: 12), Expanded(child: card)],
    );
  }
}

// ---------------------------------------------------------------- griglia tablet

class WeekGrid extends StatelessWidget {
  const WeekGrid({super.key, required this.week, required this.slots, required this.now});

  final WeekSchedule week;
  final List<TimeSlot> slots;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final n = week.days.length;
    final rows = week.maxLessons;
    final today = todayIndex(now, n);
    final start = weekStart(now, n);
    final nowIdx = today >= 0 ? currentSlot(slots, now) : null;
    final breaks = breaksOf(slots);
    const timeW = 64.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Column(
            children: [
              Row(
                children: [
                  const SizedBox(width: timeW),
                  for (var i = 0; i < n; i++)
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: i == today ? scheme.primary : cardColor(context),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          children: [
                            Text(
                              i == today ? 'OGGI' : dayNames[i].toUpperCase(),
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: i == today ? scheme.onPrimary : scheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              '${start.add(Duration(days: i)).day}',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                height: 1.1,
                                color: i == today ? scheme.onPrimary : scheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              for (var r = 0; r < rows; r++) ...[
                if (r > 0 && breakAfter(breaks, r - 1) != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Container(
                      margin: const EdgeInsets.only(left: timeW + 3, right: 3),
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest.withAlpha(110),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.local_cafe_outlined, size: 14, color: scheme.onSurfaceVariant),
                          const SizedBox(width: 6),
                          Text(
                            breakAfter(breaks, r - 1)!.label,
                            style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: timeW,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8, top: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${r + 1}ª',
                                  style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                                ),
                                if (r < slots.length && slots[r].start != null) ...[
                                  Text(
                                    slots[r].startText,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: nowIdx == r ? scheme.primary : scheme.onSurface,
                                    ),
                                  ),
                                  Text(
                                    slots[r].endText,
                                    style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        for (var i = 0; i < n; i++)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 3),
                              child: r < week.days[i].lessons.length
                                  ? _GridCell(
                                      lesson: week.days[i].lessons[r],
                                      active: i == today && nowIdx == r,
                                    )
                                  : const SizedBox(),
                            ),
                          ),
                      ],
                    ),
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

class _GridCell extends StatelessWidget {
  const _GridCell({required this.lesson, required this.active});

  final Lesson lesson;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (lesson.isEmpty) {
      return Container(
        constraints: const BoxConstraints(minHeight: 72),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.outlineVariant.withAlpha(140)),
        ),
      );
    }
    final c = SubjectColors.of(lesson.title, theme.brightness);
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: active ? scheme.primary : c.accent.withAlpha(60), width: active ? 2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lesson.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: c.fg, height: 1.2),
          ),
          for (final d in lesson.details.take(2))
            Text(
              d,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(color: c.fg.withAlpha(200)),
            ),
          if (lesson.lab.isNotEmpty || lesson.sostegno.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(spacing: 4, runSpacing: 4, children: lessonTags(lesson, c.fg, dense: true)),
          ],
        ],
      ),
    );
  }
}

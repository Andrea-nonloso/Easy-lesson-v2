import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import 'app_menu.dart';
import 'theme.dart';
import 'widgets.dart';

/// Sceglie con chi confrontare [a] e apre il confronto.
Future<void> openCompare(BuildContext context, ScheduleRef a) async {
  final b = await pickScheduleRef(context, title: 'Confronta ${a.displayName} con…', exclude: a);
  if (b == null || !context.mounted) return;
  await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ComparePage(a: a, b: b)));
}

/// Elenco con ricerca di classi e docenti (prima quelli salvati e recenti).
Future<ScheduleRef?> pickScheduleRef(BuildContext context, {required String title, ScheduleRef? exclude}) {
  final store = StoreScope.read(context);
  final known = [
    if (store.myRef != null) store.myRef!,
    for (final s in [...store.favorites, ...store.recents]) s.ref,
  ];
  final all = [
    for (final c in store.classi) ScheduleRef(c, prof: false),
    for (final d in store.docenti) ScheduleRef(d, prof: true),
  ];
  var q = '';
  return showDialog<ScheduleRef>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setState) {
        final lq = q.trim().toLowerCase();
        final seen = <String>{if (exclude != null) exclude.key};
        final list = <ScheduleRef>[
          for (final r in [...known, ...all])
            if (seen.add(r.key) &&
                (lq.isEmpty ? known.contains(r) : '${r.displayName} ${r.kindLabel}'.toLowerCase().contains(lq)))
              r,
        ];
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 420,
            height: 420,
            child: Column(
              children: [
                TextField(
                  autofocus: true,
                  decoration: const InputDecoration(
                    isDense: true,
                    prefixIcon: Icon(Icons.search_rounded),
                    hintText: 'Classe o docente…',
                  ),
                  onChanged: (v) => setState(() => q = v),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: list.isEmpty
                      ? Center(child: Text(lq.isEmpty ? 'Scrivi per cercare' : 'Nessun risultato'))
                      : ListView(
                          children: [
                            for (final r in list.take(60))
                              ListTile(
                                dense: true,
                                leading: Icon(r.prof ? Icons.person_rounded : Icons.groups_rounded),
                                title: Text(r.displayName),
                                subtitle: Text(r.kindLabel),
                                onTap: () => Navigator.pop(c, r),
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annulla'))],
        );
      },
    ),
  );
}

/// Due orari a confronto, ora per ora: ore libere insieme e ore in cui sono insieme.
class ComparePage extends StatefulWidget {
  const ComparePage({super.key, required this.a, required this.b});

  final ScheduleRef a;
  final ScheduleRef b;

  @override
  State<ComparePage> createState() => _ComparePageState();
}

class _ComparePageState extends State<ComparePage> {
  Object? _error;
  int? _day;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final store = StoreScope.read(context);
    try {
      for (final r in [widget.a, widget.b]) {
        if (store.cached(r) == null) await store.fetchSchedule(r);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  static String _norm(String s) => s.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  /// Le due ore "si incontrano": una nomina l'altro (prof ↔ classe) o due prof nella stessa classe.
  bool _together(Lesson x, Lesson y) {
    if (x.isEmpty || y.isEmpty) return false;
    final an = _norm(widget.a.name);
    final bn = _norm(widget.b.name);
    final an2 = _norm(widget.a.displayName);
    final bn2 = _norm(widget.b.displayName);
    bool mentions(Lesson l, String n, String n2) =>
        l.lines.any((t) => _norm(t).contains(n) || _norm(t).contains(n2));
    if (mentions(x, bn, bn2) || mentions(y, an, an2)) return true;
    if (widget.a.prof && widget.b.prof) return _norm(x.title) == _norm(y.title);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ca = store.cached(widget.a);
    final cb = store.cached(widget.b);

    Widget body;
    if (ca == null || cb == null) {
      body = _error != null
          ? EmptyState(icon: Icons.cloud_off_rounded, title: 'Orario non disponibile', message: '$_error')
          : const Center(child: CircularProgressIndicator());
    } else {
      final days = ca.week.days.length > cb.week.days.length ? ca.week.days.length : cb.week.days.length;
      final today = todayIndex(DateTime.now(), days);
      final day = _day ?? (today >= 0 ? today : 0);
      Lesson at(WeekSchedule w, int d, int h) =>
          d < w.days.length && h < w.days[d].lessons.length ? w.days[d].lessons[h] : Lesson(index: h, text: '', lab: '', sostegno: const []);
      int rowsOf(int d) {
        var n = 0;
        for (final w in [ca.week, cb.week]) {
          if (d < w.days.length && w.days[d].lessons.length > n) n = w.days[d].lessons.length;
        }
        return n;
      }

      var freeWeek = 0;
      var togetherWeek = 0;
      for (var d = 0; d < days; d++) {
        for (var h = 0; h < rowsOf(d); h++) {
          final x = at(ca.week, d, h);
          final y = at(cb.week, d, h);
          if (x.isEmpty && y.isEmpty) freeWeek++;
          if (_together(x, y)) togetherWeek++;
        }
      }

      Widget cell(Lesson l, Color bg) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
            child: Text(
              l.isEmpty ? '—' : [l.title, ...l.details.take(1)].join('\n'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: l.isEmpty ? FontWeight.w400 : FontWeight.w600,
                color: l.isEmpty ? scheme.onSurfaceVariant : scheme.onSurface,
              ),
            ),
          );

      body = ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(avatar: const Text('🟢'), label: Text('$freeWeek ore libere insieme a settimana')),
              Chip(avatar: const Text('🤝'), label: Text('$togetherWeek ore insieme')),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (var d = 0; d < days; d++)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(d < dayShort.length ? dayShort[d] : '${d + 1}'),
                      selected: d == day,
                      onSelected: (_) => setState(() => _day = d),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const SizedBox(width: 56),
              Expanded(child: Text(widget.a.displayName, style: const TextStyle(fontWeight: FontWeight.w700))),
              const SizedBox(width: 8),
              Expanded(child: Text(widget.b.displayName, style: const TextStyle(fontWeight: FontWeight.w700))),
            ],
          ),
          const SizedBox(height: 6),
          for (var h = 0; h < rowsOf(day); h++)
            () {
              final x = at(ca.week, day, h);
              final y = at(cb.week, day, h);
              final both = x.isEmpty && y.isEmpty;
              final together = _together(x, y);
              final bg = both
                  ? Colors.green.withAlpha(40)
                  : together
                      ? scheme.primary.withAlpha(45)
                      : cardColor(context);
              final s = h < store.slots.length ? store.slots[h] : null;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 56,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${h + 1}ª${both ? ' 🟢' : together ? ' 🤝' : ''}',
                                style: const TextStyle(fontWeight: FontWeight.w700)),
                            if (s?.start != null)
                              Text(s!.startText, style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                    ),
                    Expanded(child: cell(x, bg)),
                    const SizedBox(width: 8),
                    Expanded(child: cell(y, bg)),
                  ],
                ),
              );
            }(),
          const SizedBox(height: 8),
          Text(
            '🟢 entrambi liberi · 🤝 insieme (stessa classe o il prof è in quella classe)',
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.a.displayName} ↔ ${widget.b.displayName}', overflow: TextOverflow.ellipsis),
        actions: const [AppMenuButton(), SizedBox(width: 4)],
      ),
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 760), child: body)),
    );
  }
}

import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../log.dart';
import '../models.dart';
import '../store.dart';
import '../updater.dart';
import '../xlsx_write.dart';
import 'color_lab.dart';
import 'deep_dev_page.dart';
import 'dev_tools.dart';
import 'save_file_io.dart' if (dart.library.js_interop) 'save_file_web.dart';
import 'widgets.dart';

void openDevPage(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const DevPage()));

/// Opzioni sviluppatore: si sbloccano toccando 7 volte la foglia nelle impostazioni.
class DevPage extends StatelessWidget {
  const DevPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    Widget tile(IconData icon, String title, String? subtitle, VoidCallback? onTap) => ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon, color: onTap == null ? null : scheme.primary),
          title: Text(title),
          subtitle: subtitle == null ? null : Text(subtitle),
          trailing: onTap == null ? null : const Icon(Icons.chevron_right_rounded),
          onTap: onTap,
          enabled: onTap != null,
        );

    return Scaffold(
      appBar: AppBar(
        // Tieni premuto il titolo: si apre la porta del menu nascosto (serve il PIN).
        title: GestureDetector(
          onLongPress: () => openDeepDevGate(context),
          child: const Text('Opzioni sviluppatore'),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: _grouped(context, [
              const SectionLabel('Diagnostica'),
              ValueListenableBuilder<int>(
                valueListenable: AppLog.revision,
                builder: (context, rev, child) {
                  final errors = AppLog.entries.where((e) => e.level == 'E').length;
                  return tile(
                    Icons.receipt_long_rounded,
                    'Log',
                    '${AppLog.entries.length} righe${errors > 0 ? ' · $errors errori' : ''}',
                    () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const LogPage())),
                  );
                },
              ),
              FutureBuilder<String>(
                future: Updater.currentVersion(),
                builder: (context, snap) => tile(
                  Icons.info_outline_rounded,
                  'Informazioni',
                  'Versione ${snap.data ?? '…'} · ${kIsWeb ? 'web' : defaultTargetPlatform.name}\n'
                      'Tema: ${store.themeId} · ${store.slots.length} ore al giorno · '
                      '${store.favorites.length + store.recents.length} orari in memoria',
                  null,
                ),
              ),
              ...devExtraTiles(context, store, tile),
              const SectionLabel('Excel'),
              tile(
                Icons.grid_on_rounded,
                'Vedi il file Excel',
                store.excelGrid == null
                    ? 'Nessun file importato'
                    : '${store.excelName ?? 'orario.xlsx'} · ${store.excelGrid!.length} righe',
                store.excelGrid == null
                    ? null
                    : () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ExcelViewerPage())),
              ),
              tile(
                Icons.file_download_outlined,
                'Esporta tutto in un .xlsx',
                'Un foglio per ogni orario, in un solo file',
                () => _chooseExport(context),
              ),
              const SectionLabel('Temi'),
              tile(
                Icons.colorize_rounded,
                'Laboratorio colori',
                'HEX, RGB, decimale, tonalità: ogni colore del tuo tema al valore esatto',
                () => openThemeLab(context),
              ),
              const SectionLabel('Altro'),
              tile(
                Icons.lock_outline_rounded,
                'Disattiva opzioni sviluppatore',
                'Si riattivano con 7 tocchi sulla foglia 🍃',
                () {
                  store.setDevMode(false);
                  Navigator.of(context).pop();
                },
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Schede apribili, nell'ordine giusto

/// Ordine e icona delle schede; i nomi a sinistra vengono uniti in quella a destra.
const _devOrder = [
  ('Diagnostica', Icons.monitor_heart_outlined),
  ('Notifiche e widget', Icons.notifications_active_outlined),
  ('Aggiornamenti', Icons.system_update_outlined),
  ('Dati e memoria', Icons.storage_rounded),
  ('Rete', Icons.network_check_rounded),
  ('Interfaccia e temi', Icons.brush_outlined),
  ('Obiettivi e sorprese', Icons.emoji_events_outlined),
  ('Altro', Icons.more_horiz_rounded),
];

const _devMerge = {'Memoria': 'Dati e memoria', 'Excel': 'Dati e memoria', 'Interfaccia': 'Interfaccia e temi', 'Temi': 'Interfaccia e temi'};

/// Trasforma la lista piatta (divisa da SectionLabel) in schede apribili.
List<Widget> _grouped(BuildContext context, List<Widget> flat) {
  final groups = <String, List<Widget>>{};
  var current = 'Diagnostica';
  for (final w in flat) {
    if (w is SectionLabel) {
      current = _devMerge[w.text] ?? w.text;
      continue;
    }
    (groups[current] ??= []).add(w);
  }
  final scheme = Theme.of(context).colorScheme;
  final names = [
    for (final o in _devOrder) if (groups.containsKey(o.$1)) o.$1,
    for (final k in groups.keys) if (!_devOrder.any((o) => o.$1 == k)) k,
  ];
  return [
    for (final name in names)
      Card(
        margin: const EdgeInsets.symmetric(vertical: 5),
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          key: PageStorageKey('dev-$name'),
          initiallyExpanded: name == 'Diagnostica',
          leading: Icon(_devOrder.firstWhere((o) => o.$1 == name, orElse: () => (name, Icons.tune_rounded)).$2,
              color: scheme.primary),
          title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text('${groups[name]!.length} strumenti'),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          children: groups[name]!,
        ),
      ),
  ];
}

// ---------------------------------------------------------------------------
// Esportazione in un solo file Excel

List<List<String>> scheduleRows(WeekSchedule week, List<TimeSlot> slots) {
  final days = week.days.length;
  String cell(Lesson l) => l.isEmpty
      ? ''
      : [
          ...l.lines,
          if (l.lab.isNotEmpty) 'Lab: ${l.lab}',
          if (l.sostegno.isNotEmpty) 'Sostegno: ${l.sostegno.join(', ')}',
        ].join('\n');
  return [
    ['Ora', 'Orario', for (var d = 0; d < days; d++) d < dayNames.length ? dayNames[d] : 'Giorno ${d + 1}'],
    for (var h = 0; h < week.maxLessons; h++)
      [
        '${h + 1}ª',
        h < slots.length && slots[h].start != null ? '${slots[h].startText}-${slots[h].endText}' : '',
        for (var d = 0; d < days; d++) h < week.days[d].lessons.length ? cell(week.days[d].lessons[h]) : '',
      ],
  ];
}

Future<void> _chooseExport(BuildContext context) async {
  final store = StoreScope.read(context);
  final saved = [...store.favorites, ...store.recents];
  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.bookmark_rounded),
            title: const Text('Orari salvati e recenti'),
            subtitle: Text('${saved.length} orari'),
            enabled: saved.isNotEmpty,
            onTap: () => Navigator.pop(c, 'saved'),
          ),
          ListTile(
            leading: const Icon(Icons.groups_rounded),
            title: const Text('Tutte le classi'),
            subtitle: Text(store.usingExcel ? '${store.classi.length} classi dal file Excel' : 'Serve un file Excel importato'),
            enabled: store.usingExcel,
            onTap: () => Navigator.pop(c, 'classi'),
          ),
          ListTile(
            leading: const Icon(Icons.person_rounded),
            title: const Text('Tutti i docenti'),
            subtitle: Text(store.usingExcel ? '${store.docenti.length} docenti dal file Excel' : 'Serve un file Excel importato'),
            enabled: store.usingExcel,
            onTap: () => Navigator.pop(c, 'docenti'),
          ),
          ListTile(
            leading: const Icon(Icons.select_all_rounded),
            title: const Text('Classi e docenti'),
            enabled: store.usingExcel,
            onTap: () => Navigator.pop(c, 'tutto'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (choice == null || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  final sheets = <String, List<List<String>>>{};
  void addRef(ScheduleRef ref) {
    final w = store.excelWeek(ref);
    if (w != null && !w.isEmpty) sheets[ref.displayName] = scheduleRows(w, store.slots);
  }

  if (choice == 'saved') {
    for (final s in saved) {
      sheets[s.ref.displayName] = scheduleRows(s.week, store.slots);
    }
  }
  if (choice == 'classi' || choice == 'tutto') {
    for (final c in store.classi) {
      addRef(ScheduleRef(c, prof: false));
    }
  }
  if (choice == 'docenti' || choice == 'tutto') {
    for (final d in store.docenti) {
      addRef(ScheduleRef(d, prof: true));
    }
  }
  if (sheets.isEmpty) {
    messenger.showSnackBar(const SnackBar(content: Text('Niente da esportare')));
    return;
  }
  try {
    final bytes = writeXlsx(sheets);
    AppLog.i('export', 'xlsx "$choice": ${sheets.length} fogli, ${bytes.length} byte');
    final where = await saveBytesFile(
      'easy_lesson_$choice.xlsx',
      bytes,
      mime: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      title: 'Salva il file Excel',
    );
    if (where == null) return;
    messenger.showSnackBar(SnackBar(
      content: Text(where.isEmpty ? 'File Excel scaricato (${sheets.length} fogli)' : 'Salvato in $where'),
    ));
  } catch (e, st) {
    AppLog.e('export', e, st);
    messenger.showSnackBar(SnackBar(content: Text('Esportazione non riuscita: $e')));
  }
}

// ---------------------------------------------------------------------------
// Log

class LogPage extends StatefulWidget {
  const LogPage({super.key});

  @override
  State<LogPage> createState() => _LogPageState();
}

class _LogPageState extends State<LogPage> {
  String _level = 'tutti'; // 'tutti' | 'W' | 'E'

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log'),
        actions: [
          IconButton(
            tooltip: 'Copia',
            icon: const Icon(Icons.copy_rounded),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: AppLog.dump()));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Log copiato')));
            },
          ),
          IconButton(
            tooltip: 'Salva come file',
            icon: const Icon(Icons.save_alt_rounded),
            onPressed: () => saveTextFile('easy_lesson_log.txt', AppLog.dump()),
          ),
          const IconButton(
            tooltip: 'Svuota',
            icon: Icon(Icons.delete_sweep_outlined),
            onPressed: AppLog.clear,
          ),
        ],
      ),
      body: ValueListenableBuilder<int>(
        valueListenable: AppLog.revision,
        builder: (context, rev, child) {
          final all = AppLog.entries.reversed.toList();
          final shown = switch (_level) {
            'W' => all.where((e) => e.level != 'I').toList(),
            'E' => all.where((e) => e.level == 'E').toList(),
            _ => all,
          };
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'tutti', label: Text('Tutto')),
                    ButtonSegment(value: 'W', label: Text('Avvisi')),
                    ButtonSegment(value: 'E', label: Text('Errori')),
                  ],
                  selected: {_level},
                  onSelectionChanged: (s) => setState(() => _level = s.first),
                ),
              ),
              Expanded(
                child: shown.isEmpty
                    ? const Center(child: Text('Niente da mostrare 🎉'))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: shown.length,
                        separatorBuilder: (context, i) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final e = shown[i];
                          final color = switch (e.level) {
                            'E' => scheme.error,
                            'W' => scheme.tertiary,
                            _ => scheme.onSurfaceVariant,
                          };
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: SelectableText.rich(
                              TextSpan(
                                style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5),
                                children: [
                                  TextSpan(text: '${e.timeText} ', style: TextStyle(color: scheme.onSurfaceVariant)),
                                  TextSpan(
                                    text: '${e.level}/${e.tag} ',
                                    style: TextStyle(color: color, fontWeight: FontWeight.w700),
                                  ),
                                  TextSpan(text: e.message, style: TextStyle(color: scheme.onSurface)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Visualizzatore del file Excel

class ExcelViewerPage extends StatefulWidget {
  const ExcelViewerPage({super.key});

  @override
  State<ExcelViewerPage> createState() => _ExcelViewerPageState();
}

class _ExcelViewerPageState extends State<ExcelViewerPage> {
  final _h = ScrollController();
  String _q = '';

  static const _cellW = 128.0;
  static const _rowH = 46.0;
  static const _indexW = 52.0;

  @override
  void dispose() {
    _h.dispose();
    super.dispose();
  }

  void _showCell(String ref, String value) {
    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Cella $ref'),
        content: SelectableText(value.isEmpty ? '(vuota)' : value),
        actions: [
          TextButton(
            onPressed: () => Clipboard.setData(ClipboardData(text: value)),
            child: const Text('Copia'),
          ),
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Chiudi')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final grid = store.excelGrid ?? const <List<String>>[];
    final scheme = Theme.of(context).colorScheme;
    final cols = grid.fold<int>(0, (m, r) => r.length > m ? r.length : m);
    final q = _q.trim().toLowerCase();
    final rows = <int>[
      for (var r = 0; r < grid.length; r++)
        if (q.isEmpty || grid[r].any((c) => c.toLowerCase().contains(q))) r,
    ];
    final line = scheme.outlineVariant.withAlpha(120);

    Widget box(Widget child, {double w = _cellW, Color? bg, VoidCallback? onTap}) => InkWell(
          onTap: onTap,
          child: Container(
            width: w,
            height: _rowH,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: bg,
              border: Border(right: BorderSide(color: line), bottom: BorderSide(color: line)),
            ),
            child: child,
          ),
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(store.excelName ?? 'File Excel'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: TextField(
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: 'Cerca nel file… (${rows.length} righe)',
              ),
              onChanged: (v) => setState(() => _q = v),
            ),
          ),
        ),
      ),
      body: Scrollbar(
        controller: _h,
        child: SingleChildScrollView(
          controller: _h,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: _indexW + cols * _cellW,
            child: Column(
              children: [
                Row(
                  children: [
                    box(const SizedBox(), w: _indexW, bg: scheme.surfaceContainerHighest),
                    for (var c = 0; c < cols; c++)
                      box(
                        Center(child: Text(colName(c), style: const TextStyle(fontWeight: FontWeight.w700))),
                        bg: scheme.surfaceContainerHighest,
                      ),
                  ],
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: rows.length,
                    itemExtent: _rowH,
                    itemBuilder: (context, i) {
                      final r = rows[i];
                      final row = grid[r];
                      return Row(
                        children: [
                          box(
                            Text('${r + 1}', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
                            w: _indexW,
                            bg: scheme.surfaceContainerHigh,
                          ),
                          for (var c = 0; c < cols; c++)
                            () {
                              final v = c < row.length ? row[c] : '';
                              final hit = q.isNotEmpty && v.toLowerCase().contains(q);
                              return box(
                                Text(
                                  v,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12, height: 1.15),
                                ),
                                bg: hit ? scheme.primaryContainer : null,
                                onTap: () => _showCell('${colName(c)}${r + 1}', v),
                              );
                            }(),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import 'app_menu.dart';
import 'schedule_screen.dart';
import 'settings_sheet.dart';
import 'theme.dart';
import 'widgets.dart';
import '../i18n.dart';

void openSchedule(BuildContext context, ScheduleRef ref) {
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ScheduleScreen(ref: ref)));
}

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _ctrl = TextEditingController();
  bool _prof = false;
  String _q = '';

  /// Docenti: cerca e raggruppa per nome (false) o per materia (true).
  bool _bySubject = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit(List<String> results) {
    if (results.length == 1) openSchedule(context, ScheduleRef(results.first, prof: _prof));
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final theme = Theme.of(context);
    final source = _prof ? store.docenti : store.classi;
    final q = normalizeSearch(_q);
    final bySubject = _prof && _bySubject;
    String key(String s) => bySubject ? normalizeSearch(teacherSubject(s) ?? 'altro') : normalizeSearch(s);
    final results = q.isEmpty ? source : source.where((s) => key(s).contains(q)).toList();
    final recents = [...store.favorites, ...store.recents].take(10).toList();

    Widget content;
    if (source.isEmpty) {
      if (store.listsLoading) {
        content = const Center(child: CircularProgressIndicator());
      } else {
        content = EmptyState(
          icon: Icons.wifi_off_rounded,
          title: tr('Elenchi non disponibili', 'Lists not available'),
          message: store.listsError != null
              ? tr('${store.listsError}. Serve la connessione la prima volta.', '${store.listsError}. A connection is needed the first time.')
              : tr('Nessun elemento trovato.', 'Nothing found.'),
          action: Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: () => store.refreshLists(),
                icon: const Icon(Icons.refresh_rounded),
                label: Text(tr('Riprova', 'Try again')),
              ),
              OutlinedButton.icon(
                onPressed: () => pickAndImportExcel(context),
                icon: const Icon(Icons.upload_file_rounded),
                label: Text(tr('Importa orario Excel', 'Import Excel timetable')),
              ),
            ],
          ),
        );
      }
    } else if (results.isEmpty) {
      content = EmptyState(
        icon: Icons.search_off_rounded,
        title: tr('Nessun risultato', 'No results'),
        message: bySubject
            ? tr('Nessuna materia corrisponde a "$_q".', 'No subject matches "$_q".')
            : _prof ? tr('Nessun docente corrisponde a "$_q".', 'No teacher matches "$_q".') : tr('Nessuna classe corrisponde a "$_q".', 'No class matches "$_q".'),
      );
    } else {
      content = _prof
          ? _TeacherList(
              names: results,
              bySubject: bySubject,
              onOpen: (n) => openSchedule(context, ScheduleRef(n, prof: true)),
            )
          : _ClassGrid(names: results, onOpen: (n) => openSchedule(context, ScheduleRef(n, prof: false)));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Cerca orario', 'Search timetable')),
        actions: [
          AppMenuButton(items: [
            AppMenuItem(Icons.sync_rounded, tr('Aggiorna elenchi', 'Update lists'), () => store.refreshLists()),
            AppMenuItem(Icons.upload_file_rounded, tr('Importa file Excel', 'Import Excel file'), () => pickAndImportExcel(context)),
          ]),
          const SizedBox(width: 4),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<bool>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(value: false, icon: const Icon(Icons.groups_outlined), label: Text(tr('Classi', 'Classes'))),
                      ButtonSegment(value: true, icon: const Icon(Icons.person_outline_rounded), label: Text(tr('Docenti', 'Teachers'))),
                    ],
                    selected: {_prof},
                    onSelectionChanged: (s) => setState(() => _prof = s.first),
                  ),
                ),
              ),
              if (_prof)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Row(
                    children: [
                      Text(
                        tr('Cerca per', 'Search by'),
                        style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(width: 10),
                      ChoiceChip(
                        avatar: const Icon(Icons.badge_outlined, size: 18),
                        label: Text(tr('Nome', 'Name')),
                        selected: !_bySubject,
                        showCheckmark: false,
                        onSelected: (_) => setState(() => _bySubject = false),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        avatar: const Icon(Icons.menu_book_outlined, size: 18),
                        label: Text(tr('Materia', 'Subject')),
                        selected: _bySubject,
                        showCheckmark: false,
                        onSelected: (_) => setState(() => _bySubject = true),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: TextField(
                  controller: _ctrl,
                  onChanged: (v) => setState(() => _q = v),
                  onSubmitted: (_) => _submit(results),
                  textInputAction: TextInputAction.search,
                  textCapitalization: TextCapitalization.characters,
                  autocorrect: false,
                  decoration: InputDecoration(
                    hintText: !_prof
                        ? tr('Cerca una classe, es. 3A', 'Search for a class, e.g. 3A')
                        : (_bySubject ? tr('Cerca una materia, es. Matematica', 'Search for a subject, e.g. Maths') : tr('Cerca un docente…', 'Search for a teacher…')),
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _q.isEmpty
                        ? null
                        : IconButton(
                            tooltip: tr('Cancella', 'Delete'),
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () {
                              _ctrl.clear();
                              setState(() => _q = '');
                            },
                          ),
                  ),
                ),
              ),
              if (_q.isEmpty && recents.isNotEmpty)
                SizedBox(
                  height: 52,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    itemCount: recents.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final r = recents[i].ref;
                      return ActionChip(
                        avatar: Icon(
                          recents[i].favorite
                              ? Icons.bookmark_rounded
                              : (r.prof ? Icons.person_outline_rounded : Icons.history_rounded),
                          size: 18,
                        ),
                        label: Text(r.displayName),
                        onPressed: () => openSchedule(context, r),
                      );
                    },
                  ),
                ),
              if (store.listsLoading && source.isNotEmpty) const LinearProgressIndicator(minHeight: 2),
              Expanded(child: content),
              if (source.isNotEmpty && (store.usingExcel || store.listsUpdatedAt != null))
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    store.usingExcel
                        ? 'Dal file ${store.excelName ?? 'Excel'}'
                        : '${tr('Elenchi aggiornati', 'Lists updated')} ${relativeTime(store.listsUpdatedAt!)}',
                    style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClassGrid extends StatelessWidget {
  const _ClassGrid({required this.names, required this.onOpen});

  final List<String> names;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<String>>{};
    for (final n in names) {
      final y = RegExp(r'^\d+').firstMatch(n.trim())?.group(0);
      groups.putIfAbsent(y == null ? '' : '$yª', () => []).add(n);
    }
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        for (final e in groups.entries) ...[
          SectionLabel(e.key.isEmpty ? tr('Altre', 'Others') : '${tr('Classi', 'Classes')} ${e.key}'),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final n in e.value)
                Builder(builder: (context) {
                  final c = SubjectColors.of(e.key, theme.brightness);
                  return Material(
                    color: c.bg,
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => onOpen(n),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 78, minHeight: 60),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          // widthFactor/heightFactor: il riquadro resta grande quanto il testo
                          child: Center(
                            widthFactor: 1,
                            heightFactor: 1,
                            child: Text(
                              n.toUpperCase(),
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: c.fg),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
            ],
          ),
        ],
      ],
    );
  }
}

class _TeacherList extends StatelessWidget {
  const _TeacherList({required this.names, required this.onOpen, this.bySubject = false});

  final List<String> names;
  final ValueChanged<String> onOpen;

  /// true = raggruppati per materia (A-Z delle materie), false = per iniziale del cognome.
  final bool bySubject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Lista piatta con intestazioni (iniziale del cognome oppure materia).
    String group(String n) {
      if (bySubject) return teacherSubject(n) ?? tr('Sostegno e altri', 'Support and others');
      final label = teacherLabel(n);
      return label.isEmpty ? '#' : label[0].toUpperCase();
    }

    final sorted = [...names];
    if (bySubject) {
      sorted.sort((a, b) {
        final ga = group(a), gb = group(b);
        // "Sostegno e altri" in fondo
        final oa = teacherSubject(a) == null ? 1 : 0, ob = teacherSubject(b) == null ? 1 : 0;
        if (oa != ob) return oa - ob;
        final c = ga.toLowerCase().compareTo(gb.toLowerCase());
        return c != 0 ? c : teacherLabel(a).toLowerCase().compareTo(teacherLabel(b).toLowerCase());
      });
    }
    final items = <Object>[];
    String? current;
    for (final n in sorted) {
      final g = group(n);
      if (g != current) {
        items.add(g);
        current = g;
      }
      items.add(_Name(n));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final it = items[i];
        if (it is String) return SectionLabel(it);
        final n = (it as _Name).value;
        final c = SubjectColors.of(teacherSubject(n) ?? n, theme.brightness);
        final label = teacherLabel(n);
        final subject = teacherSubject(n);
        final initials = label
            .split(RegExp(r'\s+'))
            .where((p) => p.isNotEmpty)
            .take(2)
            .map((p) => p[0].toUpperCase())
            .join();
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Material(
            color: cardColor(context),
            borderRadius: BorderRadius.circular(16),
            child: ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              leading: CircleAvatar(
                backgroundColor: c.bg,
                foregroundColor: c.fg,
                child: Text(initials, style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
              subtitle: subject == null ? null : Text(subject),
              trailing: Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
              onTap: () => onOpen(n),
            ),
          ),
        );
      },
    );
  }
}

class _Name {
  const _Name(this.value);
  final String value;
}

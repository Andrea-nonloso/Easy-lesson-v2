import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../timetable.dart';
import 'app_menu.dart';
import 'fun.dart';
import 'search_page.dart';
import 'settings_sheet.dart';
import 'widgets.dart';
import '../i18n.dart';

/// [labs] = apre direttamente la scheda dei laboratori liberi.
void openNowAtSchool(BuildContext context, {bool labs = false}) => Navigator.of(context)
    .push(MaterialPageRoute<void>(builder: (_) => NowAtSchoolPage(initialTab: labs ? 1 : 0)));

/// "Adesso a scuola": dov'è ogni docente e quali laboratori sono liberi,
/// in un'ora qualsiasi della settimana. Funziona con il file Excel importato.
class NowAtSchoolPage extends StatefulWidget {
  const NowAtSchoolPage({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<NowAtSchoolPage> createState() => _NowAtSchoolPageState();
}

class _NowAtSchoolPageState extends State<NowAtSchoolPage> {
  int? _day;
  int? _hour;
  String _q = '';
  String _qc = '';
  String _filter = 'tutti'; // 'tutti' | 'classe' | 'liberi'

  /// Giorno e ora di partenza: adesso, oppure la prossima ora di lezione.
  void _initTime(Timetable tt, List<TimeSlot> slots) {
    if (_day != null) return;
    final now = DateTime.now();
    final m = now.hour * 60 + now.minute;
    var d = now.weekday - 1;
    var h = 0;
    if (d >= tt.days) {
      d = 0; // fine settimana: lunedì, prima ora
    } else {
      final cur = currentSlot(slots, now);
      if (cur != null) {
        h = cur;
      } else {
        final next = [for (var k = 0; k < slots.length && k < tt.hours; k++) if ((slots[k].start ?? 0) > m) k];
        if (next.isNotEmpty) {
          h = next.first;
        } else if (slots.isNotEmpty && m > (slots.first.start ?? 0)) {
          d = (d + 1) % tt.days; // giornata finita: domani alla prima ora
        }
      }
    }
    _day = d;
    _hour = h.clamp(0, tt.hours - 1);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final tt = store.timetable;
    if (tt == null) {
      return Scaffold(
        appBar: AppBar(title: Text(tr('Adesso a scuola', 'At school now'))),
        body: EmptyState(
          icon: Icons.table_view_rounded,
          title: tr('Serve il file Excel', 'The Excel file is needed'),
          message: tr('Per sapere dove sono i docenti e quali laboratori sono liberi, '
              'importa il file dell\'orario della scuola.', 'To know where teachers are and which labs are free, import the school\'s timetable file.'),
          action: FilledButton.icon(
            onPressed: () => pickAndImportExcel(context),
            icon: const Icon(Icons.upload_file_rounded),
            label: Text(tr('Importa file Excel', 'Import Excel file')),
          ),
        ),
      );
    }
    _initTime(tt, store.slots);
    final day = _day!;
    final hour = _hour!;
    final slot = hour < store.slots.length ? store.slots[hour] : null;

    return DefaultTabController(
      length: 3,
      initialIndex: widget.initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr('Adesso a scuola', 'At school now')),
          actions: const [AppMenuButton(), SizedBox(width: 4)],
          bottom: TabBar(tabs: [
            Tab(icon: const Icon(Icons.person_search_rounded), text: tr('Dov\'è il prof', 'Where\'s the teacher')),
            Tab(icon: const Icon(Icons.science_outlined), text: tr('Laboratori', 'Labs')),
            Tab(icon: const Icon(Icons.groups_outlined), text: tr('Classi', 'Classes')),
          ]),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              children: [
                // Scelta del giorno e dell'ora
                SizedBox(
                  height: 48,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    children: [
                      for (var d = 0; d < tt.days; d++)
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
                SizedBox(
                  height: 48,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                    children: [
                      for (var h = 0; h < tt.hours; h++)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(h < store.slots.length && store.slots[h].start != null
                                ? '${h + 1}ª · ${store.slots[h].startText}'
                                : '${h + 1}ª'),
                            selected: h == hour,
                            onSelected: (_) => setState(() => _hour = h),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Text(
                    '${day < dayNames.length ? dayNames[day] : ''}, ${tr('${hour + 1}ª ora', 'period ${hour + 1}')}'
                    '${slot?.start != null ? ' (${slot!.startText}–${slot.endText})' : ''}',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _teachers(context, store, tt, day, hour),
                      _labs(context, store, tt, day, hour),
                      _classes(context, store, tt, day, hour),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _hourText(AppStore store, int h) =>
      h < store.slots.length && store.slots[h].start != null ? '${h + 1}ª (${store.slots[h].startText})' : '${h + 1}ª';

  Widget _teachers(BuildContext context, AppStore store, Timetable tt, int day, int hour) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final q = _q.trim().toLowerCase();
    final rows = <Widget>[];
    for (final t in tt.docenti) {
      if (q.isNotEmpty &&
          !teacherLabel(t).toLowerCase().contains(q) &&
          !(teacherSubject(t)?.toLowerCase().contains(q) ?? false)) {
        continue;
      }
      final at = tt.teacherAt(t, day, hour);
      final inClass = at.classes.isNotEmpty;
      if (_filter == 'classe' && !inClass) continue;
      final hours = tt.teacherHours(t, day);
      final atSchool = hours.isNotEmpty && hours.first < hour && hours.last > hour;
      if (_filter == 'liberi' && (inClass || !atSchool)) continue;

      String status;
      Color color;
      if (inClass) {
        status = '📍 ${at.classes.join(' + ')}'
            '${at.labs.isNotEmpty ? ' · ${at.labs.map((l) => '${labInfo(l).emoji} $l').join(', ')}' : ''}';
        var lastBlock = hour;
        while (hours.contains(lastBlock + 1)) {
          lastBlock++;
        }
        if (lastBlock == hours.last) status += tr(' · finisce alla ${lastBlock + 1}ª', ' · ends after period ${lastBlock + 1}');
        color = scheme.primary;
      } else if (hours.isEmpty) {
        status = tr('Oggi non ha lezione', 'No lessons today');
        color = scheme.onSurfaceVariant;
      } else {
        final next = hours.where((h) => h > hour).toList();
        if (next.isNotEmpty) {
          final where = tt.teacherAt(t, day, next.first).classes.join(' + ');
          status = '${atSchool ? 'Ora buca' : 'Non ancora a scuola'} · poi ${_hourText(store, next.first)} in $where';
        } else {
          status = tr('Ha finito alla ${hours.last + 1}ª', 'Finished after period ${hours.last + 1}');
        }
        color = atSchool ? scheme.tertiary : scheme.onSurfaceVariant;
      }

      rows.add(ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        leading: CircleAvatar(
          backgroundColor: inClass ? scheme.primaryContainer : scheme.surfaceContainerHighest,
          child: Icon(inClass ? Icons.co_present_rounded : Icons.person_outline_rounded,
              color: inClass ? scheme.onPrimaryContainer : scheme.onSurfaceVariant, size: 20),
        ),
        title: Text(teacherLabel(t), style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          [if (teacherSubject(t) != null) teacherSubject(t)!, status].join('\n'),
          style: TextStyle(color: color),
        ),
        isThreeLine: teacherSubject(t) != null,
        onTap: () => openSchedule(context, ScheduleRef(t, prof: true)),
      ));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: TextField(
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: tr('Cerca per nome o materia…', 'Search by name or subject…'),
            ),
            onChanged: (v) => setState(() => _q = v),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              for (final f in [('tutti', tr('Tutti', 'All')), ('classe', tr('In classe', 'In class')), ('liberi', tr('Ora buca', 'Free period'))])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(f.$2),
                    selected: _filter == f.$1,
                    onSelected: (_) => setState(() => _filter = f.$1),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: rows.isEmpty
              ? EmptyState(icon: Icons.person_off_outlined, title: tr('Nessun docente', 'No teachers'), message: tr('Prova a cambiare filtro o ricerca.', 'Try changing the filter or search.'))
              : ListView(padding: const EdgeInsets.fromLTRB(12, 4, 12, 24), children: rows),
        ),
      ],
    );
  }

  Widget _classes(BuildContext context, AppStore store, Timetable tt, int day, int hour) {
    final scheme = Theme.of(context).colorScheme;
    final q = _qc.trim().toLowerCase();
    final names = [...tt.classi]..sort(compareClassi);
    final rows = <Widget>[];
    for (final c in names) {
      if (q.isNotEmpty && !c.toLowerCase().contains(q)) continue;
      final at = tt.classAt(c, day, hour);
      final busy = at.subject != null || at.labs.isNotEmpty;
      final place = at.labs.isNotEmpty
          ? at.labs.map((l) => '${labInfo(l).emoji} $l').join(', ')
          : (busy ? tr('🏫 In aula', '🏫 In the classroom') : '');
      rows.add(ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        leading: CircleAvatar(
          backgroundColor: at.labs.isNotEmpty ? scheme.tertiaryContainer : scheme.surfaceContainerHighest,
          child: Text(
            c.split(' ').first,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: at.labs.isNotEmpty ? scheme.onTertiaryContainer : scheme.onSurfaceVariant,
            ),
          ),
        ),
        title: Text(c, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          busy
              ? '$place${at.subject != null ? ' · ${at.subject}' : ''}'
                  '${at.teachers.isNotEmpty ? '\n${at.teachers.map(teacherLabel).join(' · ')}' : ''}'
              : tr('Nessuna lezione a quest\'ora', 'No lessons at this time'),
          style: TextStyle(color: busy ? scheme.onSurface : scheme.onSurfaceVariant),
        ),
        isThreeLine: busy && at.teachers.isNotEmpty,
        onTap: () => openSchedule(context, ScheduleRef(c, prof: false)),
      ));
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: TextField(
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: tr('Cerca una classe… (es. 3B)', 'Search for a class… (e.g. 3B)'),
            ),
            onChanged: (v) => setState(() => _qc = v),
          ),
        ),
        Expanded(
          child: rows.isEmpty
              ? EmptyState(icon: Icons.groups_outlined, title: tr('Nessuna classe', 'No classes'), message: tr('Prova un\'altra ricerca.', 'Try another search.'))
              : ListView(padding: const EdgeInsets.fromLTRB(12, 4, 12, 24), children: rows),
        ),
      ],
    );
  }

  Widget _labs(BuildContext context, AppStore store, Timetable tt, int day, int hour) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (tt.labs.isEmpty) {
      return EmptyState(
        icon: Icons.science_outlined,
        title: tr('Nessun laboratorio', 'No labs'),
        message: tr('Il file Excel non ha la sezione dei laboratori.', 'The Excel file has no labs section.'),
      );
    }
    final free = <Widget>[];
    final busy = <Widget>[];
    for (final lab in tt.labs) {
      final use = tt.labUse(lab, day, hour);
      final info = labInfo(lab);
      if (use.isEmpty) {
        var until = hour;
        while (until + 1 < tt.hours && tt.labUse(lab, day, until + 1).isEmpty) {
          until++;
        }
        final rest = until + 1 >= tt.hours;
        free.add(ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          leading: Text(info.emoji, style: const TextStyle(fontSize: 26)),
          title: Text(lab, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(
            rest ? tr('Libero per il resto della giornata', 'Free for the rest of the day') : tr('Libero fino alla fine della ${until + 1}ª ora', 'Free until the end of period ${until + 1}'),
            style: TextStyle(color: scheme.primary),
          ),
        ));
      } else {
        busy.add(ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          leading: Opacity(opacity: 0.55, child: Text(info.emoji, style: const TextStyle(fontSize: 26))),
          title: Text(lab),
          subtitle: Text('${tr('Occupato', 'In use')} · ${use.join(' + ')}', style: TextStyle(color: scheme.onSurfaceVariant)),
          onTap: () => openSchedule(context, ScheduleRef(use.first, prof: false)),
        ));
      }
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      children: [
        SectionLabel('${tr('Liberi', 'Free')} (${free.length})'),
        ...free,
        SectionLabel('Occupati (${busy.length})'),
        ...busy,
      ],
    );
  }
}

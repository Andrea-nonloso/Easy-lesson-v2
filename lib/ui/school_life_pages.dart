import 'dart:async';

import 'package:flutter/material.dart';

import '../agenda.dart';
import '../models.dart';
import '../live.dart';
import '../native.dart';
import '../school_extra.dart';
import '../school_life.dart';
import '../social.dart';
import '../store.dart';
import 'agenda_page.dart' show mySubjects;
import 'desktop.dart';
import 'more_pages.dart' show openCharts, openCredits;
import 'register_import_page.dart';
import 'report_pdf.dart';
import 'widgets.dart';
import '../i18n.dart';

void openAbsences(BuildContext context) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AbsencesPage()));

void openGrades(BuildContext context) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const GradesPage()));

void openStudyTimer(BuildContext context, {String? subject}) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => StudyTimerPage(subject: subject)));

String _date(DateTime d) => '${dayShort[d.weekday - 1]} ${d.day}/${d.month}';

Widget _body(List<Widget> children) => Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 96), children: children),
      ),
    );

Future<DateTime?> _pickDate(BuildContext context, DateTime initial) => showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(initial.year - 1, 9, 1),
      lastDate: DateTime(initial.year + 1, 8, 31),
    );

// ---------------------------------------------------------------------------
// Assenze, entrate e uscite

/// Dialogo "segna assenza / entrata / uscita". [kind] preimpostato.
Future<void> addAbsenceDialog(BuildContext context, {String kind = 'assenza', DateTime? date}) async {
  final store = StoreScope.read(context);
  final now = DateTime.now();
  var day = date ?? (kind == 'assenza' ? now : store.nextSchoolDay(now) ?? now);
  var k = kind;
  var hour = k == 'uscita' ? 4 : 2;
  final note = TextEditingController();
  final maxHours = store.myScheduleOn(day)?.week.maxLessons ?? 7;
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setState) => AlertDialog(
        title: Text(tr('Assenze e permessi', 'Absences and permits')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'assenza', label: Text(tr('Assente', 'Absent'))),
                  ButtonSegment(value: 'entrata', label: Text(tr('Entro dopo', 'Late entry'))),
                  ButtonSegment(value: 'uscita', label: Text(tr('Esco prima', 'Early exit'))),
                ],
                selected: {k},
                onSelectionChanged: (s) => setState(() {
                  k = s.first;
                  hour = k == 'uscita' ? 4 : 2;
                }),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.event_rounded),
                label: Text('${dayNames[day.weekday - 1]} ${day.day}/${day.month}/${day.year}'),
                onPressed: () async {
                  final d = await _pickDate(c, day);
                  if (d != null) setState(() => day = d);
                },
              ),
              if (k != 'assenza') ...[
                const SizedBox(height: 12),
                Text(k == 'entrata' ? tr('Entro alla…', 'I come in at…') : tr('Esco dopo la…', 'I leave after…')),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (var h = k == 'entrata' ? 2 : 1; h <= (k == 'entrata' ? maxHours : maxHours - 1); h++)
                      ChoiceChip(label: Text(tr('$hª ora', 'Period $h')), selected: hour == h, onSelected: (_) => setState(() => hour = h)),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              TextField(controller: note, decoration: InputDecoration(labelText: tr('Nota (facoltativa)', 'Note (optional)'))),
              if (!dateOnly(day).isBefore(dateOnly(now))) ...[
                const SizedBox(height: 12),
                Text(
                  k == 'assenza'
                      ? tr('Quel giorno niente notifiche delle lezioni né silenzioso.',
                          'That day no lesson notifications and no silent mode.')
                      : tr('Widget, notifiche e riepilogo della sera terranno conto dell\'orario.',
                          'Widget, notifications and evening summary will take the timetable into account.'),
                  style: Theme.of(c).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('Annulla', 'Cancel'))),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(tr('Salva', 'Save'))),
        ],
      ),
    ),
  );
  if (ok == true) await store.addAbsence(date: day, kind: k, hour: hour, note: note.text);
}

class AbsencesPage extends StatelessWidget {
  const AbsencesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ref = store.myMainRef;
    final week = ref == null ? null : store.cached(ref)?.week;
    final now = DateTime.now();
    final today = dateOnly(now);
    final stats = week == null ? null : absenceStats(store.absences, week, now);
    final mode = store.opt('periods', 'tri');
    final view = store.opt('absences.view', 0);
    final kindFilter = store.opt('absences.kind', '');
    final inView = store.absences.where((a) => view == 0 || gradePeriod(a.date, mode: mode) == view).toList();
    final shown = inView.where((a) => kindFilter.isEmpty || a.kind == kindFilter).toList()..sort((a, b) => b.date.compareTo(a.date));
    int count(String k) => inView.where((a) => a.kind == k && !a.date.isAfter(today)).length;

    Color level(double r) => r >= 0.2 ? scheme.error : (r >= 0.15 ? Colors.orange : scheme.primary);
    final accent = stats == null ? scheme.primary : level(stats.ratio);
    void setKind(String k) => store.setOpt('absences.kind', k.isEmpty || k == kindFilter ? null : k);

    Widget entry(AbsenceEntry a) {
      final color = _absenceColor(scheme, a.kind);
      final planned = a.date.isAfter(today);
      return Dismissible(
        key: ValueKey(a.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          margin: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(color: scheme.errorContainer, borderRadius: BorderRadius.circular(18)),
          child: Icon(Icons.delete_outline_rounded, color: scheme.onErrorContainer),
        ),
        onDismissed: (_) => store.removeAbsence(a),
        child: _RecordCard(
          badge: _Badge(_absenceLetter(a.kind), color),
          date: '${_fullDate(a.date)}${planned ? tr(' · in programma', ' · planned') : ''}',
          dateColor: color,
          children: [
            Text(_absenceTitle(a.kind), style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(switch (a.kind) {
              'entrata' => tr('Entra alla ${a.hour}ª ora', 'Comes in at period ${a.hour}'),
              'uscita' => tr('Esce dopo la ${a.hour}ª ora', 'Leaves after period ${a.hour}'),
              _ => tr('Tutto il giorno', 'All day'),
            }),
            if (a.note.isNotEmpty) _labelled(context, tr('Nota', 'Note'), a.note),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Assenze e permessi', 'Absences and permits')),
        actions: [
          // Importa dal registro incollando il testo degli screenshot (beta, per tutti dalla 3.6).
          IconButton(
            tooltip: tr('Incolla dal registro (beta)', 'Paste from the register (beta)'),
            icon: const Icon(Icons.document_scanner_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const RegisterImportPage())),
          ),
          PopupMenuButton<String>(
            onSelected: (k) => addAbsenceDialog(context, kind: k),
            itemBuilder: (_) => [
              PopupMenuItem(value: 'entrata', child: Text(tr('⏰ Domani entro dopo', '⏰ Late entry tomorrow'))),
              PopupMenuItem(value: 'uscita', child: Text(tr('🚪 Domani esco prima', '🚪 Early exit tomorrow'))),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => addAbsenceDialog(context),
        icon: const Icon(Icons.add_rounded),
        label: Text(tr('Segna', 'Mark')),
      ),
      body: _body([
        // Riquadro della percentuale, come sul registro.
        Card(
          color: Color.alphaBlend(accent.withAlpha(46), scheme.surfaceContainerHigh),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(tr('Percentuale assenze totali', 'Total absence rate'),
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    ),
                    _Badge(stats == null ? '—' : '${(stats.ratio * 100).toStringAsFixed(1)}%', accent, size: 60),
                  ],
                ),
                if (stats == null)
                  Text(tr('Imposta "il mio orario" per contare le ore perse.', 'Set "my timetable" to count the hours missed.'),
                      style: TextStyle(color: scheme.onSurfaceVariant))
                else ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: (stats.ratio / absenceLimit).clamp(0.0, 1.0),
                      minHeight: 8,
                      color: accent,
                      backgroundColor: scheme.surface.withAlpha(120),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    stats.left > 0
                        ? tr('${stats.lost} ore perse su ${stats.limitHours} · puoi perderne ancora ${stats.left}',
                            '${stats.lost} hours missed out of ${stats.limitHours} · you can still miss ${stats.left}')
                        : tr('⚠️ Hai superato il limite: parlane con il coordinatore (ci sono deroghe per motivi di salute)',
                            '⚠️ You\'ve gone over the limit: talk to the coordinator (there are exceptions for health reasons)'),
                    style: TextStyle(color: stats.left > 0 ? scheme.onSurfaceVariant : accent, fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
          ),
        ),
        _Picker<int>(
          value: view,
          accent: accent,
          items: [
            (0, tr('Tutto l\'anno', 'Whole year')),
            (1, periodName(1, mode: mode)),
            (2, periodName(2, mode: mode)),
          ],
          onChanged: (v) => store.setOpt('absences.view', v == 0 ? null : v),
        ),
        _Picker<String>(
          value: kindFilter,
          accent: accent,
          items: [
            ('', tr('Tutti i tipi', 'All kinds')),
            for (final k in AbsenceEntry.kinds) (k, _absenceTitle(k)),
          ],
          onChanged: setKind,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            for (final k in AbsenceEntry.kinds) ...[
              if (k != AbsenceEntry.kinds.first) const SizedBox(width: 10),
              Expanded(
                child: _Counter(
                  label: _absenceShort(k),
                  value: count(k),
                  color: _absenceColor(scheme, k),
                  selected: kindFilter == k,
                  onTap: () => setKind(k),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              store.absences.isEmpty
                  ? tr('Nessuna assenza. Grande! 💪', 'No absences. Great! 💪')
                  : tr('Niente in questo periodo.', 'Nothing in this period.'),
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
        for (final a in shown) entry(a),
        if (stats != null && stats.bySubject.isNotEmpty)
          Card(
            margin: const EdgeInsets.only(top: 12),
            clipBehavior: Clip.antiAlias,
            child: ExpansionTile(
              shape: const Border(),
              title: Text(tr('Ore perse per materia', 'Hours missed by subject'), style: const TextStyle(fontWeight: FontWeight.w600)),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              children: [
                for (final e in (stats.bySubject.entries.toList()..sort((a, b) => b.value.compareTo(a.value))))
                  Builder(builder: (context) {
                    final year = AbsenceStats.subjectYearHours(week!, e.key);
                    final r = year == 0 ? 0.0 : e.value / year;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(e.key),
                      subtitle: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(value: (r / absenceLimit).clamp(0.0, 1.0), color: level(r)),
                      ),
                      trailing: Text('${e.value}/$year h'),
                    );
                  }),
              ],
            ),
          ),
        const SizedBox(height: 12),
        Text(
          tr(
              'Il conto è una stima: $schoolWeeks settimane di lezione con il tuo orario attuale. '
                  'Il numero ufficiale è quello del registro elettronico.',
              'The count is an estimate: $schoolWeeks weeks of lessons with your current timetable. The official number is the one in the electronic register.'),
          style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ]),
    );
  }
}

Color _absenceColor(ColorScheme scheme, String kind) => switch (kind) {
      'entrata' => scheme.tertiary,
      'uscita' => scheme.primary,
      _ => scheme.error,
    };

String _absenceLetter(String kind) => switch (kind) {
      'entrata' => tr('E', 'L'),
      'uscita' => tr('U', 'E'),
      _ => 'A',
    };

String _absenceTitle(String kind) => switch (kind) {
      'entrata' => tr('Entrata in ritardo', 'Late entry'),
      'uscita' => tr('Uscita anticipata', 'Early exit'),
      _ => tr('Assenza', 'Absence'),
    };

String _absenceShort(String kind) => switch (kind) {
      'entrata' => tr('Entrate', 'Late'),
      'uscita' => tr('Uscite', 'Early'),
      _ => tr('Assenze', 'Absences'),
    };

// ---------------------------------------------------------------------------
// Pezzi in comune tra Voti e Assenze (layout a card, come sul registro)

String _fullDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// "Etichetta: testo", con l'etichetta nel colore del tema.
Widget _labelled(BuildContext context, String label, String text) => Text.rich(
      TextSpan(children: [
        TextSpan(text: '$label: ', style: TextStyle(fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.primary)),
        TextSpan(text: text),
      ]),
    );

/// Menu a tendina a tutta larghezza; il bordo si colora quando è scelto qualcosa.
class _Picker<T> extends StatelessWidget {
  const _Picker({required this.value, required this.items, required this.onChanged, this.accent});
  final T value;
  final List<(T, String)> items;
  final ValueChanged<T> onChanged;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = accent ?? scheme.primary;
    final active = value != items.first.$1;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: active ? color : Colors.transparent, width: 1.5),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            isExpanded: true,
            borderRadius: BorderRadius.circular(14),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            icon: Icon(Icons.keyboard_arrow_down_rounded, color: color),
            items: [
              for (final (v, label) in items) DropdownMenuItem(value: v, child: Text(label, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ),
      ),
    );
  }
}

/// Bollino tondo pieno con il voto o la lettera.
class _Badge extends StatelessWidget {
  const _Badge(this.text, this.color, {this.size = 52});
  final String text;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final onColor = ThemeData.estimateBrightnessForColor(color) == Brightness.dark ? Colors.white : Colors.black87;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: FittedBox(
          child: Text(text, style: TextStyle(color: onColor, fontWeight: FontWeight.w800, fontSize: 20)),
        ),
      ),
    );
  }
}

/// Card di un voto o di un'assenza: bollino a sinistra, data colorata e righe a destra.
class _RecordCard extends StatelessWidget {
  const _RecordCard({required this.badge, required this.date, required this.children, this.dateColor, this.onTap});
  final Widget badge;
  final String date;
  final Color? dateColor;
  final List<Widget> children;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
          child: Row(
            children: [
              badge,
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Text(date,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700, color: dateColor ?? theme.colorScheme.primary)),
                    ...children,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Contatore con l'etichetta colorata e la riga sotto, come sul registro.
class _Counter extends StatelessWidget {
  const _Counter({required this.label, required this.value, required this.color, this.selected = false, this.onTap});
  final String label;
  final int value;
  final Color color;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? Color.alphaBlend(color.withAlpha(40), scheme.surfaceContainerHigh) : scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
              child: FittedBox(child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700))),
            ),
            Container(height: 2, color: color),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text('$value', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Voti

Color gradeColor(BuildContext context, double v) {
  final scheme = Theme.of(context).colorScheme;
  if (v < 5) return scheme.error;
  if (v < 6) return Colors.orange;
  if (v < 8) return scheme.primary;
  return Colors.green;
}

Future<void> addGradeDialog(BuildContext context, {String subject = ''}) async {
  final store = StoreScope.read(context);
  final subjects = {...mySubjects(store), ...store.grades.map((g) => g.subject)}.toList()..sort();
  final subj = TextEditingController(text: subject);
  final value = TextEditingController();
  final note = TextEditingController();
  var weight = 1.0;
  var kind = 'scritto';
  var day = DateTime.now();
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setState) {
        final v = Grade.parse(value.text);
        return AlertDialog(
          title: Text(tr('Nuovo voto', 'New grade')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: value,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: tr('Voto', 'Grade'),
                    hintText: '7, 6½, 6+, 8-, 6/7',
                    helperText: v == null ? null : '= ${v.toStringAsFixed(2)}',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                TextField(controller: subj, decoration: InputDecoration(labelText: tr('Materia', 'Subject'))),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final s in subjects.take(14))
                      ChoiceChip(
                        label: Text(s),
                        selected: subj.text == s,
                        onSelected: (_) => setState(() => subj.text = s),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(value: 'scritto', label: Text(tr('Scritto', 'Written'))),
                    ButtonSegment(value: 'orale', label: Text(tr('Orale', 'Oral'))),
                    ButtonSegment(value: 'pratico', label: Text(tr('Pratico', 'Practical'))),
                  ],
                  selected: {kind},
                  onSelectionChanged: (s) => setState(() => kind = s.first),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(tr('Peso', 'Weight')),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SegmentedButton<double>(
                        segments: const [
                          ButtonSegment(value: 0.5, label: Text('50%')),
                          ButtonSegment(value: 1.0, label: Text('100%')),
                          ButtonSegment(value: 2.0, label: Text('×2')),
                        ],
                        selected: {weight},
                        onSelectionChanged: (s) => setState(() => weight = s.first),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  icon: const Icon(Icons.event_rounded),
                  label: Text('${day.day}/${day.month}/${day.year}'),
                  onPressed: () async {
                    final d = await _pickDate(c, day);
                    if (d != null) setState(() => day = d);
                  },
                ),
                TextField(controller: note, decoration: InputDecoration(labelText: tr('Argomento (facoltativo)', 'Topic (optional)'))),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('Annulla', 'Cancel'))),
            FilledButton(
              onPressed: v == null || subj.text.trim().isEmpty ? null : () => Navigator.pop(c, true),
              child: Text(tr('Salva', 'Save')),
            ),
          ],
        );
      },
    ),
  );
  final v = Grade.parse(value.text);
  if (ok == true && v != null) {
    await store.addGrade(date: day, subject: subj.text, value: v, weight: weight, kind: kind, note: note.text);
    if (v >= 9.99 && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr('🔟 DIECI?! Qualcuno offre la pizza 🍕', '🔟 A TEN?! Someone\'s buying pizza 🍕'))));
    }
  }
}

class GradesPage extends StatelessWidget {
  const GradesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Periodo: 0 = tutto l'anno, 1 = trimestre/1º quadrimestre, 2 = pentamestre/2º.
    final mode = store.opt('periods', 'tri');
    final view = store.opt('grades.view', 0);
    // 3.8: elenco a card come sul registro (predefinito) oppure medie per materia.
    final bySubjectLayout = store.opt('grades.layout', 'list') == 'subjects';
    final allSubjects = {for (final g in store.grades) g.subject}.toList()..sort();
    final picked = store.opt('grades.subject', '');
    final subjectFilter = allSubjects.contains(picked) ? picked : '';
    final shown = store.grades.where((g) => view == 0 || gradePeriod(g.date, mode: mode) == view).toList();
    final bySubject = <String, List<Grade>>{};
    for (final g in shown) {
      (bySubject[g.subject] ??= []).add(g);
    }
    final subjects = bySubject.keys.toList()..sort();
    final avgs = [for (final s in subjects) average(bySubject[s]!)!];
    final overall = avgs.isEmpty ? null : avgs.reduce((a, b) => a + b) / avgs.length;
    final listed = shown.where((g) => subjectFilter.isEmpty || g.subject == subjectFilter).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final subjectAvg = subjectFilter.isEmpty ? null : average(listed);
    // 3.9: obiettivi di media salvati (per materia e generale).
    final targets = gradeTargets(store.opt<Object?>('grades.targets', null));
    double targetOf(String s) => targets[s] ?? 6;
    final overallTarget = store.opt<num?>('grades.target', null)?.toDouble();
    final raise = overallTarget == null || avgs.isEmpty
        ? null
        : raiseOverall({for (var i = 0; i < subjects.length; i++) subjects[i]: avgs[i]}, overallTarget);

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Voti', 'Grades')),
        actions: [
          IconButton(
            tooltip: bySubjectLayout ? tr('Elenco dei voti', 'Grade list') : tr('Medie per materia', 'Averages by subject'),
            onPressed: () => store.setOpt('grades.layout', bySubjectLayout ? null : 'subjects'),
            icon: Icon(bySubjectLayout ? Icons.view_agenda_outlined : Icons.leaderboard_outlined),
          ),
          IconButton(tooltip: tr('Grafici', 'Charts'), onPressed: () => openCharts(context), icon: const Icon(Icons.show_chart_rounded)),
          PopupMenuButton<String>(
            onSelected: (v) {
              switch (v) {
                case 'pdf':
                  exportReport(context);
                case 'credits':
                  openCredits(context);
                case 'tri':
                case 'quad':
                  store.setOpt('periods', v == 'tri' ? null : v);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'pdf', child: Text(tr('📄 Resoconto PDF per i genitori', '📄 PDF report for parents'))),
              PopupMenuItem(value: 'credits', child: Text(tr('🎓 Crediti scolastici', '🎓 School credits'))),
              CheckedPopupMenuItem(
                  value: 'tri', checked: mode == 'tri', child: Text(tr('Trimestre e pentamestre', 'Trimester and pentamester'))),
              CheckedPopupMenuItem(value: 'quad', checked: mode == 'quad', child: Text(tr('Due quadrimestri', 'Two semesters'))),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => addGradeDialog(context, subject: subjectFilter),
        icon: const Icon(Icons.add_rounded),
        label: Text(tr('Voto', 'Grade')),
      ),
      body: _body([
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr('Media generale', 'Overall average'),
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      Text(tr('${shown.length} voti · ${subjects.length} materie', '${shown.length} grades · ${subjects.length} subjects'),
                          style: TextStyle(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                _Badge(overall == null ? '—' : overall.toStringAsFixed(2), overall == null ? scheme.outline : gradeColor(context, overall),
                    size: 60),
              ],
            ),
          ),
        ),
        if (overall != null)
          Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              leading: const Text('🎯', style: TextStyle(fontSize: 24)),
              title: Text(overallTarget == null
                  ? tr('Che media generale vuoi?', 'What overall average do you want?')
                  : tr('Obiettivo: ${Grade.format(overallTarget)} di media generale', 'Goal: ${Grade.format(overallTarget)} overall average')),
              subtitle: Text(overallTarget == null
                  ? tr('Scegli un obiettivo e ti dico quali materie alzare', 'Pick a goal and I\'ll tell you which subjects to raise')
                  : overallPlanText(raise, overallTarget)),
              trailing: const Icon(Icons.edit_rounded),
              onTap: () => _overallTargetDialog(context, overallTarget ?? 7),
            ),
          ),
        _Picker<int>(
          value: view,
          items: [
            (0, tr('Tutto l\'anno', 'Whole year')),
            (1, periodName(1, mode: mode)),
            (2, periodName(2, mode: mode)),
          ],
          onChanged: (v) => store.setOpt('grades.view', v == 0 ? null : v),
        ),
        if (!bySubjectLayout && allSubjects.isNotEmpty)
          _Picker<String>(
            value: subjectFilter,
            items: [('', tr('Tutte le materie', 'All subjects')), for (final s in allSubjects) (s, s)],
            onChanged: (v) => store.setOpt('grades.subject', v.isEmpty ? null : v),
          ),
        const SizedBox(height: 8),
        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Text(
              store.grades.isEmpty
                  ? tr('Aggiungi il primo voto con il tasto qui sotto. Si salvano solo su questo dispositivo.',
                      'Add the first grade with the button below. They\'re only saved on this device.')
                  : tr('Nessun voto in questo periodo.', 'No grades in this period.'),
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
        if (bySubjectLayout)
          for (var i = 0; i < subjects.length; i++)
            Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                title: Text(subjects[i], style: const TextStyle(fontWeight: FontWeight.w600)),
                // Sotto il 6: subito quanto serve alla prossima (3.8).
                // 3.9: con l'obiettivo salvato per la materia (se no il 6).
                isThreeLine: avgs[i] < targetOf(subjects[i]),
                subtitle: Text([
                  bySubject[subjects[i]]!.take(8).map((g) => Grade.format(g.value)).join('  '),
                  if (avgs[i] < targetOf(subjects[i])) planText(planToReach(bySubject[subjects[i]]!, targetOf(subjects[i])), targetOf(subjects[i])),
                ].join('\n')),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      avgs[i].toStringAsFixed(2),
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: gradeColor(context, avgs[i])),
                    ),
                    Text(tr('pagella: ${reportCardMark(avgs[i])}', 'report card: ${reportCardMark(avgs[i])}'),
                        style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                    if (targets[subjects[i]] != null)
                      Text('🎯 ${Grade.format(targets[subjects[i]]!)}', style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                  ],
                ),
                onTap: () => _subjectSheet(context, subjects[i]),
              ),
            )
        else ...[
          // Materia scelta: media e "quanto mi serve?" a portata di dito.
          if (subjectAvg != null)
            Card(
              margin: const EdgeInsets.symmetric(vertical: 6),
              color: scheme.secondaryContainer,
              child: ListTile(
                title: Text(
                    '${tr('Media', 'Average')} ${subjectAvg.toStringAsFixed(2)} · ${tr('pagella', 'report card')} ${reportCardMark(subjectAvg)}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(subjectAvg < targetOf(subjectFilter)
                    ? planText(planToReach(listed, targetOf(subjectFilter)), targetOf(subjectFilter))
                    : tr('Quanto mi serve? Tocca per calcolarlo', 'How much do I need? Tap to work it out')),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _subjectSheet(context, subjectFilter),
              ),
            ),
          for (final g in listed)
            _RecordCard(
              badge: _Badge(Grade.format(g.value), gradeColor(context, g.value)),
              date: _fullDate(g.date),
              children: [
                Text('${_kindName(g.kind)}${g.weight != 1 ? ' · ${tr('peso', 'weight')} ${g.weight}' : ''}'),
                Text(g.subject.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w700)),
                if (g.note.isNotEmpty) _labelled(context, tr('Argomento', 'Topic'), g.note),
              ],
              onTap: () => _subjectSheet(context, g.subject),
            ),
        ],
      ]),
    );
  }
}

/// Testo del piano per la media generale.
String overallPlanText(List<(String, double, double)>? steps, double target) {
  final t = Grade.format(target);
  if (steps == null) return tr('Il $t di media generale è troppo lontano per questo periodo 😬', 'A $t overall average is too far for this term 😬');
  if (steps.isEmpty) return tr('Ce l\'hai già 😎', 'You\'ve already got it 😎');
  String f(double v) => v.toStringAsFixed(2);
  final parts = [for (final (s, a, b) in steps.take(3)) '$s ${f(a)} → ${f(b)}'];
  final more = steps.length > 3 ? tr(' e altre ${steps.length - 3}', ' and ${steps.length - 3} more') : '';
  return tr('Per esempio alza: ${parts.join(', ')}$more', 'For example raise: ${parts.join(', ')}$more');
}

Future<void> _overallTargetDialog(BuildContext context, double start) async {
  final store = StoreScope.read(context);
  var v = start;
  final r = await showDialog<double?>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setState) => AlertDialog(
        title: Text(tr('Obiettivo di media generale', 'Overall average goal')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(Grade.format(v), style: Theme.of(c).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800)),
          Slider(value: v, min: 5, max: 10, divisions: 20, label: Grade.format(v), onChanged: (x) => setState(() => v = x)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, -1.0), child: Text(tr('Togli', 'Remove'))),
          FilledButton(onPressed: () => Navigator.pop(c, v), child: Text(tr('Salva', 'Save'))),
        ],
      ),
    ),
  );
  if (r == null) return;
  await store.setOpt('grades.target', r < 0 ? null : r);
}

Future<void> _subjectSheet(BuildContext context, String subject) => showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (c) => _SubjectGrades(subject: subject),
    );

class _SubjectGrades extends StatefulWidget {
  const _SubjectGrades({required this.subject});
  final String subject;

  @override
  State<_SubjectGrades> createState() => _SubjectGradesState();
}

class _SubjectGradesState extends State<_SubjectGrades> {
  double? _target;
  double _weight = 1;

  /// 3.9: l'obiettivo della materia resta salvato (opzione "grades.targets").
  Future<void> _saveTarget(AppStore store, double v) async {
    final all = gradeTargets(store.opt<Object?>('grades.targets', null));
    if (v == 6) {
      all.remove(widget.subject);
    } else {
      all[widget.subject] = v;
    }
    await store.setOpt('grades.targets', all.isEmpty ? null : all);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final theme = Theme.of(context);
    // Stesso periodo della pagina Voti (tutto l'anno, trimestre/pentamestre o quadrimestri).
    final mode = store.opt('periods', 'tri');
    final view = store.opt('grades.view', 0);
    final list = store.grades.where((g) => g.subject == widget.subject && (view == 0 || gradePeriod(g.date, mode: mode) == view)).toList();
    final avg = average(list);
    final target = _target ?? gradeTargets(store.opt<Object?>('grades.targets', null))[widget.subject] ?? 6;
    String needText() => planText(planToReach(list, target, weight: _weight), target);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.subject, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          if (avg != null)
            Text(
                '${tr('Media', 'Average')} ${avg.toStringAsFixed(2)} · ${list.length} ${tr('voti', 'grades')}${view == 0 ? '' : ' · ${periodName(view, mode: mode)}'}'),
          SectionLabel(tr('Quanto mi serve?', 'How much do I need?')),
          Text(tr('Per arrivare a ${Grade.format(target)} di media (resta salvato come obiettivo)',
              'To reach a ${Grade.format(target)} average (saved as your goal)')),
          Slider(
            value: target.clamp(5, 10).toDouble(),
            min: 5,
            max: 10,
            divisions: 10,
            label: Grade.format(target),
            onChanged: (v) => setState(() => _target = v),
            onChangeEnd: (v) => _saveTarget(store, v),
          ),
          SegmentedButton<double>(
            segments: [
              ButtonSegment(value: 0.5, label: Text(tr('Prova al 50%', 'Test at 50%'))),
              ButtonSegment(value: 1.0, label: Text(tr('Prova normale', 'Normal test'))),
            ],
            selected: {_weight},
            onSelectionChanged: (s) => setState(() => _weight = s.first),
          ),
          const SizedBox(height: 8),
          Text(needText(), style: theme.textTheme.titleMedium),
          SectionLabel(tr('Voti', 'Grades')),
          for (final g in list)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: gradeColor(context, g.value).withAlpha(40),
                child: Text(Grade.format(g.value), style: TextStyle(fontWeight: FontWeight.w800, color: gradeColor(context, g.value))),
              ),
              title: Text('${_kindName(g.kind)}${g.weight != 1 ? ' · ${tr('peso', 'weight')} ${g.weight}' : ''}'),
              subtitle: Text([_date(g.date), if (g.note.isNotEmpty) g.note].join(' · ')),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: () => store.removeGrade(g),
              ),
            ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: () => addGradeDialog(context, subject: widget.subject),
            icon: const Icon(Icons.add_rounded),
            label: Text(tr('Aggiungi un voto', 'Add a grade')),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Timer per studiare (pomodoro)

class StudyTimerPage extends StatefulWidget {
  const StudyTimerPage({super.key, this.subject});
  final String? subject;

  @override
  State<StudyTimerPage> createState() => _StudyTimerPageState();
}

class _StudyTimerPageState extends State<StudyTimerPage> with WidgetsBindingObserver {
  static const _notifyId = 7000;
  int _focus = 25;
  int _pause = 5;
  bool _onBreak = false;
  DateTime? _end;
  Duration? _paused;
  Timer? _tick;
  String _subject = '';
  int _rounds = 0;

  // 3.9: studio insieme. Gli amici vedono che studi (e cosa) solo se accendi l'interruttore.
  late final AppStore _store;
  List<StudyBuddy> _buddies = const [];
  StudyBuddy? _with;
  bool _shared = false;
  StreamSubscription<LiveEvent>? _liveSub;
  bool get _social => _store.accountCode != null && _store.opt<String?>('social.nick', null) != null;
  bool get _share => _store.opt<bool>('study.share', false);

  @override
  void initState() {
    super.initState();
    _store = StoreScope.read(context);
    _subject = widget.subject ?? '';
    WidgetsBinding.instance.addObserver(this);
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
    if (_social) {
      _loadBuddies();
      _liveSub = Live.instance.events.where((e) => e.type == 'study').listen((_) => _loadBuddies());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tick?.cancel();
    _liveSub?.cancel();
    if (_shared) Social.stopStudy(_store).catchError((_) {});
    super.dispose();
  }

  Future<void> _loadBuddies() async {
    try {
      final b = await Social.studying(_store);
      if (mounted) setState(() => _buddies = b);
    } catch (_) {
      // niente rete: si vede il timer e basta
    }
  }

  /// Dice agli amici che studi adesso (fino a [end]).
  void _shareStart(DateTime end) {
    if (!_social || !_share || _onBreak) return;
    _shared = true;
    final minutes = (end.difference(DateTime.now()).inSeconds / 60).ceil();
    Social.startStudy(_store, subject: _subject, minutes: minutes, withCode: _with?.code).catchError((_) {});
  }

  void _shareStop() {
    if (!_shared) return;
    _shared = false;
    Social.stopStudy(_store).catchError((_) {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _onTick();
  }

  Duration get _left {
    if (_paused != null) return _paused!;
    if (_end == null) return Duration(minutes: _onBreak ? _pause : _focus);
    final d = _end!.difference(DateTime.now());
    return d.isNegative ? Duration.zero : d;
  }

  void _onTick() {
    if (!mounted) return;
    if (_end != null && _paused == null && !DateTime.now().isBefore(_end!)) {
      _finish();
    } else {
      setState(() {});
    }
  }

  void _finish() {
    _shareStop();
    final store = StoreScope.read(context);
    if (!_onBreak) {
      store.addStudy(_subject, _focus);
      _rounds++;
      DesktopBridge.notify(
          tr('Pausa! ☕', 'Break! ☕'),
          appEnglish
              ? '$_focus minutes of ${_subject.isEmpty ? 'study' : _subject} done'
              : '$_focus minuti di ${_subject.isEmpty ? 'studio' : _subject} fatti');
    } else {
      DesktopBridge.notify(tr('Si riparte! 📚', 'Back to it! 📚'), tr('Altri $_focus minuti', 'Another $_focus minutes'));
    }
    setState(() {
      _onBreak = !_onBreak;
      _end = null;
      _paused = null;
    });
  }

  void _start() {
    final left = _left;
    final end = DateTime.now().add(left);
    setState(() {
      _end = end;
      _paused = null;
    });
    _shareStart(end);
    NativeBridge.scheduleOne(
      _notifyId,
      end,
      _onBreak ? tr('Fine pausa! 📚', 'Break over! 📚') : tr('Tempo! ☕ Fai una pausa', 'Time! ☕ Take a break'),
      _onBreak
          ? tr('Si torna a studiare', 'Back to studying')
          : '${_subject.isEmpty ? tr('Studio', 'Study') : _subject}: $_focus ${tr('minuti fatti', 'minutes done')}',
    );
  }

  void _pauseTimer() {
    _shareStop();
    setState(() {
      _paused = _left;
      _end = null;
    });
    NativeBridge.cancelOne(_notifyId);
  }

  void _reset() {
    _shareStop();
    setState(() {
      _end = null;
      _paused = null;
      _onBreak = false;
    });
    NativeBridge.cancelOne(_notifyId);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final running = _end != null;
    final total = Duration(minutes: _onBreak ? _pause : _focus).inSeconds;
    final left = _left;
    final mm = left.inMinutes.toString().padLeft(2, '0');
    final ss = (left.inSeconds % 60).toString().padLeft(2, '0');
    // Prima le materie con una verifica in arrivo.
    final tests = store.agendaFrom(DateTime.now(), days: 14).where((a) => a.kind != 'compito').map((a) => a.subject);
    final subjects = {...tests, ...mySubjects(store)}.where((s) => s.isNotEmpty).toList();
    final studied = store.studyMinutes.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      appBar: AppBar(title: Text(tr('Timer per studiare', 'Study timer'))),
      body: _body([
        const SizedBox(height: 8),
        Center(
          child: SizedBox(
            width: 240,
            height: 240,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: total == 0 ? 0 : left.inSeconds / total,
                  strokeWidth: 12,
                  color: _onBreak ? Colors.teal : scheme.primary,
                  backgroundColor: scheme.surfaceContainerHighest,
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_onBreak ? tr('PAUSA ☕', 'BREAK ☕') : (_subject.isEmpty ? tr('STUDIO', 'STUDY') : _subject.toUpperCase()),
                          textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
                      Text('$mm:$ss', style: theme.textTheme.displayMedium?.copyWith(fontWeight: FontWeight.w800)),
                      Text(tr('$_rounds giri', '$_rounds rounds'), style: TextStyle(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton.icon(onPressed: _reset, icon: const Icon(Icons.restart_alt_rounded), label: Text(tr('Azzera', 'Reset'))),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: running ? _pauseTimer : _start,
              icon: Icon(running ? Icons.pause_rounded : Icons.play_arrow_rounded),
              label: Text(running ? tr('Pausa', 'Pause') : (_paused != null ? tr('Riprendi', 'Resume') : tr('Via!', 'Go!'))),
            ),
            if (running || _paused != null) ...[
              const SizedBox(width: 12),
              IconButton(tooltip: tr('Salta', 'Skip'), onPressed: _finish, icon: const Icon(Icons.skip_next_rounded)),
            ],
          ],
        ),
        SectionLabel(tr('Durata', 'Duration')),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 15, label: Text('15/3')),
            ButtonSegment(value: 25, label: Text('25/5')),
            ButtonSegment(value: 45, label: Text('45/10')),
            ButtonSegment(value: 60, label: Text('60/15')),
          ],
          selected: {_focus},
          onSelectionChanged: running
              ? null
              : (s) => setState(() {
                    _focus = s.first;
                    _pause = switch (s.first) { 15 => 3, 25 => 5, 45 => 10, _ => 15 };
                    _paused = null;
                  }),
        ),
        SectionLabel(tr('Cosa studi', 'What you\'re studying')),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final s in subjects.take(16))
              ChoiceChip(
                label: Text(s),
                selected: _subject == s,
                onSelected: running ? null : (_) => setState(() => _subject = _subject == s ? '' : s),
              ),
          ],
        ),
        if (_social) ...[
          SectionLabel(tr('Studia con gli amici', 'Study with friends')),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(tr('Fai vedere agli amici che studi', 'Let friends see you\'re studying')),
            subtitle: Text(tr('Solo i tuoi amici, solo mentre il timer va (e la materia, se è nell\'elenco)',
                'Only your friends, only while the timer runs (and the subject, if it\'s on the list)')),
            value: _share,
            onChanged: (v) async {
              await _store.setOpt('study.share', v);
              if (!v) _shareStop();
              if (v && running && _end != null) _shareStart(_end!);
              if (mounted) setState(() {});
            },
          ),
          if (_buddies.isEmpty)
            Text(tr('Nessun amico sta studiando adesso.', 'No friends are studying right now.'), style: TextStyle(color: scheme.onSurfaceVariant))
          else
            for (final b in _buddies)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Text(b.avatar, style: const TextStyle(fontSize: 26)),
                title: Text(b.withMe ? tr('${b.nickname} · studia con te!', '${b.nickname} · studying with you!') : b.nickname),
                subtitle: Text([
                  if (b.subject.isNotEmpty) b.subject,
                  tr('ancora ${b.until.difference(DateTime.now()).inMinutes.clamp(0, 999)} min', '${b.until.difference(DateTime.now()).inMinutes.clamp(0, 999)} min left'),
                ].join(' · ')),
                trailing: _share
                    ? FilterChip(
                        label: Text(tr('Studio con te', 'Study with you')),
                        selected: _with?.code == b.code,
                        onSelected: (v) {
                          setState(() => _with = v ? b : null);
                          if (running && _end != null) _shareStart(_end!);
                        },
                      )
                    : null,
              ),
        ],
        if (studied.isNotEmpty) ...[
          SectionLabel(tr('Quanto hai studiato', 'How much you studied')),
          for (final e in studied.take(10))
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(e.key),
              trailing: Text(e.value < 60 ? '${e.value} min' : '${e.value ~/ 60} h ${e.value % 60} min'),
            ),
        ],
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Settimana A/B

Future<void> abWeekDialog(BuildContext context) async {
  final store = StoreScope.read(context);
  final mine = store.myMainRef;
  final options = [...store.favorites, ...store.recents].where((s) => s.ref.key != mine?.key).toList();
  var alt = store.altRef?.key ?? '';
  final anchor = DateTime.tryParse(store.opt('ab.anchor', ''));
  final now = DateTime.now();
  var thisIsB = anchor != null && isWeekB(now, anchor);
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setState) => AlertDialog(
        title: Text(tr('Settimana A/B', 'Week A/B')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                tr(
                    'Se il tuo orario cambia a settimane alterne: la settimana A usa "il mio orario", '
                        'la B un altro orario salvato (cercalo e salvalo prima).',
                    'If your timetable changes on alternate weeks: week A uses "my timetable", week B another saved timetable (search for it and save it first).'),
              ),
              const SizedBox(height: 12),
              RadioGroup<String>(
                groupValue: alt,
                onChanged: (v) => setState(() => alt = v ?? ''),
                child: Column(
                  children: [
                    RadioListTile<String>(
                        contentPadding: EdgeInsets.zero, value: '', title: Text(tr('Niente settimane alternate', 'No alternating weeks'))),
                    for (final s in options)
                      RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        value: s.ref.key,
                        title: Text(tr('Settimana B: ${s.ref.displayName}', 'Week B: ${s.ref.displayName}')),
                      ),
                  ],
                ),
              ),
              if (alt.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(tr('Questa settimana è la…', 'This week is…')),
                const SizedBox(height: 6),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('A')),
                    ButtonSegment(value: true, label: Text('B')),
                  ],
                  selected: {thisIsB},
                  onSelectionChanged: (s) => setState(() => thisIsB = s.first),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('Annulla', 'Cancel'))),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(tr('Salva', 'Save'))),
        ],
      ),
    ),
  );
  if (ok != true) return;
  if (alt.isEmpty) {
    await store.setOpt('ab.alt', null);
    await store.setOpt('ab.anchor', null);
    return;
  }
  final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
  final b = thisIsB ? monday : monday.add(const Duration(days: 7));
  await store.setOpt('ab.alt', alt);
  await store.setOpt(
      'ab.anchor',
      '${b.year.toString().padLeft(4, '0')}-${b.month.toString().padLeft(2, '0')}-'
          '${b.day.toString().padLeft(2, '0')}');
}

/// Tipo di voto (scritto, orale, pratico) nella lingua dell'app.
String _kindName(String kind) => switch (kind) {
      'scritto' => tr('Scritto', 'Written'),
      'orale' => tr('Orale', 'Oral'),
      'pratico' => tr('Pratico', 'Practical'),
      _ => kind.isEmpty ? kind : '${kind[0].toUpperCase()}${kind.substring(1)}',
    };

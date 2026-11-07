import 'dart:async';

import 'package:flutter/material.dart';

import '../agenda.dart';
import '../models.dart';
import '../native.dart';
import '../school_extra.dart';
import '../school_life.dart';
import '../store.dart';
import 'agenda_page.dart' show mySubjects;
import 'desktop.dart';
import 'more_pages.dart' show openCharts, openCredits;
import 'register_import_page.dart';
import 'report_pdf.dart';
import 'widgets.dart';
import '../i18n.dart';

void openAbsences(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AbsencesPage()));

void openGrades(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const GradesPage()));

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
                      ? tr('Quel giorno niente notifiche delle lezioni né silenzioso.', 'That day no lesson notifications and no silent mode.')
                      : tr('Widget, notifiche e riepilogo della sera terranno conto dell\'orario.', 'Widget, notifications and evening summary will take the timetable into account.'),
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
    final stats = week == null ? null : absenceStats(store.absences, week, now);
    final future = store.absences.where((a) => a.date.isAfter(dateOnly(now))).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final past = store.absences.where((a) => !a.date.isAfter(dateOnly(now))).toList();

    Color level(double r) => r >= 0.2 ? scheme.error : (r >= 0.15 ? Colors.orange : scheme.primary);

    Widget entry(AbsenceEntry a, {bool planned = false}) => Dismissible(
          key: ValueKey(a.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            color: scheme.errorContainer,
            child: Icon(Icons.delete_outline_rounded, color: scheme.onErrorContainer),
          ),
          onDismissed: (_) => store.removeAbsence(a),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Text(a.emoji, style: const TextStyle(fontSize: 24)),
            title: Text('${a.label}${planned ? tr(' · in programma', ' · planned') : ''}'),
            subtitle: Text([_date(a.date), if (a.note.isNotEmpty) a.note].join(' · ')),
          ),
        );

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
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => addAbsenceDialog(context),
        icon: const Icon(Icons.add_rounded),
        label: Text(tr('Segna', 'Mark')),
      ),
      body: _body([
        if (stats == null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(tr('Imposta "il mio orario" per contare le ore perse per materia.', 'Set "my timetable" to count the hours missed per subject.')),
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('${stats.lost} ore perse', '${stats.lost} hours missed'), style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    tr('Limite: ${stats.limitHours} ore (25% di ${stats.yearHours} ore all\'anno) · '
                    '${stats.days} giorni interi', 'Limit: ${stats.limitHours} hours (25% of ${stats.yearHours} hours a year) · ${stats.days} full days'),
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: (stats.ratio / absenceLimit).clamp(0.0, 1.0),
                      minHeight: 10,
                      color: level(stats.ratio),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    stats.left > 0
                        ? tr('${(stats.ratio * 100).toStringAsFixed(1)}% · puoi perdere ancora ${stats.left} ore', '${(stats.ratio * 100).toStringAsFixed(1)}% · you can still miss ${stats.left} hours')
                        : tr('⚠️ Hai superato il limite: parlane con il coordinatore (ci sono deroghe per motivi di salute)', '⚠️ You\'ve gone over the limit: talk to the coordinator (there are exceptions for health reasons)'),
                    style: TextStyle(color: level(stats.ratio), fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ActionChip(
              avatar: const Text('⏰'),
              label: Text(tr('Domani entro dopo', 'Late entry tomorrow')),
              onPressed: () => addAbsenceDialog(context, kind: 'entrata'),
            ),
            ActionChip(
              avatar: const Text('🚪'),
              label: Text(tr('Domani esco prima', 'Early exit tomorrow')),
              onPressed: () => addAbsenceDialog(context, kind: 'uscita'),
            ),
          ],
        ),
        if (future.isNotEmpty) ...[
          SectionLabel(tr('In programma', 'Planned')),
          for (final a in future) entry(a, planned: true),
        ],
        if (stats != null && stats.bySubject.isNotEmpty) ...[
          SectionLabel(tr('Per materia', 'By subject')),
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
        SectionLabel(tr('Storico', 'History')),
        if (past.isEmpty)
          Text(tr('Nessuna assenza. Grande! 💪', 'No absences. Great! 💪'), style: TextStyle(color: scheme.onSurfaceVariant)),
        for (final a in past) entry(a),
        const SizedBox(height: 12),
        Text(
          tr('Il conto è una stima: $schoolWeeks settimane di lezione con il tuo orario attuale. '
          'Il numero ufficiale è quello del registro elettronico.', 'The count is an estimate: $schoolWeeks weeks of lessons with your current timetable. The official number is the one in the electronic register.'),
          style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ]),
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('🔟 DIECI?! Qualcuno offre la pizza 🍕', '🔟 A TEN?! Someone\'s buying pizza 🍕'))));
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
    final shown = store.grades.where((g) => view == 0 || gradePeriod(g.date, mode: mode) == view).toList();
    final bySubject = <String, List<Grade>>{};
    for (final g in shown) {
      (bySubject[g.subject] ??= []).add(g);
    }
    final subjects = bySubject.keys.toList()..sort();
    final avgs = [for (final s in subjects) average(bySubject[s]!)!];
    final overall = avgs.isEmpty ? null : avgs.reduce((a, b) => a + b) / avgs.length;
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Voti', 'Grades')),
        actions: [
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
              CheckedPopupMenuItem(value: 'tri', checked: mode == 'tri', child: Text(tr('Trimestre e pentamestre', 'Trimester and pentamester'))),
              CheckedPopupMenuItem(value: 'quad', checked: mode == 'quad', child: Text(tr('Due quadrimestri', 'Two semesters'))),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => addGradeDialog(context),
        icon: const Icon(Icons.add_rounded),
        label: Text(tr('Voto', 'Grade')),
      ),
      body: _body([
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr('Media generale', 'Overall average'), style: TextStyle(color: scheme.onSurfaceVariant)),
                      Text(
                        overall == null ? '—' : overall.toStringAsFixed(2),
                        style: theme.textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: overall == null ? null : gradeColor(context, overall),
                        ),
                      ),
                      Text(tr('${shown.length} voti · ${subjects.length} materie', '${shown.length} grades · ${subjects.length} subjects'),
                          style: TextStyle(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                const Text('📊', style: TextStyle(fontSize: 48)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        SegmentedButton<int>(
          segments: [
            ButtonSegment(value: 0, label: Text(tr('Tutto l\'anno', 'Whole year'))),
            ButtonSegment(value: 1, label: Text(periodName(1, mode: mode))),
            ButtonSegment(value: 2, label: Text(periodName(2, mode: mode))),
          ],
          selected: {view},
          onSelectionChanged: (s) => store.setOpt('grades.view', s.first == 0 ? null : s.first),
        ),
        if (subjects.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Text(tr('Aggiungi il primo voto con il tasto qui sotto. Si salvano solo su questo dispositivo.', 'Add the first grade with the button below. They\'re only saved on this device.')),
          ),
        if (subjects.isNotEmpty) SectionLabel(tr('Per materia', 'By subject')),
        for (var i = 0; i < subjects.length; i++)
          Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              title: Text(subjects[i], style: const TextStyle(fontWeight: FontWeight.w600)),
              // Sotto il 6: subito quanto serve alla prossima (3.8).
              isThreeLine: avgs[i] < 6,
              subtitle: Text([
                bySubject[subjects[i]]!.take(8).map((g) => Grade.format(g.value)).join('  '),
                if (avgs[i] < 6) planText(planToReach(bySubject[subjects[i]]!, 6), 6),
              ].join('\n')),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    avgs[i].toStringAsFixed(2),
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: gradeColor(context, avgs[i])),
                  ),
                  Text(tr('pagella: ${reportCardMark(avgs[i])}', 'report card: ${reportCardMark(avgs[i])}'), style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                ],
              ),
              onTap: () => _subjectSheet(context, subjects[i]),
            ),
          ),
      ]),
    );
  }
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
  double _target = 6;
  double _weight = 1;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final theme = Theme.of(context);
    // Stesso periodo della pagina Voti (tutto l'anno, trimestre/pentamestre o quadrimestri).
    final mode = store.opt('periods', 'tri');
    final view = store.opt('grades.view', 0);
    final list = store.grades
        .where((g) => g.subject == widget.subject && (view == 0 || gradePeriod(g.date, mode: mode) == view))
        .toList();
    final avg = average(list);
    String needText() => planText(planToReach(list, _target, weight: _weight), _target);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.subject, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          if (avg != null)
            Text('${tr('Media', 'Average')} ${avg.toStringAsFixed(2)} · ${list.length} ${tr('voti', 'grades')}${view == 0 ? '' : ' · ${periodName(view, mode: mode)}'}'),
          SectionLabel(tr('Quanto mi serve?', 'How much do I need?')),
          Text(tr('Per arrivare a ${Grade.format(_target)} di media', 'To reach a ${Grade.format(_target)} average')),
          Slider(
            value: _target,
            min: 5,
            max: 10,
            divisions: 10,
            label: Grade.format(_target),
            onChanged: (v) => setState(() => _target = v),
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
                child: Text(Grade.format(g.value),
                    style: TextStyle(fontWeight: FontWeight.w800, color: gradeColor(context, g.value))),
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

  @override
  void initState() {
    super.initState();
    _subject = widget.subject ?? '';
    WidgetsBinding.instance.addObserver(this);
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tick?.cancel();
    super.dispose();
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
    final store = StoreScope.read(context);
    if (!_onBreak) {
      store.addStudy(_subject, _focus);
      _rounds++;
      DesktopBridge.notify(tr('Pausa! ☕', 'Break! ☕'), appEnglish ? '$_focus minutes of ${_subject.isEmpty ? 'study' : _subject} done' : '$_focus minuti di ${_subject.isEmpty ? 'studio' : _subject} fatti');
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
    NativeBridge.scheduleOne(
      _notifyId,
      end,
      _onBreak ? tr('Fine pausa! 📚', 'Break over! 📚') : tr('Tempo! ☕ Fai una pausa', 'Time! ☕ Take a break'),
      _onBreak ? tr('Si torna a studiare', 'Back to studying') : '${_subject.isEmpty ? tr('Studio', 'Study') : _subject}: $_focus ${tr('minuti fatti', 'minutes done')}',
    );
  }

  void _pauseTimer() {
    setState(() {
      _paused = _left;
      _end = null;
    });
    NativeBridge.cancelOne(_notifyId);
  }

  void _reset() {
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
                tr('Se il tuo orario cambia a settimane alterne: la settimana A usa "il mio orario", '
                'la B un altro orario salvato (cercalo e salvalo prima).', 'If your timetable changes on alternate weeks: week A uses "my timetable", week B another saved timetable (search for it and save it first).'),
              ),
              const SizedBox(height: 12),
              RadioGroup<String>(
                groupValue: alt,
                onChanged: (v) => setState(() => alt = v ?? ''),
                child: Column(
                  children: [
                    RadioListTile<String>(contentPadding: EdgeInsets.zero, value: '', title: Text(tr('Niente settimane alternate', 'No alternating weeks'))),
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
  await store.setOpt('ab.anchor', '${b.year.toString().padLeft(4, '0')}-${b.month.toString().padLeft(2, '0')}-'
      '${b.day.toString().padLeft(2, '0')}');
}

/// Tipo di voto (scritto, orale, pratico) nella lingua dell'app.
String _kindName(String kind) => switch (kind) {
      'scritto' => tr('Scritto', 'Written'),
      'orale' => tr('Orale', 'Oral'),
      'pratico' => tr('Pratico', 'Practical'),
      _ => kind.isEmpty ? kind : '${kind[0].toUpperCase()}${kind.substring(1)}',
    };

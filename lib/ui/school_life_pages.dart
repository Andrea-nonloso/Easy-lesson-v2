import 'dart:async';

import 'package:flutter/material.dart';

import '../agenda.dart';
import '../models.dart';
import '../native.dart';
import '../school_life.dart';
import '../store.dart';
import 'agenda_page.dart' show mySubjects;
import 'desktop.dart';
import 'widgets.dart';

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
        title: const Text('Assenze e permessi'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'assenza', label: Text('Assente')),
                  ButtonSegment(value: 'entrata', label: Text('Entro dopo')),
                  ButtonSegment(value: 'uscita', label: Text('Esco prima')),
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
                Text(k == 'entrata' ? 'Entro alla…' : 'Esco dopo la…'),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (var h = k == 'entrata' ? 2 : 1; h <= (k == 'entrata' ? maxHours : maxHours - 1); h++)
                      ChoiceChip(label: Text('$hª ora'), selected: hour == h, onSelected: (_) => setState(() => hour = h)),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              TextField(controller: note, decoration: const InputDecoration(labelText: 'Nota (facoltativa)')),
              if (!dateOnly(day).isBefore(dateOnly(now))) ...[
                const SizedBox(height: 12),
                Text(
                  k == 'assenza'
                      ? 'Quel giorno niente notifiche delle lezioni né silenzioso.'
                      : 'Widget, notifiche e riepilogo della sera terranno conto dell\'orario.',
                  style: Theme.of(c).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annulla')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Salva')),
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
            title: Text('${a.label}${planned ? ' · in programma' : ''}'),
            subtitle: Text([_date(a.date), if (a.note.isNotEmpty) a.note].join(' · ')),
          ),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Assenze e permessi')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => addAbsenceDialog(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Segna'),
      ),
      body: _body([
        if (stats == null)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Text('Imposta "il mio orario" per contare le ore perse per materia.'),
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${stats.lost} ore perse', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    'Limite: ${stats.limitHours} ore (25% di ${stats.yearHours} ore all\'anno) · '
                    '${stats.days} giorni interi',
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
                        ? '${(stats.ratio * 100).toStringAsFixed(1)}% · puoi perdere ancora ${stats.left} ore'
                        : '⚠️ Hai superato il limite: parlane con il coordinatore (ci sono deroghe per motivi di salute)',
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
              label: const Text('Domani entro dopo'),
              onPressed: () => addAbsenceDialog(context, kind: 'entrata'),
            ),
            ActionChip(
              avatar: const Text('🚪'),
              label: const Text('Domani esco prima'),
              onPressed: () => addAbsenceDialog(context, kind: 'uscita'),
            ),
          ],
        ),
        if (future.isNotEmpty) ...[
          const SectionLabel('In programma'),
          for (final a in future) entry(a, planned: true),
        ],
        if (stats != null && stats.bySubject.isNotEmpty) ...[
          const SectionLabel('Per materia'),
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
        const SectionLabel('Storico'),
        if (past.isEmpty)
          Text('Nessuna assenza. Grande! 💪', style: TextStyle(color: scheme.onSurfaceVariant)),
        for (final a in past) entry(a),
        const SizedBox(height: 12),
        Text(
          'Il conto è una stima: $schoolWeeks settimane di lezione con il tuo orario attuale. '
          'Il numero ufficiale è quello del registro elettronico.',
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
          title: const Text('Nuovo voto'),
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
                    labelText: 'Voto',
                    hintText: '7, 6½, 6+, 8-, 6/7',
                    helperText: v == null ? null : '= ${v.toStringAsFixed(2)}',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                TextField(controller: subj, decoration: const InputDecoration(labelText: 'Materia')),
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
                  segments: const [
                    ButtonSegment(value: 'scritto', label: Text('Scritto')),
                    ButtonSegment(value: 'orale', label: Text('Orale')),
                    ButtonSegment(value: 'pratico', label: Text('Pratico')),
                  ],
                  selected: {kind},
                  onSelectionChanged: (s) => setState(() => kind = s.first),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Peso'),
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
                TextField(controller: note, decoration: const InputDecoration(labelText: 'Argomento (facoltativo)')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annulla')),
            FilledButton(
              onPressed: v == null || subj.text.trim().isEmpty ? null : () => Navigator.pop(c, true),
              child: const Text('Salva'),
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🔟 DIECI?! Qualcuno offre la pizza 🍕')));
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
    final bySubject = <String, List<Grade>>{};
    for (final g in store.grades) {
      (bySubject[g.subject] ??= []).add(g);
    }
    final subjects = bySubject.keys.toList()..sort();
    final avgs = [for (final s in subjects) average(bySubject[s]!)!];
    final overall = avgs.isEmpty ? null : avgs.reduce((a, b) => a + b) / avgs.length;
    return Scaffold(
      appBar: AppBar(title: const Text('Voti')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => addGradeDialog(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Voto'),
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
                      Text('Media generale', style: TextStyle(color: scheme.onSurfaceVariant)),
                      Text(
                        overall == null ? '—' : overall.toStringAsFixed(2),
                        style: theme.textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: overall == null ? null : gradeColor(context, overall),
                        ),
                      ),
                      Text('${store.grades.length} voti · ${subjects.length} materie',
                          style: TextStyle(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                const Text('📊', style: TextStyle(fontSize: 48)),
              ],
            ),
          ),
        ),
        if (subjects.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: Text('Aggiungi il primo voto con il tasto qui sotto. Si salvano solo su questo dispositivo.'),
          ),
        if (subjects.isNotEmpty) const SectionLabel('Per materia'),
        for (var i = 0; i < subjects.length; i++)
          Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              title: Text(subjects[i], style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(bySubject[subjects[i]]!.take(8).map((g) => Grade.format(g.value)).join('  ')),
              trailing: Text(
                avgs[i].toStringAsFixed(2),
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: gradeColor(context, avgs[i])),
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
    final list = store.grades.where((g) => g.subject == widget.subject).toList();
    final avg = average(list);
    final need = neededFor(list, _target, weight: _weight);
    String needText() {
      if (need == null) return '';
      if (need <= 1) return 'Ce l\'hai già fatta, anche con un 1 😎';
      if (need > 10) return 'Neanche con un 10 ci arrivi in una prova sola 😬 (servirebbe ${need.toStringAsFixed(1)})';
      return 'Ti serve almeno ${Grade.format((need * 4).ceil() / 4)} nella prossima prova';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.subject, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          if (avg != null) Text('Media ${avg.toStringAsFixed(2)} · ${list.length} voti'),
          const SectionLabel('Quanto mi serve?'),
          Text('Per arrivare a ${Grade.format(_target)} di media'),
          Slider(
            value: _target,
            min: 5,
            max: 10,
            divisions: 10,
            label: Grade.format(_target),
            onChanged: (v) => setState(() => _target = v),
          ),
          SegmentedButton<double>(
            segments: const [
              ButtonSegment(value: 0.5, label: Text('Prova al 50%')),
              ButtonSegment(value: 1.0, label: Text('Prova normale')),
            ],
            selected: {_weight},
            onSelectionChanged: (s) => setState(() => _weight = s.first),
          ),
          const SizedBox(height: 8),
          Text(needText(), style: theme.textTheme.titleMedium),
          const SectionLabel('Voti'),
          for (final g in list)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: gradeColor(context, g.value).withAlpha(40),
                child: Text(Grade.format(g.value),
                    style: TextStyle(fontWeight: FontWeight.w800, color: gradeColor(context, g.value))),
              ),
              title: Text('${g.kind[0].toUpperCase()}${g.kind.substring(1)}${g.weight != 1 ? ' · peso ${g.weight}' : ''}'),
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
            label: const Text('Aggiungi un voto'),
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
      DesktopBridge.notify('Pausa! ☕', '$_focus minuti di ${_subject.isEmpty ? 'studio' : _subject} fatti');
    } else {
      DesktopBridge.notify('Si riparte! 📚', 'Altri $_focus minuti');
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
      _onBreak ? 'Fine pausa! 📚' : 'Tempo! ☕ Fai una pausa',
      _onBreak ? 'Si torna a studiare' : '${_subject.isEmpty ? 'Studio' : _subject}: $_focus minuti fatti',
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
      appBar: AppBar(title: const Text('Timer per studiare')),
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
                      Text(_onBreak ? 'PAUSA ☕' : (_subject.isEmpty ? 'STUDIO' : _subject.toUpperCase()),
                          textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
                      Text('$mm:$ss', style: theme.textTheme.displayMedium?.copyWith(fontWeight: FontWeight.w800)),
                      Text('$_rounds giri', style: TextStyle(color: scheme.onSurfaceVariant)),
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
            OutlinedButton.icon(onPressed: _reset, icon: const Icon(Icons.restart_alt_rounded), label: const Text('Azzera')),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: running ? _pauseTimer : _start,
              icon: Icon(running ? Icons.pause_rounded : Icons.play_arrow_rounded),
              label: Text(running ? 'Pausa' : (_paused != null ? 'Riprendi' : 'Via!')),
            ),
            if (running || _paused != null) ...[
              const SizedBox(width: 12),
              IconButton(tooltip: 'Salta', onPressed: _finish, icon: const Icon(Icons.skip_next_rounded)),
            ],
          ],
        ),
        const SectionLabel('Durata'),
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
        const SectionLabel('Cosa studi'),
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
          const SectionLabel('Quanto hai studiato'),
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
        title: const Text('Settimana A/B'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Se il tuo orario cambia a settimane alterne: la settimana A usa "il mio orario", '
                'la B un altro orario salvato (cercalo e salvalo prima).',
              ),
              const SizedBox(height: 12),
              RadioGroup<String>(
                groupValue: alt,
                onChanged: (v) => setState(() => alt = v ?? ''),
                child: Column(
                  children: [
                    const RadioListTile<String>(contentPadding: EdgeInsets.zero, value: '', title: Text('Niente settimane alternate')),
                    for (final s in options)
                      RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        value: s.ref.key,
                        title: Text('Settimana B: ${s.ref.displayName}'),
                      ),
                  ],
                ),
              ),
              if (alt.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('Questa settimana è la…'),
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
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annulla')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Salva')),
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

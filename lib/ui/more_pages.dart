import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../agenda.dart';
import '../models.dart';
import '../native.dart';
import '../school_extra.dart';
import '../school_life.dart';
import '../store.dart';
import 'agenda_page.dart' show addAgendaDialog, mySubjects, openAgenda;
import 'customize_pages.dart' show nicknameCandidates;
import 'photos_page.dart' show openPhotos;
import 'school_life_pages.dart';
import 'search_page.dart' show openSchedule;
import 'widgets.dart';

// Pagine della 2.6: calendario del mese, piano di studio, crediti, prof, materiale,
// conti alla rovescia, ricerca globale, grafici, modalità verifica, orario cambiato.

void _push(BuildContext context, Widget page) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

void openMonth(BuildContext context) => _push(context, const MonthPage());
void openStudyPlan(BuildContext context) => _push(context, const StudyPlanPage());
void openCredits(BuildContext context) => _push(context, const CreditsPage());
void openTeachers(BuildContext context) => _push(context, const TeachersPage());
void openMaterials(BuildContext context) => _push(context, const MaterialsPage());
void openCountdowns(BuildContext context) => _push(context, const CountdownsPage());
void openGlobalSearch(BuildContext context) => _push(context, const GlobalSearchPage());
void openCharts(BuildContext context) => _push(context, const ChartsPage());
void openExamMode(BuildContext context, {int? minutes}) => _push(context, ExamModePage(minutes: minutes));

Widget _list(List<Widget> children, {EdgeInsets padding = const EdgeInsets.fromLTRB(20, 8, 20, 96)}) => Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: ListView(padding: padding, children: children),
      ),
    );

const _months = [
  'Gennaio', 'Febbraio', 'Marzo', 'Aprile', 'Maggio', 'Giugno',
  'Luglio', 'Agosto', 'Settembre', 'Ottobre', 'Novembre', 'Dicembre',
];

// ---------------------------------------------------------------------------
// Calendario del mese

class MonthPage extends StatefulWidget {
  const MonthPage({super.key});

  @override
  State<MonthPage> createState() => _MonthPageState();
}

class _MonthPageState extends State<MonthPage> {
  late DateTime _month;
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _selected = dateOnly(now);
  }

  /// Tutto quello che succede in un giorno: (emoji, testo).
  List<(String, String)> _events(AppStore store, DateTime d) {
    final out = <(String, String)>[];
    final c = store.calendar.closureOn(d);
    if (c != null && d.weekday <= 6) out.add((c.emoji, c.name));
    for (final a in store.agenda.where((a) => a.date == d)) {
      out.add((a.emoji, '${a.label}${a.subject.isEmpty ? '' : ' · ${a.subject}'}${a.text.isEmpty ? '' : ': ${a.text}'}'));
    }
    for (final a in store.absences.where((a) => a.date == d)) {
      out.add((a.emoji, a.label));
    }
    for (final g in store.grades.where((g) => g.date == d)) {
      out.add(('📊', '${Grade.format(g.value)} in ${g.subject}'));
    }
    for (final e in store.countdowns.where((e) => e.date == d)) {
      out.add((e.emoji, e.name));
    }
    if (store.photos.any((p) => p.date == d)) out.add(('📸', '${store.photos.where((p) => p.date == d).length} foto'));
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final first = DateTime(_month.year, _month.month);
    final daysIn = DateTime(_month.year, _month.month + 1, 0).day;
    final lead = first.weekday - 1;
    final today = dateOnly(DateTime.now());
    final events = _events(store, _selected);

    Widget cell(int day) {
      final d = DateTime(_month.year, _month.month, day);
      final ev = _events(store, d);
      final closed = store.calendar.closureOn(d) != null || d.weekday == 7;
      final sel = d == _selected;
      final hasTest = store.agenda.any((a) => a.date == d && !a.done && (a.kind == 'verifica' || a.kind == 'interrogazione'));
      return InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _selected = d),
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: sel ? scheme.primaryContainer : (closed ? scheme.surfaceContainerHighest.withAlpha(120) : null),
            borderRadius: BorderRadius.circular(12),
            border: d == today ? Border.all(color: scheme.primary, width: 2) : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('$day',
                  style: TextStyle(
                    fontWeight: d == today ? FontWeight.w800 : FontWeight.w500,
                    color: closed ? scheme.onSurfaceVariant : null,
                  )),
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final _ in ev.take(3))
                    Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(shape: BoxShape.circle, color: hasTest ? scheme.error : scheme.primary),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendario'),
        actions: [
          IconButton(
            tooltip: 'Oggi',
            icon: const Icon(Icons.today_rounded),
            onPressed: () => setState(() {
              _month = DateTime(today.year, today.month);
              _selected = today;
            }),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Aggiungi in agenda',
        onPressed: () => addAgendaDialog(context, date: _selected),
        child: const Icon(Icons.add_rounded),
      ),
      body: _list([
        Row(
          children: [
            IconButton(
              onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Expanded(
              child: Text('${_months[_month.month - 1]} ${_month.year}',
                  textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
            ),
            IconButton(
              onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 0.95,
          children: [
            for (final d in dayShort) Center(child: Text(d, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12))),
            for (var i = 0; i < lead; i++) const SizedBox(),
            for (var d = 1; d <= daysIn; d++) cell(d),
          ],
        ),
        const SizedBox(height: 8),
        Text('${dayNames[_selected.weekday - 1]} ${_selected.day} ${_months[_selected.month - 1].toLowerCase()}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        if (events.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Niente in programma', style: TextStyle(color: scheme.onSurfaceVariant)),
          ),
        for (final e in events)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: Text(e.$1, style: const TextStyle(fontSize: 22)),
            title: Text(e.$2),
          ),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Piano di studio

class StudyPlanPage extends StatelessWidget {
  const StudyPlanPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final days = store.opt('plan.days', 3);
    final plan = studyPlan(store.agenda, now, days: days);
    final byDay = <DateTime, List<StudyStep>>{};
    for (final p in plan) {
      (byDay[p.day] ??= []).add(p);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Piano di studio')),
      body: _list([
        Text(
          'Per ogni verifica e interrogazione in agenda, il ripasso viene diviso sui giorni prima. '
          'Con la notifica attiva (Impostazioni → Notifiche) ogni pomeriggio ti ricorda cosa fare.',
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Expanded(child: Text('Giorni di ripasso')),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 2, label: Text('2')),
                ButtonSegment(value: 3, label: Text('3')),
                ButtonSegment(value: 5, label: Text('5')),
                ButtonSegment(value: 7, label: Text('7')),
              ],
              selected: {days},
              onSelectionChanged: (s) => store.setOpt('plan.days', s.first == 3 ? null : s.first),
            ),
          ],
        ),
        if (plan.isEmpty) ...[
          const SizedBox(height: 32),
          const Center(child: Text('Nessuna verifica nei prossimi 14 giorni 🎉')),
          const SizedBox(height: 12),
          Center(
            child: OutlinedButton.icon(
              onPressed: () => openAgenda(context),
              icon: const Icon(Icons.event_note_rounded),
              label: const Text('Apri l\'agenda'),
            ),
          ),
        ],
        for (final e in byDay.entries) ...[
          SectionLabel(friendlyDate(e.key, now)),
          for (final p in e.value)
            Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                leading: Text(p.item.emoji, style: const TextStyle(fontSize: 24)),
                title: Text(p.item.subject.isEmpty ? p.item.label : p.item.subject),
                subtitle: Text('${p.item.label} ${friendlyDate(p.item.date, e.key).toLowerCase()}'
                    '${p.item.text.isEmpty ? '' : ' · ${p.item.text}'}\nRipasso ${p.part} di ${p.of}'),
                isThreeLine: true,
                trailing: IconButton(
                  tooltip: 'Studia adesso',
                  icon: const Icon(Icons.timer_outlined),
                  onPressed: () => openStudyTimer(context, subject: p.item.subject),
                ),
              ),
            ),
        ],
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Crediti scolastici

class CreditsPage extends StatefulWidget {
  const CreditsPage({super.key});

  @override
  State<CreditsPage> createState() => _CreditsPageState();
}

class _CreditsPageState extends State<CreditsPage> {
  int _year = 3;
  double? _avg;
  final _manual = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_avg == null) {
      final store = StoreScope.read(context);
      final by = <String, List<Grade>>{};
      for (final g in store.grades) {
        (by[g.subject] ??= []).add(g);
      }
      if (by.isNotEmpty) {
        // Media dei voti in pagella (interi), come allo scrutinio.
        final marks = by.values.map((l) => reportCardMark(average(l)!)).toList();
        _avg = marks.reduce((a, b) => a + b) / marks.length;
        _manual.text = _avg!.toStringAsFixed(2);
      }
      _year = store.opt('credits.year', 3);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final theme = Theme.of(context);
    final m = double.tryParse(_manual.text.replaceAll(',', '.'));
    final band = m == null ? null : creditBand(m, _year);
    final prev = [store.opt('credits.3', 0), store.opt('credits.4', 0), store.opt('credits.5', 0)];
    final total = prev.fold<int>(0, (a, b) => a + b);
    return Scaffold(
      appBar: AppBar(title: const Text('Crediti scolastici')),
      body: _list([
        Text(
          'Dal 3º anno ogni anno vale dei crediti per la maturità (massimo 40 in tutto). '
          'Dipendono dalla media dei voti allo scrutinio, condotta compresa.',
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 3, label: Text('3º anno')),
            ButtonSegment(value: 4, label: Text('4º anno')),
            ButtonSegment(value: 5, label: Text('5º anno')),
          ],
          selected: {_year},
          onSelectionChanged: (s) {
            setState(() => _year = s.first);
            store.setOpt('credits.year', s.first == 3 ? null : s.first);
          },
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _manual,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Media (con la condotta)',
            helperText: _avg == null ? 'Scrivila tu' : 'Calcolata dai tuoi voti arrotondati: puoi cambiarla',
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  band == null ? (m == null ? '—' : 'Non ammesso') : '${band.$1} – ${band.$2}',
                  style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(band == null ? '' : 'crediti nel $_yearº anno'),
                if (band != null && m != null && m - m.floor() >= 0.5 && m < 10)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('Con una media alta nella fascia, di solito si prende il massimo 👍',
                        textAlign: TextAlign.center),
                  ),
              ],
            ),
          ),
        ),
        const SectionLabel('I tuoi crediti'),
        for (final y in [3, 4, 5])
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('$yº anno'),
            trailing: SizedBox(
              width: 120,
              child: DropdownButton<int>(
                isExpanded: true,
                value: prev[y - 3],
                items: [
                  const DropdownMenuItem(value: 0, child: Text('—')),
                  for (var c = 7; c <= 15; c++) DropdownMenuItem(value: c, child: Text('$c')),
                ],
                onChanged: (v) => store.setOpt('credits.$y', v == 0 ? null : v),
              ),
            ),
          ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Totale', style: TextStyle(fontWeight: FontWeight.w700)),
          trailing: Text('$total / 40', style: theme.textTheme.titleLarge),
        ),
        const SizedBox(height: 8),
        Text(
          'Tabella dell\'allegato A del D.Lgs. 62/2017. Il numero esatto lo decide il consiglio di classe.',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// I miei prof

Future<void> editTeacherDialog(BuildContext context, String name) async {
  final store = StoreScope.read(context);
  final info = store.teachers[name] ?? TeacherInfo();
  final email = TextEditingController(text: info.email);
  final office = TextEditingController(text: info.office);
  final note = TextEditingController(text: info.note);
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(nick(name)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email', hintText: 'nome.cognome@isrosselliaprilia.edu.it'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: office,
              decoration: const InputDecoration(labelText: 'Ricevimento', hintText: 'Es. martedì 10:30–11:30'),
            ),
            const SizedBox(height: 12),
            TextField(controller: note, maxLines: 3, decoration: const InputDecoration(labelText: 'Note')),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annulla')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Salva')),
      ],
    ),
  );
  if (ok == true) {
    await store.setTeacherInfo(name, TeacherInfo(email: email.text.trim(), office: office.text.trim(), note: note.text.trim()));
  }
}

class TeachersPage extends StatelessWidget {
  const TeachersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    // Prof del mio orario, con le materie.
    final subjectsOf = <String, Set<String>>{};
    final mine = store.myMainRef == null ? null : store.cached(store.myMainRef!);
    if (mine != null && !mine.ref.prof) {
      for (final d in mine.week.days) {
        for (final l in d.lessons) {
          if (l.isEmpty || l.rawLines.length < 2) continue;
          for (final p in l.rawLines[1].split(' · ')) {
            if (p.trim().isNotEmpty) (subjectsOf[p.trim()] ??= {}).add(l.title);
          }
        }
      }
    }
    final names = {...subjectsOf.keys, ...store.teachers.keys}.toList()..sort();
    return Scaffold(
      appBar: AppBar(title: const Text('I miei prof')),
      body: names.isEmpty
          ? const Center(child: Text('Imposta il tuo orario di classe per vedere i tuoi prof'))
          : _list([
              for (final n in names)
                Builder(builder: (context) {
                  final info = store.teachers[n];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      title: Text(nick(n), style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text([
                        if (subjectsOf[n] != null) subjectsOf[n]!.join(', '),
                        if (info != null && info.office.isNotEmpty) '🕐 Ricevimento: ${info.office}',
                        if (info != null && info.note.isNotEmpty) '📝 ${info.note}',
                      ].join('\n')),
                      isThreeLine: info != null && (info.office.isNotEmpty || info.note.isNotEmpty),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (info != null && info.email.isNotEmpty)
                            IconButton(
                              tooltip: 'Scrivi una email',
                              icon: Icon(Icons.mail_outline_rounded, color: scheme.primary),
                              onPressed: () => launchUrl(Uri(scheme: 'mailto', path: info.email)),
                            ),
                          IconButton(
                            tooltip: 'Dov\'è adesso',
                            icon: const Icon(Icons.person_search_rounded),
                            onPressed: () {
                              // Nel mio orario c'è solo il cognome: si cerca il nome completo tra i docenti.
                              final full = store.docenti.firstWhere(
                                (d) => d == n || teacherLabel(d) == n,
                                orElse: () => n,
                              );
                              openSchedule(context, ScheduleRef(full, prof: true));
                            },
                          ),
                        ],
                      ),
                      onTap: () => editTeacherDialog(context, n),
                    ),
                  );
                }),
            ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Libri, materiale e promemoria settimanali

class MaterialsPage extends StatelessWidget {
  const MaterialsPage({super.key});

  Future<void> _editSubject(BuildContext context, String subject) async {
    final store = StoreScope.read(context);
    final ctrl = TextEditingController(text: (store.materials[subject] ?? const []).join('\n'));
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(subject),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 6,
          decoration: const InputDecoration(
            labelText: 'Cosa portare (una cosa per riga)',
            hintText: '📕 Libro di storia vol. 1\n📓 Quaderno a quadretti',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annulla')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Salva')),
        ],
      ),
    );
    if (ok == true) await store.setMaterials(subject, ctrl.text.split('\n'));
  }

  Future<void> _addWeekly(BuildContext context) async {
    final store = StoreScope.read(context);
    final ctrl = TextEditingController();
    var day = 1;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setState) => AlertDialog(
          title: const Text('Ogni settimana'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 6,
                children: [
                  for (var d = 1; d <= 6; d++)
                    ChoiceChip(label: Text(dayShort[d - 1]), selected: day == d, onSelected: (_) => setState(() => day = d)),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Cosa portare', hintText: 'Es. 💶 Soldi per la merenda'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annulla')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Aggiungi')),
          ],
        ),
      ),
    );
    if (ok == true) await store.addWeeklyItem(day, ctrl.text);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final subjects = nicknameCandidates(store).subjects;
    return Scaffold(
      appBar: AppBar(title: const Text('Libri e materiale')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addWeekly(context),
        icon: const Icon(Icons.repeat_rounded),
        label: const Text('Ogni settimana'),
      ),
      body: _list([
        Text('Tutto finisce nello zaino del giorno giusto e nel riepilogo della sera.',
            style: TextStyle(color: scheme.onSurfaceVariant)),
        if (store.weeklyItems.isNotEmpty) ...[
          const SectionLabel('Ogni settimana'),
          for (final w in [...store.weeklyItems]..sort((a, b) => a.weekday.compareTo(b.weekday)))
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(child: Text(dayShort[w.weekday - 1])),
              title: Text(w.item),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: () => store.removeWeeklyItem(w),
              ),
            ),
        ],
        const SectionLabel('Per materia'),
        if (subjects.isEmpty) const Text('Salva il tuo orario per vedere le materie.'),
        for (final s in subjects)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(decorateSubject(s)),
            subtitle: store.materials[s] == null ? null : Text(store.materials[s]!.join(' · ')),
            trailing: const Icon(Icons.edit_outlined, size: 20),
            onTap: () => _editSubject(context, s),
          ),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Conti alla rovescia personali

class CountdownsPage extends StatelessWidget {
  const CountdownsPage({super.key});

  Future<void> _add(BuildContext context) async {
    final store = StoreScope.read(context);
    final name = TextEditingController();
    var emoji = '🎉';
    var date = DateTime.now().add(const Duration(days: 7));
    const emojis = ['🎉', '🎂', '🚌', '✈️', '🏖️', '🎄', '⚽', '🎤', '🎮', '❤️', '📝', '🏆'];
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setState) => AlertDialog(
          title: const Text('Nuovo conto alla rovescia'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: name,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Cosa', hintText: 'Gita a Firenze, compleanno di…'),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 4,
                children: [
                  for (final e in emojis)
                    ChoiceChip(label: Text(e), selected: emoji == e, onSelected: (_) => setState(() => emoji = e)),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.event_rounded),
                label: Text('${date.day}/${date.month}/${date.year}'),
                onPressed: () async {
                  final d = await showDatePicker(
                    context: c,
                    initialDate: date,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 730)),
                  );
                  if (d != null) setState(() => date = d);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annulla')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Aggiungi')),
          ],
        ),
      ),
    );
    if (ok == true && name.text.trim().isNotEmpty) await store.addCountdown(name.text, date, emoji);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final theme = Theme.of(context);
    final today = dateOnly(DateTime.now());
    return Scaffold(
      appBar: AppBar(title: const Text('Conti alla rovescia')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Aggiungi'),
      ),
      body: store.countdowns.isEmpty
          ? const Center(child: Text('Aggiungi una gita, un compleanno o quello che aspetti: compare nella home'))
          : _list([
              for (final e in store.countdowns)
                Builder(builder: (context) {
                  final left = daysBetweenDates(today, e.date);
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      leading: Text(e.emoji, style: const TextStyle(fontSize: 30)),
                      title: Text(e.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('${dayNames[e.date.weekday - 1]} ${e.date.day}/${e.date.month}/${e.date.year}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            left < 0 ? 'passato' : (left == 0 ? 'OGGI!' : '$left gg'),
                            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          IconButton(icon: const Icon(Icons.delete_outline_rounded), onPressed: () => store.removeCountdown(e)),
                        ],
                      ),
                    ),
                  );
                }),
            ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Ricerca in tutto

class GlobalSearchPage extends StatefulWidget {
  const GlobalSearchPage({super.key});

  @override
  State<GlobalSearchPage> createState() => _GlobalSearchPageState();
}

class _GlobalSearchPageState extends State<GlobalSearchPage> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final q = normalizeSearch(_q);
    bool has(String s) => q.isNotEmpty && normalizeSearch(s).contains(q);
    final results = <(IconData, String, String, VoidCallback)>[];
    if (q.isNotEmpty) {
      for (final c in store.classi.where(has).take(5)) {
        results.add((Icons.groups_rounded, c.toUpperCase(), 'Classe', () => openSchedule(context, ScheduleRef(c, prof: false))));
      }
      for (final d in store.docenti.where((d) => has(d) || has(nick(teacherLabel(d)))).take(5)) {
        results.add((Icons.person_rounded, nick(teacherLabel(d)), 'Docente', () => openSchedule(context, ScheduleRef(d, prof: true))));
      }
      for (final s in mySubjects(store).where(has)) {
        results.add((Icons.menu_book_rounded, s, 'Materia · foto e agenda', () => openPhotos(context, subject: s)));
      }
      for (final a in store.agenda.where((a) => has(a.subject) || has(a.text) || has(a.label))) {
        results.add((Icons.event_note_rounded, a.summary, friendlyDate(a.date, DateTime.now()), () => openAgenda(context)));
      }
      for (final g in store.grades.where((g) => has(g.subject) || has(g.note))) {
        results.add((Icons.grade_outlined, '${Grade.format(g.value)} · ${g.subject}', '${g.date.day}/${g.date.month}${g.note.isEmpty ? '' : ' · ${g.note}'}',
            () => openGrades(context)));
      }
      for (final e in store.teachers.entries.where((e) => has(e.key) || has(e.value.note) || has(e.value.email))) {
        results.add((Icons.contact_mail_outlined, nick(e.key), e.value.office.isEmpty ? e.value.email : 'Ricevimento: ${e.value.office}',
            () => openTeachers(context)));
      }
      for (final a in store.absences.where((a) => has(a.note) || has(a.label))) {
        results.add((Icons.event_busy_outlined, a.label, '${a.date.day}/${a.date.month}${a.note.isEmpty ? '' : ' · ${a.note}'}',
            () => openAbsences(context)));
      }
      for (final e in store.countdowns.where((e) => has(e.name))) {
        results.add((Icons.hourglass_top_rounded, '${e.emoji} ${e.name}', '${e.date.day}/${e.date.month}', () => openCountdowns(context)));
      }
    }
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Cerca in tutto: prof, classi, compiti, voti…', border: InputBorder.none),
          onChanged: (v) => setState(() => _q = v),
        ),
      ),
      body: q.isEmpty
          ? const Center(child: Text('Scrivi qualcosa 🔎'))
          : results.isEmpty
              ? const Center(child: Text('Nessun risultato'))
              : ListView(
                  children: [
                    for (final r in results)
                      ListTile(leading: Icon(r.$1), title: Text(r.$2), subtitle: Text(r.$3), onTap: r.$4),
                  ],
                ),
    );
  }
}

// ---------------------------------------------------------------------------
// Grafici

class ChartsPage extends StatefulWidget {
  const ChartsPage({super.key});

  @override
  State<ChartsPage> createState() => _ChartsPageState();
}

class _ChartsPageState extends State<ChartsPage> {
  String? _subject;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final subjects = store.grades.map((g) => g.subject).toSet().toList()..sort();
    final grades = store.grades.where((g) => _subject == null || g.subject == _subject);
    final trend = runningAverage(grades);
    final study = weeklyStudy(store.studyLog, DateTime.now());
    return Scaffold(
      appBar: AppBar(title: const Text('Grafici')),
      body: _list([
        const SectionLabel('Andamento della media'),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ChoiceChip(label: const Text('Tutte'), selected: _subject == null, onSelected: (_) => setState(() => _subject = null)),
            for (final s in subjects)
              ChoiceChip(label: Text(s), selected: _subject == s, onSelected: (_) => setState(() => _subject = s)),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: trend.length < 2
              ? Center(child: Text('Servono almeno 2 voti', style: TextStyle(color: scheme.onSurfaceVariant)))
              : CustomPaint(
                  painter: _LinePainter(
                    points: [for (final p in trend) p.$2],
                    raw: [for (final g in (grades.toList()..sort((a, b) => a.date.compareTo(b.date)))) g.value],
                    color: scheme.primary,
                    dots: scheme.tertiary,
                    grid: scheme.outlineVariant,
                    label: scheme.onSurfaceVariant,
                  ),
                ),
        ),
        if (trend.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Linea: media che cambia voto dopo voto · Punti: i singoli voti',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
            ),
          ),
        const SectionLabel('Studio delle ultime 8 settimane'),
        SizedBox(
          height: 180,
          child: study.every((w) => w.$2 == 0)
              ? Center(child: Text('Usa il timer per studiare e qui vedrai i minuti', style: TextStyle(color: scheme.onSurfaceVariant)))
              : CustomPaint(
                  painter: _BarPainter(
                    values: [for (final w in study) w.$2],
                    labels: [for (final w in study) '${w.$1.day}/${w.$1.month}'],
                    color: scheme.primary,
                    label: scheme.onSurfaceVariant,
                  ),
                ),
        ),
      ]),
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter({required this.points, required this.raw, required this.color, required this.dots, required this.grid, required this.label});
  final List<double> points;
  final List<double> raw;
  final Color color;
  final Color dots;
  final Color grid;
  final Color label;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 28.0;
    final w = size.width - left - 8;
    final h = size.height - 16;
    double y(double v) => 8 + h - (v - 2) / 8 * h; // scala 2..10
    final gp = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var v = 2; v <= 10; v += 2) {
      canvas.drawLine(Offset(left, y(v.toDouble())), Offset(size.width - 8, y(v.toDouble())), gp);
      final tp = TextPainter(
        text: TextSpan(text: '$v', style: TextStyle(color: label, fontSize: 11)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(4, y(v.toDouble()) - tp.height / 2));
    }
    // Linea del 6.
    canvas.drawLine(
      Offset(left, y(6)),
      Offset(size.width - 8, y(6)),
      Paint()
        ..color = Colors.orange.withAlpha(150)
        ..strokeWidth = 1.5,
    );
    double x(int i) => left + (points.length == 1 ? w / 2 : i * w / (points.length - 1));
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final p = Offset(x(i), y(points[i].clamp(2, 10).toDouble()));
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    for (var i = 0; i < raw.length; i++) {
      canvas.drawCircle(Offset(x(i), y(raw[i].clamp(2, 10).toDouble())), 4, Paint()..color = dots);
    }
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) => old.points != points || old.color != color;
}

class _BarPainter extends CustomPainter {
  _BarPainter({required this.values, required this.labels, required this.color, required this.label});
  final List<int> values;
  final List<String> labels;
  final Color color;
  final Color label;

  @override
  void paint(Canvas canvas, Size size) {
    final maxV = math.max(1, values.reduce(math.max));
    final n = values.length;
    final slot = size.width / n;
    final h = size.height - 34;
    for (var i = 0; i < n; i++) {
      final bh = values[i] / maxV * h;
      final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(i * slot + slot * 0.2, 16 + h - bh, slot * 0.6, bh),
        const Radius.circular(6),
      );
      canvas.drawRRect(r, Paint()..color = color);
      final v = values[i];
      final top = TextPainter(
        text: TextSpan(text: v == 0 ? '' : (v < 60 ? '${v}m' : '${(v / 60).toStringAsFixed(1)}h'), style: TextStyle(color: label, fontSize: 10)),
        textDirection: TextDirection.ltr,
      )..layout();
      top.paint(canvas, Offset(i * slot + (slot - top.width) / 2, 16 + h - bh - top.height));
      final tp = TextPainter(
        text: TextSpan(text: labels[i], style: TextStyle(color: label, fontSize: 10)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(i * slot + (slot - tp.width) / 2, size.height - tp.height));
    }
  }

  @override
  bool shouldRepaint(covariant _BarPainter old) => old.values != values;
}

// ---------------------------------------------------------------------------
// Modalità verifica

class ExamModePage extends StatefulWidget {
  const ExamModePage({super.key, this.minutes});
  final int? minutes;

  @override
  State<ExamModePage> createState() => _ExamModePageState();
}

class _ExamModePageState extends State<ExamModePage> {
  static const _notifyId = 7001;
  int _minutes = 50;
  DateTime? _end;
  Timer? _tick;
  bool _silenced = false;

  @override
  void initState() {
    super.initState();
    _minutes = widget.minutes ?? 50;
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _stop();
    super.dispose();
  }

  Future<void> _start() async {
    final end = DateTime.now().add(Duration(minutes: _minutes));
    final store = StoreScope.read(context);
    final silence = store.opt('exam.silence', true);
    store.setOpt('ach.exam', true);
    setState(() => _end = end);
    await NativeBridge.keepScreenOn(true);
    if (silence && await NativeBridge.silenceAllowed()) {
      await NativeBridge.silenceNow(true);
      _silenced = true;
    }
    await NativeBridge.scheduleOne(_notifyId, end, 'Tempo scaduto! ⏰', 'La verifica è finita: consegna!');
  }

  void _stop() {
    NativeBridge.keepScreenOn(false);
    NativeBridge.cancelOne(_notifyId);
    if (_silenced) NativeBridge.silenceNow(false);
    _silenced = false;
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final running = _end != null;
    final left = running ? _end!.difference(DateTime.now()) : Duration(minutes: _minutes);
    final over = left.isNegative;
    final abs = left.abs();
    final hh = abs.inHours;
    final mm = (abs.inMinutes % 60).toString().padLeft(2, '0');
    final ss = (abs.inSeconds % 60).toString().padLeft(2, '0');
    final warn = running && !over && left.inMinutes < 10;
    final bg = over ? scheme.errorContainer : (warn ? Colors.orange.withAlpha(60) : scheme.surface);
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        title: const Text('Modalità verifica'),
        actions: [
          if (running)
            TextButton(
              onPressed: () {
                _stop();
                setState(() => _end = null);
              },
              child: const Text('Termina'),
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(over ? 'TEMPO SCADUTO' : (running ? 'TEMPO RIMASTO' : 'DURATA'),
                    style: TextStyle(letterSpacing: 2, color: scheme.onSurfaceVariant)),
                FittedBox(
                  child: Text(
                    '${over ? '+' : ''}${hh > 0 ? '$hh:' : ''}$mm:$ss',
                    style: const TextStyle(fontSize: 120, fontWeight: FontWeight.w800, fontFeatures: [FontFeature.tabularFigures()]),
                  ),
                ),
                if (running && !over)
                  Text('Finisce alle ${TimeSlot.fmt(_end!.hour * 60 + _end!.minute)}',
                      style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 18)),
                const SizedBox(height: 24),
                if (!running) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final m in [30, 50, 60, 100, 120, 180])
                        ChoiceChip(
                          label: Text(m < 60 || m % 60 != 0 ? '$m min' : '${m ~/ 60} h'),
                          selected: _minutes == m,
                          onSelected: (_) => setState(() => _minutes = m),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Non disturbare durante la verifica'),
                    value: store.opt('exam.silence', true),
                    onChanged: (v) => store.setOpt('exam.silence', v ? null : false),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _start,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Inizia'),
                    style: FilledButton.styleFrom(minimumSize: const Size(200, 56)),
                  ),
                ],
                if (running)
                  Text(
                    over ? 'Consegna! 📄' : (warn ? 'Ultimi minuti: ricontrolla tutto 👀' : 'In bocca al lupo! 🍀'),
                    style: const TextStyle(fontSize: 22),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Orario cambiato

Future<void> showScheduleChanges(BuildContext context) async {
  final store = StoreScope.read(context);
  final list = store.scheduleChanges;
  if (list == null) return;
  await showDialog<void>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('L\'orario è cambiato! 🔄'),
      content: SizedBox(
        width: 420,
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final l in list)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text('• $l'),
              ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () {
            store.dismissScheduleChanges();
            Navigator.pop(c);
          },
          child: const Text('Ho capito'),
        ),
      ],
    ),
  );
}

/// Banner nella home quando l'orario è cambiato.
class ScheduleChangedBanner extends StatelessWidget {
  const ScheduleChangedBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final list = store.scheduleChanges;
    if (list == null || list.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Material(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => showScheduleChanges(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                const Text('🔄', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'L\'orario è cambiato: ${list.length == 1 ? list.first : '${list.length} modifiche'}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: scheme.onTertiaryContainer, fontWeight: FontWeight.w600),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: scheme.onTertiaryContainer),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

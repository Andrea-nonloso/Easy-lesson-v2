import 'package:flutter/material.dart';

import '../activity_xp.dart';
import '../exam_prep.dart';
import '../i18n.dart';
import '../store.dart';
import 'agenda_page.dart' show mySubjects;
import 'widgets.dart';

// Maturità (3.9): conto alla rovescia, argomenti da spuntare per materia, lista pratica.

void openExamPrep(BuildContext context) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ExamPrepPage()));

const _topicXp = 2;

String _date(DateTime d) => '${d.day}/${d.month}/${d.year}';

class ExamPrepPage extends StatelessWidget {
  const ExamPrepPage({super.key});

  Future<void> _edit(BuildContext context, void Function(ExamPlan p) change) async {
    final store = StoreScope.read(context);
    final p = ExamPlan.load(store);
    change(p);
    await p.save(store);
  }

  Future<void> _pickDate(BuildContext context, ExamPlan plan) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: plan.date ?? defaultExamDate(now),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
      helpText: tr('Giorno della prima prova', 'Day of the first test'),
    );
    if (d != null && context.mounted) await _edit(context, (p) => p.date = d);
  }

  Future<void> _addSubject(BuildContext context) async {
    final store = StoreScope.read(context);
    final plan = ExamPlan.load(store);
    final have = {for (final s in plan.subjects) s.name};
    final choices = [for (final s in mySubjects(store)) if (!have.contains(s)) s];
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('Aggiungi materia', 'Add subject')),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (choices.isNotEmpty)
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final s in choices) ActionChip(label: Text(s), onPressed: () => Navigator.pop(c, s)),
              ]),
            TextField(
              controller: ctrl,
              maxLength: 40,
              decoration: InputDecoration(labelText: tr('Oppure scrivila', 'Or type it')),
              onSubmitted: (v) => Navigator.pop(c, v),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(tr('Annulla', 'Cancel'))),
          FilledButton(onPressed: () => Navigator.pop(c, ctrl.text), child: Text(tr('Aggiungi', 'Add'))),
        ],
      ),
    );
    final n = name?.trim() ?? '';
    if (n.isEmpty || !context.mounted) return;
    await _edit(context, (p) {
      if (p.subjects.length < maxExamSubjects && !p.subjects.any((s) => s.name == n)) {
        p.subjects.add(ExamSubject(id: '${DateTime.now().microsecondsSinceEpoch}', name: n));
      }
    });
  }

  Future<void> _addTopics(BuildContext context, ExamSubject subject) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('Argomenti di ${subject.name}', '${subject.name} topics')),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: ctrl,
            autofocus: true,
            minLines: 4,
            maxLines: 10,
            decoration: InputDecoration(
              helperText: tr('Uno per riga: puoi incollare il programma', 'One per line: you can paste the syllabus'),
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('Annulla', 'Cancel'))),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(tr('Aggiungi', 'Add'))),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final lines = [
      for (final l in ctrl.text.split('\n'))
        if (l.trim().replaceFirst(RegExp(r'^[-•*\d.)\s]+'), '').trim() case final t when t.isNotEmpty) t,
    ];
    var i = 0;
    await _edit(context, (p) {
      final s = p.subjects.where((x) => x.id == subject.id).firstOrNull;
      if (s == null) return;
      for (final t in lines) {
        if (s.topics.length >= maxTopicsPerSubject) break;
        s.topics.add(ExamTopic(id: '${DateTime.now().microsecondsSinceEpoch}${i++}', text: t.length > 120 ? t.substring(0, 120) : t));
      }
    });
  }

  Future<void> _toggleTopic(BuildContext context, String subjectId, String topicId) async {
    final store = StoreScope.read(context);
    var nowDone = false;
    await _edit(context, (p) {
      final t = p.subjects.where((x) => x.id == subjectId).firstOrNull?.topics.where((x) => x.id == topicId).firstOrNull;
      if (t == null) return;
      t.done = !t.done;
      nowDone = t.done;
    });
    if (nowDone && await awardActivityXpOnce(store, 'exam:$topicId', _topicXp) > 0) await store.bump('examTopics');
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final plan = ExamPlan.load(store);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final now = DateTime.now();
    final left = plan.daysLeft(now);
    final perDay = plan.topicsPerDay(now);
    return Scaffold(
      appBar: AppBar(title: Text(tr('Maturità', 'Final exam'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addSubject(context),
        icon: const Icon(Icons.add_rounded),
        label: Text(tr('Materia', 'Subject')),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 96), children: [
            Card(
              color: scheme.primaryContainer,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _pickDate(context, plan),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Text('🎓', style: TextStyle(fontSize: 34)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(
                            left == null
                                ? tr('Quando è la prima prova?', 'When is the first test?')
                                : left > 0
                                    ? tr('Mancano $left giorni', '$left days to go')
                                    : left == 0
                                        ? tr('È oggi! In bocca al lupo 🍀', 'It\'s today! Good luck 🍀')
                                        : tr('Esame passato', 'Exam is over'),
                            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          Text(plan.date == null ? tr('Tocca per scegliere la data', 'Tap to set the date') : _date(plan.date!)),
                        ]),
                      ),
                      const Icon(Icons.edit_calendar_rounded),
                    ]),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(value: plan.progress, minHeight: 10),
                    ),
                    const SizedBox(height: 6),
                    Text(tr('${(plan.progress * 100).round()}% pronto · ${plan.topicsDone}/${plan.topicsTotal} argomenti',
                        '${(plan.progress * 100).round()}% ready · ${plan.topicsDone}/${plan.topicsTotal} topics')),
                    if (perDay != null && perDay > 0)
                      Text(tr('Per finire una settimana prima: ${perDay.toStringAsFixed(1)} argomenti al giorno',
                          'To finish a week early: ${perDay.toStringAsFixed(1)} topics a day')),
                  ]),
                ),
              ),
            ),
            SectionLabel(tr('Materie', 'Subjects')),
            if (plan.subjects.isEmpty)
              Text(tr('Aggiungi le materie dell\'esame e incolla gli argomenti del programma: li spunti man mano che li ripassi.',
                  'Add your exam subjects and paste the syllabus topics: tick them as you review.')),
            for (final s in plan.subjects)
              Card(
                child: ExpansionTile(
                  shape: const Border(),
                  title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(tr('${s.done}/${s.topics.length} argomenti', '${s.done}/${s.topics.length} topics')),
                  leading: SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(
                      value: s.topics.isEmpty ? 0 : s.done / s.topics.length,
                      backgroundColor: scheme.surfaceContainerHighest,
                    ),
                  ),
                  children: [
                    for (final t in s.topics)
                      Dismissible(
                        key: ValueKey(t.id),
                        direction: DismissDirection.endToStart,
                        background: Container(color: scheme.errorContainer),
                        onDismissed: (_) => _edit(context, (p) => p.subjects.where((x) => x.id == s.id).firstOrNull?.topics.removeWhere((x) => x.id == t.id)),
                        child: CheckboxListTile(
                          dense: true,
                          value: t.done,
                          title: Text(t.text, style: t.done ? const TextStyle(decoration: TextDecoration.lineThrough) : null),
                          onChanged: (_) => _toggleTopic(context, s.id, t.id),
                        ),
                      ),
                    OverflowBar(alignment: MainAxisAlignment.end, children: [
                      TextButton.icon(
                        onPressed: () => _edit(context, (p) => p.subjects.removeWhere((x) => x.id == s.id)),
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: Text(tr('Togli materia', 'Remove subject')),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () => _addTopics(context, s),
                        icon: const Icon(Icons.playlist_add_rounded),
                        label: Text(tr('Argomenti', 'Topics')),
                      ),
                    ]),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            SectionLabel(tr('Da non dimenticare', 'Don\'t forget')),
            for (final (id, text) in examChecklist)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: plan.checks.contains(id),
                title: Text(text),
                onChanged: (v) => _edit(context, (p) => v == true ? p.checks.add(id) : p.checks.remove(id)),
              ),
          ]),
        ),
      ),
    );
  }
}

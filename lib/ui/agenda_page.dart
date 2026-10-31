import 'package:flutter/material.dart';

import '../agenda.dart';
import '../models.dart';
import '../store.dart';
import 'app_menu.dart';
import 'fun.dart';
import 'theme.dart';
import 'widgets.dart';

void openAgenda(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AgendaPage()));

/// Materie del proprio orario (per i suggerimenti).
List<String> mySubjects(AppStore store) {
  final ref = store.myRef;
  final cached = ref == null ? null : store.cached(ref);
  if (cached == null) return const [];
  final out = <String>{
    for (final d in cached.week.days)
      for (final l in d.lessons)
        if (!l.isEmpty) l.title,
  }.toList()
    ..sort();
  return out;
}

/// Dialogo "Aggiungi compito / verifica".
Future<void> addAgendaDialog(BuildContext context, {String subject = '', DateTime? date}) async {
  final store = StoreScope.read(context);
  final subjects = mySubjects(store);
  final subjectCtrl = TextEditingController(text: subject);
  final textCtrl = TextEditingController();
  var kind = 'verifica';
  var when = date ?? dateOnly(DateTime.now().add(const Duration(days: 1)));

  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setState) => AlertDialog(
        title: const Text('Aggiungi all\'agenda'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final k in AgendaItem.kinds)
                      ChoiceChip(
                        label: Text('${AgendaItem.emojiOf(k)} ${AgendaItem.labelOf(k)}'),
                        selected: kind == k,
                        onSelected: (_) => setState(() => kind = k),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: subjectCtrl,
                  decoration: const InputDecoration(labelText: 'Materia', isDense: true),
                ),
                if (subject.isEmpty && subjects.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final s in subjects.take(12))
                        ActionChip(
                          label: Text(s),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => setState(() => subjectCtrl.text = s),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: textCtrl,
                  autofocus: subject.isNotEmpty,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Cosa (es. "equazioni, pag. 120")', isDense: true),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.event_rounded),
                  label: Text('${friendlyDate(when, DateTime.now())} · ${when.day}/${when.month}/${when.year}'),
                  onPressed: () async {
                    final now = DateTime.now();
                    final d = await showDatePicker(
                      context: c,
                      initialDate: when,
                      firstDate: DateTime(now.year - 1),
                      lastDate: DateTime(now.year + 2),
                    );
                    if (d != null) setState(() => when = d);
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annulla')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Aggiungi')),
        ],
      ),
    ),
  );
  if (ok == true && (subjectCtrl.text.trim().isNotEmpty || textCtrl.text.trim().isNotEmpty)) {
    await store.addAgenda(date: when, kind: kind, subject: subjectCtrl.text, text: textCtrl.text);
  }
  subjectCtrl.dispose();
  textCtrl.dispose();
}

/// Scheda di una lezione: dettagli, agenda della materia e "aggiungi".
Future<void> showLessonSheet(
  BuildContext context, {
  required Lesson lesson,
  required int dayIndex,
  required String hoursLabel,
  int? endMinutes,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (c) {
      final store = StoreScope.of(c);
      final theme = Theme.of(c);
      final scheme = theme.colorScheme;
      final now = DateTime.now();
      final next = nextDateFor(dayIndex, now, endMinutes: endMinutes);
      final items = store.agendaFrom(now).where((a) => a.sameSubject(lesson.title)).toList();
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(lesson.title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              '${dayIndex < dayNames.length ? dayNames[dayIndex] : ''} · $hoursLabel',
              style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            if (lesson.details.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(lesson.details.join('\n')),
            ],
            if (lesson.lab.isNotEmpty) ...[
              const SizedBox(height: 10),
              Align(alignment: Alignment.centerLeft, child: LabBadge(lesson.lab)),
            ],
            if (lesson.sostegno.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Sostegno: ${lesson.sostegno.join(', ')}',
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            ],
            const SectionLabel('Agenda'),
            if (items.isEmpty)
              Text('Niente in programma per ${lesson.title}.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
            for (final a in items) _AgendaTile(item: a),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.add_rounded),
              label: Text('Aggiungi per ${friendlyDate(next, now).toLowerCase()}'),
              onPressed: () => addAgendaDialog(c, subject: lesson.title, date: next),
            ),
          ],
        ),
      );
    },
  );
}

class _AgendaTile extends StatelessWidget {
  const _AgendaTile({required this.item, this.showDate = true});

  final AgendaItem item;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.read(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: scheme.errorContainer,
        child: Icon(Icons.delete_outline_rounded, color: scheme.onErrorContainer),
      ),
      onDismissed: (_) => store.removeAgenda(item),
      child: CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        value: item.done,
        onChanged: (_) => store.toggleAgendaDone(item),
        title: Text(
          '${item.emoji} ${item.label}${item.subject.isEmpty ? '' : ' · ${item.subject}'}',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            decoration: item.done ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Text(
          [if (showDate) friendlyDate(item.date, DateTime.now()), if (item.text.isNotEmpty) item.text].join(' · '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

/// Tutta l'agenda, divisa per giorno.
class AgendaPage extends StatefulWidget {
  const AgendaPage({super.key});

  @override
  State<AgendaPage> createState() => _AgendaPageState();
}

class _AgendaPageState extends State<AgendaPage> {
  bool _showDone = false;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final theme = Theme.of(context);
    final now = DateTime.now();
    final items = store.agendaFrom(
      _showDone ? DateTime(now.year - 1) : now,
      includeDone: _showDone,
    );
    final byDay = <DateTime, List<AgendaItem>>{};
    for (final a in items) {
      (byDay[a.date] ??= []).add(a);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agenda'),
        actions: [
          IconButton(
            tooltip: _showDone ? 'Nascondi fatti e passati' : 'Mostra anche fatti e passati',
            onPressed: () => setState(() => _showDone = !_showDone),
            icon: Icon(_showDone ? Icons.visibility_off_outlined : Icons.history_rounded),
          ),
          const AppMenuButton(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => addAgendaDialog(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Aggiungi'),
      ),
      body: items.isEmpty
          ? const EmptyState(
              icon: Icons.event_available_rounded,
              title: 'Niente in agenda',
              message: 'Aggiungi compiti e verifiche da qui, oppure tocca una lezione nel tuo orario.',
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
                  children: [
                    for (final e in byDay.entries) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 16, bottom: 4),
                        child: Text(
                          '${friendlyDate(e.key, now)}  ·  ${e.key.day}/${e.key.month}',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Material(
                        color: cardColor(context),
                        borderRadius: BorderRadius.circular(18),
                        clipBehavior: Clip.antiAlias,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Column(children: [for (final a in e.value) _AgendaTile(item: a, showDate: false)]),
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

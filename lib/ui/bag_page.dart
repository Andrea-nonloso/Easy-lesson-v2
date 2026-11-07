import 'package:flutter/material.dart';

import '../agenda.dart';
import '../bag.dart';
import '../models.dart';
import '../school_extra.dart';
import '../store.dart';
import 'app_menu.dart';
import 'theme.dart';
import 'widgets.dart';
import '../i18n.dart';

void openBag(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const BagPage()));

/// Cosa serve per il prossimo giorno di scuola: materie, oggetti, compiti e verifiche.
class BagPlan {
  const BagPlan(this.date, this.subjects, this.items, this.agenda);

  final DateTime date;
  final List<String> subjects;
  final List<String> items;
  final List<AgendaItem> agenda;

  /// Tutto quello che si può spuntare.
  List<String> get checklist => [...items, for (final a in agenda) a.summary];
}

/// Piano dello zaino per il prossimo giorno di scuola del proprio orario.
BagPlan? bagPlanFor(AppStore store, DateTime now) {
  final ref = store.myRef;
  final cached = ref == null ? null : store.cached(ref);
  if (cached == null || cached.week.days.isEmpty) return null;
  final days = cached.week.days;
  final next = store.nextSchoolDay(now, daysPerWeek: days.length);
  if (next == null) return null;
  final wd = next.weekday - 1;
  if (wd >= days.length) return null;
  final day = days[wd];
  final subjects = subjectsOfDay(day);
  final agenda = store.agendaFrom(next, days: 1);
  final items = [...bagItems(day, store.bagRules)];
  for (final x in extraBagItems(day, next.weekday, store.materials, store.weeklyItems)) {
    if (!items.contains(x)) items.add(x);
  }
  return BagPlan(next, subjects, items, agenda);
}

class BagPage extends StatelessWidget {
  const BagPage({super.key});

  Future<void> _addRule(BuildContext context, AppStore store) async {
    final match = TextEditingController();
    final item = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('Nuova regola', 'New rule')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: match,
              autofocus: true,
              decoration: InputDecoration(labelText: tr('Se nell\'orario c\'è… (es. "inglese")', 'If the timetable has… (e.g. "English")'), isDense: true),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: item,
              decoration: InputDecoration(labelText: tr('porta… (es. "Dizionario 📕")', 'bring… (e.g. "Dictionary 📕")'), isDense: true),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('Annulla', 'Cancel'))),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(tr('Aggiungi', 'Add'))),
        ],
      ),
    );
    if (ok == true && match.text.trim().isNotEmpty && item.text.trim().isNotEmpty) {
      await store.setBagRules([...store.bagRules, BagRule(match.text.trim(), item.text.trim())]);
    }
    match.dispose();
    item.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final now = DateTime.now();
    final plan = bagPlanFor(store, now);
    final checked = plan == null ? const <String>{} : (store.bagChecked[AppStore.dayKey(plan.date)] ?? const <String>{});

    return Scaffold(
      appBar: AppBar(title: Text(tr('Zaino', 'Backpack')), actions: const [AppMenuButton(), SizedBox(width: 4)]),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            children: [
              if (plan == null)
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Text(tr('Imposta il tuo orario per sapere cosa portare il prossimo giorno di scuola.', 'Set your timetable to know what to bring on the next school day.')),
                )
              else ...[
                SectionLabel(tr('Per ${friendlyDate(plan.date, now).toLowerCase()} · '
                    '${dayNames[plan.date.weekday - 1]} ${plan.date.day}/${plan.date.month}', 'For ${friendlyDate(plan.date, now).toLowerCase()} · ')),
                if (plan.subjects.isNotEmpty)
                  Text('📚 ${tr('Libri e quaderni', 'Books and notebooks')}: ${plan.subjects.join(', ')}', style: theme.textTheme.bodyLarge),
                const SizedBox(height: 8),
                Material(
                  color: cardColor(context),
                  borderRadius: BorderRadius.circular(18),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      if (plan.checklist.isEmpty)
                        ListTile(title: Text(tr('Niente di speciale da portare 🎉', 'Nothing special to bring 🎉'))),
                      for (final it in plan.checklist)
                        CheckboxListTile(
                          value: checked.contains(it),
                          onChanged: (_) => store.toggleBagItem(plan.date, it),
                          title: Text(
                            it,
                            style: TextStyle(decoration: checked.contains(it) ? TextDecoration.lineThrough : null),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              SectionLabel(tr('Regole', 'Rules')),
              Text(
                tr('Se nella materia o nel laboratorio c\'è la parola a sinistra, nello zaino va quello a destra.', 'If the word on the left is in the subject or lab, what\'s on the right goes in the backpack.'),
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 6),
              for (final r in store.bagRules)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text('"${r.match}" → ${r.item}'),
                  trailing: IconButton(
                    tooltip: tr('Elimina', 'Delete'),
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => store.setBagRules([...store.bagRules]..remove(r)),
                  ),
                ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () => _addRule(context, store),
                    icon: const Icon(Icons.add_rounded),
                    label: Text(tr('Aggiungi regola', 'Add rule')),
                  ),
                  TextButton(
                    onPressed: () => store.setBagRules([...defaultBagRules]),
                    child: Text(tr('Ripristina', 'Restore')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

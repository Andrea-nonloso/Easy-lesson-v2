import 'package:flutter/material.dart';

import '../agenda.dart';
import '../bag.dart';
import '../models.dart';
import '../school_extra.dart';
import '../store.dart';
import 'app_menu.dart';
import 'theme.dart';
import 'widgets.dart';

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
        title: const Text('Nuova regola'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: match,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Se nell\'orario c\'è… (es. "inglese")', isDense: true),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: item,
              decoration: const InputDecoration(labelText: 'porta… (es. "Dizionario 📕")', isDense: true),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annulla')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Aggiungi')),
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
      appBar: AppBar(title: const Text('Zaino'), actions: const [AppMenuButton(), SizedBox(width: 4)]),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            children: [
              if (plan == null)
                const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: Text('Imposta il tuo orario per sapere cosa portare il prossimo giorno di scuola.'),
                )
              else ...[
                SectionLabel('Per ${friendlyDate(plan.date, now).toLowerCase()} · '
                    '${dayNames[plan.date.weekday - 1]} ${plan.date.day}/${plan.date.month}'),
                if (plan.subjects.isNotEmpty)
                  Text('📚 Libri e quaderni: ${plan.subjects.join(', ')}', style: theme.textTheme.bodyLarge),
                const SizedBox(height: 8),
                Material(
                  color: cardColor(context),
                  borderRadius: BorderRadius.circular(18),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      if (plan.checklist.isEmpty)
                        const ListTile(title: Text('Niente di speciale da portare 🎉')),
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
              const SectionLabel('Regole'),
              Text(
                'Se nella materia o nel laboratorio c\'è la parola a sinistra, nello zaino va quello a destra.',
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 6),
              for (final r in store.bagRules)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text('"${r.match}" → ${r.item}'),
                  trailing: IconButton(
                    tooltip: 'Elimina',
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
                    label: const Text('Aggiungi regola'),
                  ),
                  TextButton(
                    onPressed: () => store.setBagRules([...defaultBagRules]),
                    child: const Text('Ripristina'),
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

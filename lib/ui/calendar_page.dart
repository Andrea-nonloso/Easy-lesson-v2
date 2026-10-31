import 'package:flutter/material.dart';

import '../agenda.dart';
import '../school_calendar.dart';
import '../store.dart';
import 'app_menu.dart';
import 'widgets.dart';

void openSchoolCalendar(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SchoolCalendarPage()));

String _date(DateTime d) => '${d.day}/${d.month}/${d.year}';

/// Vacanze e feste dell'anno scolastico, più i giorni aggiunti a mano.
class SchoolCalendarPage extends StatelessWidget {
  const SchoolCalendarPage({super.key});

  Future<void> _add(BuildContext context, AppStore store) async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      helpText: 'Giorni senza scuola',
    );
    if (range == null || !context.mounted) return;
    final ctrl = TextEditingController(text: 'Ponte');
    final name = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Come si chiama?'),
        content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(isDense: true)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annulla')),
          FilledButton(onPressed: () => Navigator.pop(c, ctrl.text), child: const Text('Aggiungi')),
        ],
      ),
    );
    ctrl.dispose();
    if (name == null) return;
    await store.addClosure(Closure(
      dateOnly(range.start),
      dateOnly(range.end),
      name.trim().isEmpty ? 'Niente scuola' : name.trim(),
      '📌',
    ));
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final now = DateTime.now();
    final year = store.calendar.yearOf(now);
    final today = dateOnly(now);

    Widget tile(Closure c, {VoidCallback? onDelete}) {
      final past = c.to.isBefore(today);
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Text(c.emoji, style: const TextStyle(fontSize: 24)),
        title: Text(c.name, style: TextStyle(color: past ? scheme.onSurfaceVariant : null)),
        subtitle: Text(c.from == c.to ? _date(c.from) : 'dal ${_date(c.from)} al ${_date(c.to)}'),
        trailing: onDelete == null
            ? null
            : IconButton(tooltip: 'Elimina', onPressed: onDelete, icon: const Icon(Icons.delete_outline_rounded)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Calendario ${year?.label ?? ''}'),
        actions: const [AppMenuButton(), SizedBox(width: 4)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context, store),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Aggiungi ponte'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
            children: [
              if (year == null)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Text('Il calendario di quest\'anno non è ancora nell\'app: aggiungi i giorni a mano.'),
                )
              else ...[
                const SectionLabel('Anno scolastico'),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Text('🎒', style: TextStyle(fontSize: 24)),
                  title: const Text('Inizio delle lezioni'),
                  subtitle: Text(_date(year.start)),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Text('🏁', style: TextStyle(fontSize: 24)),
                  title: const Text('Fine delle lezioni'),
                  subtitle: Text(_date(year.end)),
                ),
                const SectionLabel('Vacanze e feste (Regione Lazio)'),
                for (final c in year.closures) tile(c),
              ],
              const SectionLabel('Aggiunti da te'),
              if (store.extraClosures.isEmpty)
                Text(
                  'Ponti e sospensioni decisi dalla scuola: aggiungili con il pulsante in basso.',
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              for (final c in store.extraClosures) tile(c, onDelete: () => store.removeClosure(c)),
            ],
          ),
        ),
      ),
    );
  }
}

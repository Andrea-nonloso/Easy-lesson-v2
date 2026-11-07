import 'package:flutter/material.dart';

import '../agenda.dart';
import '../school_calendar.dart';
import '../store.dart';
import 'app_menu.dart';
import 'widgets.dart';
import '../i18n.dart';

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
      helpText: tr('Giorni senza scuola', 'Days without school'),
    );
    if (range == null || !context.mounted) return;
    final ctrl = TextEditingController(text: tr('Ponte', 'Long weekend'));
    final name = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('Come si chiama?', 'What\'s it called?')),
        content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(isDense: true)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(tr('Annulla', 'Cancel'))),
          FilledButton(onPressed: () => Navigator.pop(c, ctrl.text), child: Text(tr('Aggiungi', 'Add'))),
        ],
      ),
    );
    ctrl.dispose();
    if (name == null) return;
    await store.addClosure(Closure(
      dateOnly(range.start),
      dateOnly(range.end),
      name.trim().isEmpty ? tr('Niente scuola', 'No school') : name.trim(),
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
        subtitle: Text(c.from == c.to ? _date(c.from) : tr('dal ${_date(c.from)} al ${_date(c.to)}', 'from ${_date(c.from)} to ${_date(c.to)}')),
        trailing: onDelete == null
            ? null
            : IconButton(tooltip: tr('Elimina', 'Delete'), onPressed: onDelete, icon: const Icon(Icons.delete_outline_rounded)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${tr('Calendario', 'Calendar')} ${year?.label ?? ''}'),
        actions: const [AppMenuButton(), SizedBox(width: 4)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context, store),
        icon: const Icon(Icons.add_rounded),
        label: Text(tr('Aggiungi ponte', 'Add a long weekend')),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
            children: [
              if (year == null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(tr('Il calendario di quest\'anno non è ancora nell\'app: aggiungi i giorni a mano.', 'This year\'s calendar isn\'t in the app yet: add the days by hand.')),
                )
              else ...[
                SectionLabel(tr('Anno scolastico', 'School year')),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Text('🎒', style: TextStyle(fontSize: 24)),
                  title: Text(tr('Inizio delle lezioni', 'First day of school')),
                  subtitle: Text(_date(year.start)),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Text('🏁', style: TextStyle(fontSize: 24)),
                  title: Text(tr('Fine delle lezioni', 'Last day of school')),
                  subtitle: Text(_date(year.end)),
                ),
                SectionLabel(tr('Vacanze e feste (Regione Lazio)', 'Holidays and celebrations (Lazio region)')),
                for (final c in year.closures) tile(c),
              ],
              SectionLabel(tr('Aggiunti da te', 'Added by you')),
              if (store.extraClosures.isEmpty)
                Text(
                  tr('Ponti e sospensioni decisi dalla scuola: aggiungili con il pulsante in basso.', 'Long weekends and closures decided by the school: add them with the button below.'),
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

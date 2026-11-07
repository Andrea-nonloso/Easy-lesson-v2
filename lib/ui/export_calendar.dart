import 'package:flutter/material.dart';

import '../ics.dart';
import '../store.dart';
import 'save_file_io.dart' if (dart.library.js_interop) 'save_file_web.dart';
import '../i18n.dart';

/// "Esporta nel calendario": salva un file .ics da aprire con Google Calendar,
/// Outlook o il Calendario di Windows. Le lezioni si ripetono ogni settimana fino a giugno.
Future<void> exportToCalendar(BuildContext context, CachedSchedule cached) async {
  final store = StoreScope.read(context);
  final messenger = ScaffoldMessenger.of(context);
  final ics = buildIcs(ref: cached.ref, week: cached.week, slots: store.slots);
  final safe = cached.ref.displayName.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
  try {
    final where = await saveTextFile('orario_$safe.ics', ics, mime: 'text/calendar');
    if (where == null) return; // annullato
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        duration: const Duration(seconds: 6),
        content: Text(where.isEmpty
            ? tr('Calendario pronto: aprilo con Google Calendar o Outlook per importare le lezioni', 'Calendar ready: open it with Google Calendar or Outlook to import the lessons')
            : tr('Salvato in $where: aprilo per importare le lezioni nel calendario', 'Saved in $where: open it to import the lessons into the calendar')),
      ));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(tr('Esportazione non riuscita: $e', 'Export failed: $e'))));
  }
}

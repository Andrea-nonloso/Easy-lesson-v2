import 'agenda.dart';
import 'i18n.dart';
import 'log.dart';
import 'social.dart';
import 'store.dart';

/// Verifiche segnate dalla classe (3.9): una "verifica" nella bacheca di classe confermata da almeno
/// [classTestConfirms] compagni entra da sola nell'agenda (si può spegnere: opzione "class.autoTests").
/// Ogni voce entra una volta sola (id ricordati in "class.imported"); se in agenda c'è già una verifica di quella
/// materia quel giorno, non si duplica.

const classTestConfirms = 3;
const _kImported = 'class.imported';
const _kLast = 'class.testsAt';

/// Voci da importare adesso. Pura, testata in test/class_tests_test.dart.
List<ClassItem> classTestsToImport(Iterable<ClassItem> items, Iterable<AgendaItem> agenda, Set<String> imported, DateTime now) {
  final today = dateOnly(now);
  return [
    for (final i in items)
      if (i.kind == 'test' &&
          i.confirms >= classTestConfirms &&
          !imported.contains(i.id) &&
          !dateOnly(i.date).isBefore(today) &&
          !agenda.any((a) => a.date == dateOnly(i.date) && (a.kind == 'verifica' || a.kind == 'interrogazione') && a.sameSubject(i.subject)))
        i,
  ];
}

class ClassTests {
  ClassTests._();

  static bool enabled(AppStore s) => s.opt('class.autoTests', true);

  /// Mette in agenda le verifiche confermate di [items] (di una classe già caricata). Restituisce quante.
  static Future<int> importFrom(AppStore s, Iterable<ClassItem> items, {DateTime? now}) async {
    if (!enabled(s)) return 0;
    final imported = {for (final x in s.opt<List<dynamic>?>(_kImported, null) ?? const []) '$x'};
    final todo = classTestsToImport(items, s.agenda, imported, now ?? DateTime.now());
    for (final i in todo) {
      await s.addAgenda(date: i.date, kind: 'verifica', subject: i.subject, text: tr('${i.title} (dalla classe)', '${i.title} (from class)'), count: false);
      imported.add(i.id);
    }
    if (todo.isNotEmpty) {
      final keep = imported.toList();
      await s.setOpt(_kImported, keep.sublist(keep.length > 300 ? keep.length - 300 : 0));
      AppLog.i('classe', 'Verifiche dalla classe in agenda: ${todo.length}');
    }
    return todo.length;
  }

  /// Controlla tutte le mie classi, al massimo ogni 3 ore (all'avvio e quando si torna nell'app).
  static Future<void> maybeSync(AppStore s) async {
    if (!enabled(s) || s.accountCode == null) return;
    final ids = s.opt('social.classes', '').split(',').where((x) => x.isNotEmpty).take(5).toList();
    if (ids.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - s.opt<int>(_kLast, 0) < 3 * 3600 * 1000) return;
    await s.setOpt(_kLast, now);
    for (final id in ids) {
      try {
        await importFrom(s, await Social.items(s, id));
      } catch (e) {
        AppLog.w('classe', 'Verifiche della classe: $e');
      }
    }
  }
}

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../school_extra.dart';
import '../school_life.dart';
import '../store.dart';
import 'save_file_io.dart' if (dart.library.js_interop) 'save_file_web.dart';
import '../i18n.dart';

/// Il PDF usa i caratteri standard: niente emoji né simboli strani.
String _clean(String s) => s
    .replaceAll('½', ',5')
    .replaceAll('–', '-')
    .replaceAll('·', '-')
    .replaceAll('→', '->')
    .replaceAll(RegExp(r'[^ -ÿ]'), '')
    .trim();

String _d(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Crea il resoconto (voti, medie, assenze) in PDF.
Future<List<int>> buildReportPdf(AppStore store, {String mode = 'tri'}) async {
  final doc = pw.Document(title: tr('Easy Lesson - resoconto', 'Easy Lesson - report'), author: store.username ?? 'Easy Lesson');
  final now = DateTime.now();
  final ref = store.myMainRef;
  final week = ref == null ? null : store.cached(ref)?.week;
  final bySubject = <String, List<Grade>>{};
  for (final g in store.grades) {
    (bySubject[g.subject] ??= []).add(g);
  }
  final subjects = bySubject.keys.toList()..sort();
  String avg(Iterable<Grade> l) {
    final a = average(l);
    return a == null ? '-' : a.toStringAsFixed(2);
  }

  final stats = week == null ? null : absenceStats(store.absences, week, now);
  const header = pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white);
  const green = PdfColor.fromInt(0xFF16A34A);

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(36),
    footer: (ctx) => pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Text(tr('Easy Lesson - pagina ${ctx.pageNumber} di ${ctx.pagesCount}', 'Easy Lesson - page ${ctx.pageNumber} of ${ctx.pagesCount}'),
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
    ),
    build: (ctx) => [
      pw.Text(tr('Resoconto scolastico', 'School report'), style: const pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: green)),
      pw.SizedBox(height: 4),
      pw.Text(_clean([
        if (store.username != null) store.username!,
        if (ref != null) tr('Classe ${ref.displayName}', 'Class ${ref.displayName}'),
        tr('aggiornato al ${_d(now)}', 'updated on ${_d(now)}'),
      ].join(' - '))),
      pw.SizedBox(height: 18),
      pw.Text(tr('Medie', 'Averages'), style: const pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 6),
      if (subjects.isEmpty)
        pw.Text(tr('Nessun voto segnato.', 'No grades recorded.'))
      else
        pw.TableHelper.fromTextArray(
          headerStyle: header,
          headerDecoration: const pw.BoxDecoration(color: green),
          cellAlignment: pw.Alignment.centerLeft,
          headers: [
            tr('Materia', 'Subject'),
            periodName(1, mode: mode),
            periodName(2, mode: mode),
            tr('Media', 'Average'),
            tr('Voto in pagella', 'Report card grade'),
          ].map(_clean).toList(),
          data: [
            for (final s in subjects)
              [
                _clean(s),
                avg(bySubject[s]!.where((g) => gradePeriod(g.date, mode: mode) == 1)),
                avg(bySubject[s]!.where((g) => gradePeriod(g.date, mode: mode) == 2)),
                avg(bySubject[s]!),
                '${reportCardMark(average(bySubject[s]!)!)}',
              ],
          ],
        ),
      if (subjects.isNotEmpty) ...[
        pw.SizedBox(height: 18),
        pw.Text(tr('Tutti i voti', 'All grades'), style: const pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.TableHelper.fromTextArray(
          headerStyle: header,
          headerDecoration: const pw.BoxDecoration(color: green),
          headers: [tr('Data', 'Date'), tr('Materia', 'Subject'), tr('Tipo', 'Type'), tr('Voto', 'Grade'), tr('Note', 'Notes')],
          data: [
            for (final g in [...store.grades]..sort((a, b) => a.date.compareTo(b.date)))
              [_d(g.date), _clean(g.subject), g.kind, _clean(Grade.format(g.value)), _clean(g.note)],
          ],
        ),
      ],
      pw.SizedBox(height: 18),
      pw.Text(tr('Assenze', 'Absences'), style: const pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 6),
      if (stats != null)
        pw.Text(tr('Ore perse: ${stats.lost} su un limite di ${stats.limitHours} '
            '(25% di ${stats.yearHours} ore stimate) - ${stats.days} giorni interi.', 'Hours missed: ${stats.lost} out of a limit of ${stats.limitHours} (25% of ${stats.yearHours} estimated hours) - ${stats.days} full days.')),
      pw.SizedBox(height: 6),
      if (store.absences.isEmpty)
        pw.Text(tr('Nessuna assenza segnata.', 'No absences recorded.'))
      else
        pw.TableHelper.fromTextArray(
          headerStyle: header,
          headerDecoration: const pw.BoxDecoration(color: green),
          headers: [tr('Data', 'Date'), tr('Cosa', 'What'), tr('Note', 'Notes')],
          data: [
            for (final a in [...store.absences]..sort((a, b) => a.date.compareTo(b.date)))
              [_d(a.date), _clean(a.label), _clean(a.note)],
          ],
        ),
      pw.SizedBox(height: 24),
      pw.Text(
        tr('Dati inseriti dallo studente nell\'app Easy Lesson: non sostituiscono il registro elettronico.', 'Data entered by the student in the Easy Lesson app: it doesn\'t replace the electronic register.'),
        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
      ),
    ],
  ));
  return doc.save();
}

/// Crea il PDF e chiede dove salvarlo.
Future<void> exportReport(BuildContext context) async {
  final store = StoreScope.read(context);
  final messenger = ScaffoldMessenger.of(context);
  try {
    final bytes = await buildReportPdf(store, mode: store.opt('periods', 'tri'));
    final where = await saveBytesFile(
      'resoconto_easylesson_${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}.pdf',
      bytes,
      mime: 'application/pdf',
      title: tr('Salva il resoconto', 'Save the report'),
    );
    await store.setOpt('ach.pdf', true);
    if (where != null) messenger.showSnackBar(SnackBar(content: Text(tr('Resoconto salvato 📄', 'Report saved 📄'))));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(tr('PDF non creato: $e', 'PDF not created: $e'))));
  }
}

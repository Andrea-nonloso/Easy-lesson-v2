import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../store.dart';
import 'code_scanner.dart' show accountLink, recoveryLink;
import 'save_file_io.dart' if (dart.library.js_interop) 'save_file_web.dart';
import '../i18n.dart';

/// Foglio di recupero: codice e codice di recupero, con i QR, da stampare o salvare.
Future<List<int>> buildRecoverySheet({required String code, String? recovery, String? name}) async {
  // Font con il simbolo € (Helvetica del PDF non lo ha sempre).
  final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/HindSiliguri-Regular.ttf'));
  final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/HindSiliguri-Bold.ttf'));
  final doc = pw.Document(theme: pw.ThemeData.withFont(base: regular, bold: bold));
  const green = PdfColor.fromInt(0xFF16A34A);
  final now = DateTime.now();

  pw.Widget box(String title, String value, String qr, String note) => pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 18),
        padding: const pw.EdgeInsets.all(16),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey500, width: 1),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        ),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(title, style: const pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: green)),
                  pw.SizedBox(height: 8),
                  pw.Text(value, style: const pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, letterSpacing: 1.5)),
                  pw.SizedBox(height: 6),
                  pw.Text(note, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                ],
              ),
            ),
            pw.SizedBox(width: 12),
            pw.BarcodeWidget(barcode: pw.Barcode.qrCode(), data: qr, width: 90, height: 90),
          ],
        ),
      );

  doc.addPage(pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(40),
    build: (ctx) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(tr('Easy Lesson · Foglio di recupero', 'Easy Lesson · Recovery sheet'), style: const pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: green)),
        pw.SizedBox(height: 4),
        pw.Text(
          '${name == null || name.isEmpty ? '' : '$name · '}${tr('creato il', 'created on')} ${now.day}/${now.month}/${now.year}',
          style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 20),
        box(tr('Il tuo codice', 'Your code'), code, accountLink(code),
            tr('Serve per entrare nel tuo account su un altro telefono. Il QR si inquadra con la fotocamera.', 'It\'s for signing in to your account on another phone. Scan the QR with the camera.')),
        if (recovery != null)
          box(tr('Codice di recupero', 'Recovery code'), recovery, recoveryLink(recovery),
              tr('Se perdi il codice: Impostazioni > Profilo > "Ho perso il codice". Poi ne ricevi uno nuovo.', 'If you lose the code: Settings > Profile > "I lost my code". Then you get a new one.')),
        pw.SizedBox(height: 8),
        pw.Text(tr('Come conservarlo', 'How to keep it'), style: const pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.Bullet(text: tr('Stampalo e tienilo a casa, oppure salvalo dove non lo perdi (non sul telefono soltanto).', 'Print it and keep it at home, or save it where you won\'t lose it (not only on the phone).')),
        pw.Bullet(text: tr('Non darlo a nessuno: chi ha il codice entra nel tuo account e legge i tuoi dati.', 'Don\'t give it to anyone: whoever has the code gets into your account and reads your data.')),
        pw.Bullet(text: tr('Maiuscole e simboli contano; spazi e trattini no.', 'Capitals and symbols count; spaces and dashes don\'t.')),
        pw.Bullet(
          text: tr('I tuoi voti, assenze e agenda sul server sono cifrati con questi codici: '
              'se li perdi tutti e due, nessuno può recuperarli, nemmeno chi gestisce Easy Lesson.', 'Your grades, absences and planner on the server are encrypted with these codes: if you lose both, nobody can recover them, not even whoever runs Easy Lesson.'),
        ),
      ],
    ),
  ));
  return doc.save();
}

/// Crea il foglio e chiede dove salvarlo.
Future<void> exportRecoverySheet(BuildContext context, {required String code, String? recovery, String? name}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final store = StoreScope.read(context);
    final bytes = await buildRecoverySheet(code: code, recovery: recovery, name: name);
    final where = await saveBytesFile('easy_lesson_foglio_recupero.pdf', bytes,
        mime: 'application/pdf', title: tr('Salva il foglio di recupero', 'Save the recovery sheet'));
    if (where != null) {
      await store.setOpt('ach.recoverySheet', true);
      messenger.showSnackBar(SnackBar(content: Text(tr('Foglio di recupero salvato: stampalo o tienilo al sicuro', 'Recovery sheet saved: print it or keep it safe'))));
    }
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(tr('PDF non creato: $e', 'PDF not created: $e'))));
  }
}

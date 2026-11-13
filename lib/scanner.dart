import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Scanner in PDF (3.9): ritaglio, rotazione e filtro "documento" fatti sul telefono, poi un PDF di più pagine.
/// Funzioni pure (si possono chiamare con compute() in un isolate) e testate in test/scanner_test.dart.

const maxScanPages = 30;

/// Lato lungo massimo delle pagine elaborate: si legge bene e il PDF resta piccolo.
const scanMaxSide = 1800;

enum ScanFilter { original, document, gray }

class ScanEdit {
  const ScanEdit({this.left = 0, this.top = 0, this.right = 1, this.bottom = 1, this.turns = 0, this.filter = ScanFilter.document});

  /// Ritaglio, in frazioni dell'immagine (dopo la rotazione): 0-1.
  final double left;
  final double top;
  final double right;
  final double bottom;

  /// Quarti di giro in senso orario (0-3).
  final int turns;
  final ScanFilter filter;

  ScanEdit copyWith({double? left, double? top, double? right, double? bottom, int? turns, ScanFilter? filter}) => ScanEdit(
        left: left ?? this.left,
        top: top ?? this.top,
        right: right ?? this.right,
        bottom: bottom ?? this.bottom,
        turns: turns ?? this.turns,
        filter: filter ?? this.filter,
      );
}

/// Applica [edit] alla foto [bytes] (JPEG/PNG) e restituisce un JPEG. null = immagine non leggibile.
Uint8List? processScan((Uint8List, ScanEdit) job) {
  final (bytes, edit) = job;
  var im = img.decodeImage(bytes);
  if (im == null) return null;
  im = img.bakeOrientation(im);
  // Prima si rimpicciolisce: tutto il resto va più veloce.
  final long = im.width > im.height ? im.width : im.height;
  if (long > scanMaxSide) {
    im = im.width >= im.height ? img.copyResize(im, width: scanMaxSide) : img.copyResize(im, height: scanMaxSide);
  }
  final t = edit.turns % 4;
  if (t != 0) im = img.copyRotate(im, angle: 90 * t);
  final l = edit.left.clamp(0.0, 0.95), r = edit.right.clamp(l + 0.05, 1.0);
  final tp = edit.top.clamp(0.0, 0.95), b = edit.bottom.clamp(tp + 0.05, 1.0);
  final x = (l * im.width).round(), y = (tp * im.height).round();
  final w = ((r - l) * im.width).round().clamp(1, im.width - x), h = ((b - tp) * im.height).round().clamp(1, im.height - y);
  if (x != 0 || y != 0 || w != im.width || h != im.height) im = img.copyCrop(im, x: x, y: y, width: w, height: h);
  switch (edit.filter) {
    case ScanFilter.original:
      break;
    case ScanFilter.gray:
      im = img.grayscale(im);
    case ScanFilter.document:
      im = documentFilter(im);
  }
  return img.encodeJpg(im, quality: edit.filter == ScanFilter.original ? 82 : 75);
}

/// Effetto "fotocopia": grigio, poi i livelli si allargano (il 2% più scuro diventa nero, il carta-grigio bianco).
img.Image documentFilter(img.Image src) {
  final g = img.grayscale(src);
  final hist = List.filled(256, 0);
  for (final p in g) {
    hist[p.r.toInt().clamp(0, 255)]++;
  }
  final total = g.width * g.height;
  int pct(double f) {
    var acc = 0;
    for (var i = 0; i < 256; i++) {
      acc += hist[i];
      if (acc >= total * f) return i;
    }
    return 255;
  }

  // La carta è quasi sempre la parte più chiara e più grande: al 90° percentile siamo già sulla carta (diventa bianca).
  // Il nero è il punto più scuro (1%), ma almeno 80 livelli sotto la carta: se il testo è poco non si brucia il foglio.
  final hi = pct(0.90).clamp(80, 255);
  final lo = pct(0.01).clamp(0, hi - 80);
  final span = (hi - lo).toDouble();
  for (final p in g) {
    final v = ((p.r - lo) / span).clamp(0.0, 1.0);
    // Un po' di curva: il testo resta scuro, la carta va a bianco.
    final out = (255 * (v * v * (3 - 2 * v))).round();
    p
      ..r = out
      ..g = out
      ..b = out;
  }
  return g;
}

/// PDF A4: una pagina per immagine, centrata e grande quanto può.
Future<Uint8List> buildScanPdf(List<Uint8List> jpegs, {String title = 'Scansione'}) async {
  final doc = pw.Document(title: title, creator: 'Easy Lesson');
  for (final j in jpegs.take(maxScanPages)) {
    final image = pw.MemoryImage(j);
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(18),
      build: (_) => pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
    ));
  }
  return doc.save();
}

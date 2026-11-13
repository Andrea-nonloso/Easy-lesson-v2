import 'dart:typed_data';

import 'package:easy_lesson/scanner.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

Uint8List _photo(int w, int h) {
  // Foglio grigino con una riga di "testo" scuro.
  final im = img.Image(width: w, height: h);
  img.fill(im, color: img.ColorRgb8(190, 185, 170));
  img.fillRect(im, x1: w ~/ 4, y1: h ~/ 2, x2: w * 3 ~/ 4, y2: h ~/ 2 + 6, color: img.ColorRgb8(40, 40, 50));
  return img.encodeJpg(im);
}

void main() {
  test('ritaglio e rotazione', () {
    final out = processScan((_photo(400, 200), const ScanEdit(left: 0, top: 0, right: 0.5, bottom: 1, turns: 1, filter: ScanFilter.original)))!;
    final im = img.decodeJpg(out)!;
    // Ruotata di 90°: 200×400, poi tenuta la metà sinistra → 100×400.
    expect((im.width, im.height), (100, 400));
  });

  test('il filtro documento rende bianca la carta e scuro il testo', () {
    final im = img.decodeJpg(processScan((_photo(300, 300), const ScanEdit()))!)!;
    expect(im.getPixel(10, 10).r, greaterThan(235));
    expect(im.getPixel(150, 152).r, lessThan(80));
  });

  test('le foto grandi si rimpiccioliscono', () {
    final im = img.decodeJpg(processScan((_photo(3600, 1200), const ScanEdit(filter: ScanFilter.gray)))!)!;
    expect(im.width, scanMaxSide);
  });

  test('immagine rovinata: null', () {
    expect(processScan((Uint8List.fromList([1, 2, 3]), const ScanEdit())), isNull);
  });

  test('PDF di più pagine', () async {
    final a = processScan((_photo(200, 300), const ScanEdit()))!;
    final pdf = await buildScanPdf([a, a]);
    expect(String.fromCharCodes(pdf.sublist(0, 5)), '%PDF-');
  });
}

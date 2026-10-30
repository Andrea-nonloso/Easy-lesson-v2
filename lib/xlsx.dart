import 'dart:convert';

import 'package:archive/archive.dart';

/// Lettore minimale di file .xlsx (solo testo, primo foglio).
///
/// Dart puro: funziona su Android, iOS, web e anche da riga di comando.
/// Restituisce le righe del foglio come liste di stringhe (celle vuote = '').
List<List<String>> readXlsx(List<int> bytes) {
  final Archive zip;
  try {
    zip = ZipDecoder().decodeBytes(bytes);
  } catch (_) {
    throw const FormatException('Il file non è un Excel valido (.xlsx)');
  }

  String? text(String name) {
    final f = zip.findFile(name);
    if (f == null) return null;
    return utf8.decode(f.content as List<int>, allowMalformed: true);
  }

  // Testi condivisi
  final shared = <String>[];
  final ssXml = text('xl/sharedStrings.xml');
  if (ssXml != null) {
    final clean = ssXml.replaceAll(RegExp(r'<rPh\b[\s\S]*?</rPh>'), '');
    for (final si in RegExp(r'<si>([\s\S]*?)</si>').allMatches(clean)) {
      shared.add(_joinT(si.group(1)!));
    }
  }

  final sheetXml = text(_firstSheetPath(text) ?? '') ?? _anySheet(zip);
  if (sheetXml == null) throw const FormatException('Nessun foglio trovato nel file Excel');

  final rows = <int, Map<int, String>>{};
  final cellRe = RegExp(r'<c\b([^>]*?)(?:/>|>([\s\S]*?)</c>)');
  final refRe = RegExp(r'\br="([A-Z]+)(\d+)"');
  final typeRe = RegExp(r'\bt="(\w+)"');
  final vRe = RegExp(r'<v>([\s\S]*?)</v>');
  for (final m in cellRe.allMatches(sheetXml)) {
    final attrs = m.group(1)!;
    final body = m.group(2) ?? '';
    final ref = refRe.firstMatch(attrs);
    if (ref == null) continue;
    final type = typeRe.firstMatch(attrs)?.group(1) ?? 'n';
    String value;
    if (type == 'inlineStr') {
      value = _joinT(body);
    } else {
      final v = vRe.firstMatch(body)?.group(1);
      if (v == null) continue;
      if (type == 's') {
        final i = int.tryParse(v);
        value = (i != null && i < shared.length) ? shared[i] : '';
      } else {
        value = _unescape(v);
      }
    }
    if (value.isEmpty) continue;
    rows.putIfAbsent(int.parse(ref.group(2)!) - 1, () => {})[_colIndex(ref.group(1)!)] = value;
  }

  if (rows.isEmpty) return [];
  final maxRow = rows.keys.reduce((a, b) => a > b ? a : b);
  return [
    for (var r = 0; r <= maxRow; r++)
      if (rows[r] == null)
        <String>[]
      else
        [
          for (var c = 0; c <= rows[r]!.keys.reduce((a, b) => a > b ? a : b); c++) rows[r]![c] ?? '',
        ],
  ];
}

String? _firstSheetPath(String? Function(String) text) {
  final wb = text('xl/workbook.xml');
  final rels = text('xl/_rels/workbook.xml.rels');
  if (wb == null || rels == null) return null;
  final sheet = RegExp(r'<sheet\b[^>]*>').firstMatch(wb)?.group(0);
  final id = sheet == null ? null : RegExp(r'r:id="([^"]+)"').firstMatch(sheet)?.group(1);
  if (id == null) return null;
  for (final rel in RegExp(r'<Relationship\b[^>]*>').allMatches(rels)) {
    final tag = rel.group(0)!;
    if (RegExp(r'\bId="([^"]+)"').firstMatch(tag)?.group(1) != id) continue;
    final target = RegExp(r'\bTarget="([^"]+)"').firstMatch(tag)?.group(1);
    if (target == null) return null;
    return target.startsWith('/') ? target.substring(1) : 'xl/$target';
  }
  return null;
}

String? _anySheet(Archive zip) {
  for (final f in zip.files) {
    if (RegExp(r'^xl/worksheets/sheet\d+\.xml$').hasMatch(f.name)) {
      return utf8.decode(f.content as List<int>, allowMalformed: true);
    }
  }
  return null;
}

int _colIndex(String letters) {
  var n = 0;
  for (final c in letters.codeUnits) {
    n = n * 26 + (c - 64);
  }
  return n - 1;
}

String _joinT(String xml) => _unescape(
    RegExp(r'<t\b[^>]*>([\s\S]*?)</t>').allMatches(xml).map((m) => m.group(1)!).join());

String _unescape(String s) => s.replaceAllMapped(RegExp(r'&(#x[0-9a-fA-F]+|#\d+|amp|lt|gt|quot|apos);'), (m) {
      final e = m.group(1)!;
      switch (e) {
        case 'amp':
          return '&';
        case 'lt':
          return '<';
        case 'gt':
          return '>';
        case 'quot':
          return '"';
        case 'apos':
          return "'";
      }
      final code = e.startsWith('#x') ? int.parse(e.substring(2), radix: 16) : int.parse(e.substring(1));
      return String.fromCharCode(code);
    });

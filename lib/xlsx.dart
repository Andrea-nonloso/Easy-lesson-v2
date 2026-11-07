import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'i18n.dart';

/// Limiti del lettore (sicurezza EL-03): un file piccolo non deve poter chiedere memoria
/// enorme. L'orario vero della scuola ha ~310 righe × 26 colonne e il foglio pesa ~0,5 MB.
class XlsxLimits {
  const XlsxLimits({
    this.maxFileBytes = 15 * 1024 * 1024,
    this.maxEntries = 500,
    this.maxPartBytes = 40 * 1024 * 1024,
    this.maxRows = 20000,
    this.maxCols = 1000,
    this.maxCells = 1000000,
  });

  final int maxFileBytes;
  final int maxEntries;

  /// Byte decompressi di un singolo file interno (foglio, testi condivisi…).
  final int maxPartBytes;
  final int maxRows;
  final int maxCols;
  final int maxCells;
}

FormatException get _tooBig => FormatException(tr('Il file Excel è troppo grande o rovinato', 'The Excel file is too big or damaged'));

/// Lettore minimale di file .xlsx (solo testo, primo foglio).
///
/// Dart puro: funziona su Android, Windows, web e anche da riga di comando.
/// Restituisce le righe del foglio come liste di stringhe (celle vuote = '').
List<List<String>> readXlsx(List<int> bytes, {XlsxLimits limits = const XlsxLimits()}) {
  if (bytes.length > limits.maxFileBytes) throw _tooBig;
  final Archive zip;
  try {
    zip = ZipDecoder().decodeBytes(bytes);
  } catch (_) {
    throw FormatException(tr('Il file non è un Excel valido (.xlsx)', 'The file isn\'t a valid Excel file (.xlsx)'));
  }
  if (zip.files.length > limits.maxEntries) throw _tooBig;

  String? text(String name) {
    final f = zip.findFile(name);
    if (f == null) return null;
    return _readPart(f, limits);
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

  final sheetXml = text(_firstSheetPath(text) ?? '') ?? _anySheet(zip, limits);
  if (sheetXml == null) throw FormatException(tr('Nessun foglio trovato nel file Excel', 'No sheet found in the Excel file'));

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
        value = (i != null && i >= 0 && i < shared.length) ? shared[i] : '';
      } else {
        value = _unescape(v);
      }
    }
    if (value.isEmpty) continue;
    // Coordinate controllate PRIMA di allocare qualsiasi cosa: niente righe/colonne enormi.
    final letters = ref.group(1)!;
    final digits = ref.group(2)!;
    if (letters.length > 3 || digits.length > 7) throw _tooBig;
    final r = int.parse(digits) - 1;
    final c = _colIndex(letters);
    if (r < 0 || r >= limits.maxRows || c < 0 || c >= limits.maxCols) throw _tooBig;
    rows.putIfAbsent(r, () => {})[c] = value;
  }

  if (rows.isEmpty) return [];
  final maxRow = rows.keys.reduce((a, b) => a > b ? a : b);
  var cells = 0;
  for (final row in rows.values) {
    cells += row.keys.reduce((a, b) => a > b ? a : b) + 1;
  }
  if (cells + maxRow + 1 > limits.maxCells) throw _tooBig;
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

String? _anySheet(Archive zip, XlsxLimits limits) {
  for (final f in zip.files) {
    if (RegExp(r'^xl/worksheets/sheet\d+\.xml$').hasMatch(f.name)) {
      return _readPart(f, limits);
    }
  }
  return null;
}

/// Decomprime un file interno contando i byte veri (non quelli dichiarati): si ferma appena
/// supera il limite, così una "zip bomb" non riempie la memoria.
String _readPart(ArchiveFile f, XlsxLimits limits) {
  if (f.size > limits.maxPartBytes) throw _tooBig;
  final out = _LimitedOutput(limits.maxPartBytes);
  try {
    f.decompress(out);
  } on FormatException {
    rethrow;
  } catch (_) {
    throw FormatException(tr('Il file non è un Excel valido (.xlsx)', 'The file isn\'t a valid Excel file (.xlsx)'));
  }
  return utf8.decode(out.getBytes(), allowMalformed: true);
}

class _LimitedOutput extends OutputMemoryStream {
  _LimitedOutput(this.limit);

  final int limit;

  void _check(int more) {
    if (length + more > limit) throw _tooBig;
  }

  @override
  void reserve(int total) {
    if (total > limit) throw _tooBig;
    super.reserve(total);
  }

  @override
  void writeByte(int value) {
    _check(1);
    super.writeByte(value);
  }

  @override
  void writeBytes(List<int> bytes, {int? length}) {
    _check(length ?? bytes.length);
    super.writeBytes(bytes, length: length);
  }

  @override
  void writeRange(Uint8List bytes, int start, int end) {
    _check(end - start);
    super.writeRange(bytes, start, end);
  }

  @override
  void writeStream(InputStream stream) {
    _check(stream.length);
    super.writeStream(stream);
  }

  @override
  void writeBackReference(int distance, int count) {
    _check(count);
    super.writeBackReference(distance, count);
  }
}

int _colIndex(String letters) {
  var n = 0;
  for (final c in letters.codeUnits) {
    if (c < 65 || c > 90) return -1;
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

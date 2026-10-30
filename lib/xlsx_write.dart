import 'dart:convert';

import 'package:archive/archive.dart';

/// Scrittore minimale di file .xlsx (solo testo, un foglio per voce della mappa).
/// Dart puro: funziona su Android, Windows e web.
List<int> writeXlsx(Map<String, List<List<String>>> sheets) {
  final names = <String>[];
  for (final raw in sheets.keys) {
    var n = raw.replaceAll(RegExp(r'[\[\]:*?/\\]'), ' ').trim();
    if (n.isEmpty) n = 'Foglio';
    if (n.length > 31) n = n.substring(0, 31);
    var unique = n;
    var k = 2;
    while (names.any((x) => x.toLowerCase() == unique.toLowerCase())) {
      final suffix = ' ($k)';
      unique = (n.length + suffix.length > 31 ? n.substring(0, 31 - suffix.length) : n) + suffix;
      k++;
    }
    names.add(unique);
  }

  final archive = Archive();
  void add(String path, String content) {
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(path, bytes.length, bytes));
  }

  const head = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n';
  add(
    '[Content_Types].xml',
    '$head<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
        '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
        '${[for (var i = 1; i <= names.length; i++) '<Override PartName="/xl/worksheets/sheet$i.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'].join()}'
        '</Types>',
  );
  add(
    '_rels/.rels',
    '$head<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
        '</Relationships>',
  );
  add(
    'xl/workbook.xml',
    '$head<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets>'
        '${[for (var i = 0; i < names.length; i++) '<sheet name="${_esc(names[i])}" sheetId="${i + 1}" r:id="rId${i + 1}"/>'].join()}'
        '</sheets></workbook>',
  );
  add(
    'xl/_rels/workbook.xml.rels',
    '$head<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '${[for (var i = 1; i <= names.length; i++) '<Relationship Id="rId$i" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet$i.xml"/>'].join()}'
        '<Relationship Id="rId${names.length + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
        '</Relationships>',
  );
  // Stile 1 = grassetto (prima riga), stile 2 = testo a capo.
  add(
    'xl/styles.xml',
    '$head<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
        '<fonts count="2"><font><sz val="11"/><name val="Calibri"/></font><font><b/><sz val="11"/><name val="Calibri"/></font></fonts>'
        '<fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills>'
        '<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>'
        '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
        '<cellXfs count="3"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
        '<xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/>'
        '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0" applyAlignment="1"><alignment wrapText="1" vertical="top"/></xf></cellXfs>'
        '</styleSheet>',
  );

  var i = 0;
  for (final rows in sheets.values) {
    i++;
    final b = StringBuffer('$head<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">');
    final cols = rows.fold<int>(0, (m, r) => r.length > m ? r.length : m);
    if (cols > 0) {
      b.write('<cols>');
      for (var c = 1; c <= cols; c++) {
        b.write('<col min="$c" max="$c" width="${c == 1 ? 10 : 28}" customWidth="1"/>');
      }
      b.write('</cols>');
    }
    b.write('<sheetData>');
    for (var r = 0; r < rows.length; r++) {
      b.write('<row r="${r + 1}">');
      for (var c = 0; c < rows[r].length; c++) {
        final v = rows[r][c];
        if (v.isEmpty) continue;
        final style = r == 0 ? 1 : (v.contains('\n') ? 2 : 0);
        b.write('<c r="${colName(c)}${r + 1}" t="inlineStr"${style > 0 ? ' s="$style"' : ''}>'
            '<is><t xml:space="preserve">${_esc(v)}</t></is></c>');
      }
      b.write('</row>');
    }
    b.write('</sheetData></worksheet>');
    add('xl/worksheets/sheet$i.xml', b.toString());
  }

  // Il tipo restituito cambia tra le versioni 3 e 4 di archive.
  final dynamic out = ZipEncoder().encode(archive);
  return List<int>.from(out as List);
}

/// 0 → A, 25 → Z, 26 → AA…
String colName(int index) {
  var n = index + 1;
  var s = '';
  while (n > 0) {
    final m = (n - 1) % 26;
    s = String.fromCharCode(65 + m) + s;
    n = (n - 1) ~/ 26;
  }
  return s;
}

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');

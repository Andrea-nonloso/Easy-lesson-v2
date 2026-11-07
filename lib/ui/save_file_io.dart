import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import '../i18n.dart';

/// Android / Windows: finestra "Salva con nome".
/// Restituisce il percorso, null se annullato.
Future<String?> saveTextFile(String name, String content, {String mime = 'text/plain'}) =>
    saveBytesFile(name, utf8.encode(content), mime: mime, title: tr('Salva il calendario', 'Save the calendar'));

Future<String?> saveBytesFile(
  String name,
  List<int> data, {
  String mime = 'application/octet-stream',
  String? title,
}) async {
  final bytes = Uint8List.fromList(data);
  final ext = name.contains('.') ? name.split('.').last : 'txt';
  final path = await FilePicker.platform.saveFile(
    dialogTitle: title ?? tr('Salva il file', 'Save the file'),
    fileName: name,
    type: FileType.custom,
    allowedExtensions: [ext],
    bytes: bytes,
  );
  if (path == null) return null;
  // Su Windows file_picker sceglie solo il percorso: il file lo scriviamo noi.
  if (!Platform.isAndroid && !Platform.isIOS) {
    await File(path).writeAsBytes(bytes, flush: true);
  }
  return path;
}

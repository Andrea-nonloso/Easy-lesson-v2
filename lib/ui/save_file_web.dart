import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Versione web: scarica il file con un link "download" (i browser bloccano
/// l'apertura diretta dei link data:). Restituisce '' se avviato.
Future<String?> saveTextFile(String name, String content, {String mime = 'text/plain'}) =>
    saveBytesFile(name, utf8.encode(content), mime: mime);

Future<String?> saveBytesFile(
  String name,
  List<int> data, {
  String mime = 'application/octet-stream',
  String? title,
}) async {
  final url = 'data:$mime;base64,${base64Encode(data)}';
  final doc = globalContext.getProperty<JSObject>('document'.toJS);
  final a = doc.callMethod<JSObject>('createElement'.toJS, 'a'.toJS);
  a.setProperty('href'.toJS, url.toJS);
  a.setProperty('download'.toJS, name.toJS);
  doc.getProperty<JSObject>('body'.toJS).callMethod<JSAny?>('appendChild'.toJS, a);
  a.callMethod<JSAny?>('click'.toJS);
  a.callMethod<JSAny?>('remove'.toJS);
  return '';
}

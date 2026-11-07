import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

final _name = RegExp(r'^[0-9a-f]{64}\.(webp|png|gif)$');

Future<Directory> _dir() async {
  final d = Directory('${(await getApplicationSupportDirectory()).path}${Platform.pathSeparator}stickers');
  if (!await d.exists()) await d.create(recursive: true);
  return d;
}

/// Gli sticker salvati, i più nuovi prima.
Future<List<(String, Uint8List)>> storageList() async {
  final d = await _dir();
  final files = <File>[
    for (final e in await d.list().toList())
      if (e is File && _name.hasMatch(e.uri.pathSegments.last)) e,
  ];
  files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
  return [for (final f in files) (f.uri.pathSegments.last, await f.readAsBytes())];
}

Future<void> storageWrite(String id, Uint8List bytes) async {
  if (!_name.hasMatch(id)) return;
  await File('${(await _dir()).path}${Platform.pathSeparator}$id').writeAsBytes(bytes, flush: true);
}

Future<void> storageDelete(String id) async {
  if (!_name.hasMatch(id)) return;
  final f = File('${(await _dir()).path}${Platform.pathSeparator}$id');
  if (await f.exists()) await f.delete();
}

/// Un file copiato da Android (cartella di WhatsApp): si legge e si cancella la copia.
Future<Uint8List?> storageReadPath(String path) async {
  try {
    final f = File(path);
    final b = await f.readAsBytes();
    await f.delete();
    return b;
  } catch (_) {
    return null;
  }
}

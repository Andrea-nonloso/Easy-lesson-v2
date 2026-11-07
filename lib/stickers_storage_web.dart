import 'dart:typed_data';

/// Web: gli sticker restano solo finché la pagina è aperta (niente cartelle nel browser).
final Map<String, Uint8List> _mem = {};

Future<List<(String, Uint8List)>> storageList() async => [for (final e in _mem.entries.toList().reversed) (e.key, e.value)];

Future<void> storageWrite(String id, Uint8List bytes) async => _mem[id] = bytes;

Future<void> storageDelete(String id) async => _mem.remove(id);

Future<Uint8List?> storageReadPath(String path) async => null;

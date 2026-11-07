import 'dart:typed_data';

import 'package:archive/archive.dart' show Archive, ZipDecoder;
import 'package:cryptography/cryptography.dart' show Sha256;

import 'stickers_storage.dart';

/// Raccolta di sticker e GIF del dispositivo (3.8, solo grandi). Si importano dal telefono/PC, dalla cartella di
/// WhatsApp (Android) o da un pacchetto .wastickers (è uno zip). Niente ricerca online.
/// Ogni sticker: WebP, PNG o GIF fino a 1 MB; il nome è la sua impronta (stesso file = uno solo). Al massimo [max].
class Sticker {
  const Sticker(this.id, this.bytes);
  final String id;
  final Uint8List bytes;
  String get ext => id.split('.').last;
  bool get isGif => ext == 'gif';
}

class StickerStore {
  StickerStore._();
  static const max = 300;
  static const maxBytes = 1024 * 1024;

  static List<Sticker>? _cache;

  /// Che immagine è (dai primi byte): webp, png, gif o null.
  static String? kind(Uint8List b) {
    if (b.length >= 12 && String.fromCharCodes(b.sublist(0, 4)) == 'RIFF' && String.fromCharCodes(b.sublist(8, 12)) == 'WEBP') return 'webp';
    if (b.length >= 8 && b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4e && b[3] == 0x47) return 'png';
    if (b.length >= 6 && String.fromCharCodes(b.sublist(0, 3)) == 'GIF') return 'gif';
    return null;
  }

  static Future<List<Sticker>> list() async {
    return _cache ??= [for (final (id, b) in await storageList()) Sticker(id, b)];
  }

  /// Aggiunge file scelti dall'utente ([name], byte): immagini o pacchetti .wastickers/.zip.
  /// Restituisce quanti sticker nuovi sono entrati.
  static Future<int> addFiles(List<(String, Uint8List)> files) async {
    var added = 0;
    for (final (name, bytes) in files) {
      final lower = name.toLowerCase();
      if (lower.endsWith('.wastickers') || lower.endsWith('.zip')) {
        Archive zip;
        try {
          zip = ZipDecoder().decodeBytes(bytes);
        } catch (_) {
          continue;
        }
        for (final f in zip.files) {
          if (!f.isFile) continue;
          final data = Uint8List.fromList(f.content as List<int>);
          // Nei pacchetti c'è anche il vassoio (tray.png, piccolo): si salta.
          if (f.name.toLowerCase().contains('tray')) continue;
          if (await _add(data)) added++;
        }
      } else if (await _add(bytes)) {
        added++;
      }
    }
    return added;
  }

  /// Dalla cartella di WhatsApp (percorsi dei file copiati da Android).
  static Future<int> addPaths(List<String> paths) async {
    var added = 0;
    for (final p in paths) {
      final b = await storageReadPath(p);
      if (b != null && await _add(b)) added++;
    }
    return added;
  }

  static Future<bool> _add(Uint8List b) async {
    final k = kind(b);
    if (k == null || b.length > maxBytes || b.isEmpty) return false;
    final all = await list();
    if (all.length >= max) return false;
    final hash = await Sha256().hash(b);
    final id = '${hash.bytes.map((x) => x.toRadixString(16).padLeft(2, '0')).join()}.$k';
    if (all.any((s) => s.id == id)) return false;
    await storageWrite(id, b);
    all.insert(0, Sticker(id, b));
    return true;
  }

  static Future<void> remove(String id) async {
    await storageDelete(id);
    _cache?.removeWhere((s) => s.id == id);
  }
}

// Dove stanno gli sticker: cartella dell'app (Android, Windows, Linux) o solo in memoria (web).
export 'stickers_storage_web.dart' if (dart.library.io) 'stickers_storage_io.dart';

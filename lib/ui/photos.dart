// Foto delle lezioni: su Android e Windows si salvano nella cartella dell'app; sul web no.
export 'photos_stub.dart' if (dart.library.io) 'photos_io.dart';

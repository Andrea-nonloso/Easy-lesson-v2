import 'live_sse.dart';

/// Piattaforma senza rete adatta: niente canale in diretta (le chat si aggiornano da sole ogni tanto).
Stream<SseFrame> openSse(Uri url, List<String> events) => Stream.error(UnsupportedError('in diretta non disponibile'));

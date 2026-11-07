/// Lettore di Server-Sent Events (il formato di /v1/live): blocchi separati da una riga vuota,
/// con righe "event: tipo" e "data: …". Le righe che iniziano con ":" sono il battito (si ignorano).
/// Dart puro: si prova senza rete (test/live_test.dart).
class SseFrame {
  const SseFrame(this.event, this.data);
  final String event;
  final String data;
  @override
  String toString() => 'SseFrame($event, $data)';
}

class SseParser {
  String _buf = '';

  /// Aggiunge un pezzo di testo arrivato dalla rete; restituisce i blocchi completi.
  List<SseFrame> add(String chunk) {
    _buf += chunk.replaceAll('\r\n', '\n');
    final out = <SseFrame>[];
    int i;
    while ((i = _buf.indexOf('\n\n')) >= 0) {
      final block = _buf.substring(0, i);
      _buf = _buf.substring(i + 2);
      String? event;
      final data = <String>[];
      for (final line in block.split('\n')) {
        if (line.isEmpty || line.startsWith(':')) continue;
        final c = line.indexOf(':');
        final field = c < 0 ? line : line.substring(0, c);
        var value = c < 0 ? '' : line.substring(c + 1);
        if (value.startsWith(' ')) value = value.substring(1);
        if (field == 'event') event = value;
        if (field == 'data') data.add(value);
      }
      if (data.isEmpty && event == null) continue;
      out.add(SseFrame(event ?? 'message', data.join('\n')));
    }
    // Un blocco lunghissimo senza fine: rete strana, si butta.
    if (_buf.length > 256 * 1024) _buf = '';
    return out;
  }
}

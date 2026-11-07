import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'live_sse.dart';

/// Android, Windows, Linux: una richiesta HTTP che resta aperta. Si chiude cancellando l'ascolto.
/// Se il server non manda niente per 70 s (il battito arriva ogni 25 s) la connessione si considera persa.
Stream<SseFrame> openSse(Uri url, List<String> events) {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  late StreamController<SseFrame> out;
  StreamSubscription<String>? sub;
  Timer? watchdog;
  void kick() {
    watchdog?.cancel();
    watchdog = Timer(const Duration(seconds: 70), () {
      if (!out.isClosed) out.addError(TimeoutException('il server non manda più niente'));
      sub?.cancel();
      client.close(force: true);
    });
  }

  out = StreamController<SseFrame>(
    onListen: () async {
      try {
        final req = await client.getUrl(url);
        req.headers.set(HttpHeaders.acceptHeader, 'text/event-stream');
        req.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
        final res = await req.close();
        if (res.statusCode != 200) {
          final body = await res.transform(utf8.decoder).join();
          throw HttpException('HTTP ${res.statusCode} ${body.length > 200 ? body.substring(0, 200) : body}', uri: url);
        }
        final parser = SseParser();
        kick();
        sub = res.transform(utf8.decoder).listen(
          (chunk) {
            kick();
            for (final f in parser.add(chunk)) {
              if (events.contains(f.event)) out.add(f);
            }
          },
          onError: (Object e) {
            if (!out.isClosed) out.addError(e);
          },
          onDone: () {
            watchdog?.cancel();
            if (!out.isClosed) out.close();
          },
          cancelOnError: true,
        );
      } catch (e) {
        watchdog?.cancel();
        if (!out.isClosed) {
          out.addError(e);
          await out.close();
        }
      }
    },
    onCancel: () async {
      watchdog?.cancel();
      await sub?.cancel();
      client.close(force: true);
    },
  );
  return out.stream;
}

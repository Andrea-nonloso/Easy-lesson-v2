import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'live_sse.dart';

/// Web: EventSource del browser. Il browser non può mandare intestazioni, per questo l'indirizzo porta un
/// biglietto monouso (vedi Live). Al primo errore si chiude: il biglietto non vale più, ne serve uno nuovo.
Stream<SseFrame> openSse(Uri url, List<String> events) {
  JSObject? es;
  late StreamController<SseFrame> out;
  out = StreamController<SseFrame>(
    onListen: () {
      try {
        final ctor = globalContext.getProperty<JSFunction>('EventSource'.toJS);
        es = ctor.callAsConstructor<JSObject>(url.toString().toJS);
        for (final type in events) {
          es!.callMethod<JSAny?>(
            'addEventListener'.toJS,
            type.toJS,
            ((JSObject ev) {
              final data = ev.getProperty<JSAny?>('data'.toJS);
              if (!out.isClosed) out.add(SseFrame(type, data is JSString ? data.toDart : ''));
            }).toJS,
          );
        }
        es!.callMethod<JSAny?>(
          'addEventListener'.toJS,
          'error'.toJS,
          ((JSObject _) {
            es?.callMethod<JSAny?>('close'.toJS);
            if (!out.isClosed) {
              out.addError(StateError('canale in diretta chiuso'));
              out.close();
            }
          }).toJS,
        );
      } catch (e) {
        out.addError(e);
        out.close();
      }
    },
    onCancel: () {
      es?.callMethod<JSAny?>('close'.toJS);
    },
  );
  return out.stream;
}

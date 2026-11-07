// Apertura del canale in diretta: su Android/Windows/Linux con dart:io, sul web con EventSource del browser.
export 'live_transport_stub.dart'
    if (dart.library.io) 'live_transport_io.dart'
    if (dart.library.js_interop) 'live_transport_web.dart';

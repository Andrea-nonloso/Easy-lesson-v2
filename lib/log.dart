import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart';

/// Una riga del registro (log) dell'app.
class LogEntry {
  LogEntry(this.time, this.level, this.tag, this.message);

  final DateTime time;
  final String level; // 'I' info, 'W' avviso, 'E' errore
  final String tag;
  final String message;

  String get timeText {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(time.hour)}:${two(time.minute)}:${two(time.second)}';
  }

  @override
  String toString() => '$timeText $level/$tag: $message';
}

/// Registro in memoria (ultime 500 righe), visibile nelle opzioni sviluppatore.
/// Non viene salvato né inviato da nessuna parte.
class AppLog {
  AppLog._();

  static const _max = 500;
  static final List<LogEntry> _entries = [];

  /// Cambia a ogni nuova riga: la pagina del log si aggiorna da sola.
  static final ValueNotifier<int> revision = ValueNotifier(0);

  static List<LogEntry> get entries => List.unmodifiable(_entries);

  static void i(String tag, String message) => _add('I', tag, message);
  static void w(String tag, String message) => _add('W', tag, message);
  static void e(String tag, Object error, [StackTrace? stack]) {
    final first = stack?.toString().split('\n').where((l) => l.trim().isNotEmpty).take(3).join('\n');
    _add('E', tag, first == null || first.isEmpty ? '$error' : '$error\n$first');
  }

  static void _add(String level, String tag, String message) {
    _entries.add(LogEntry(DateTime.now(), level, tag, message));
    if (_entries.length > _max) _entries.removeRange(0, _entries.length - _max);
    revision.value++;
  }

  static void clear() {
    _entries.clear();
    revision.value++;
  }

  static String dump() => _entries.map((e) => e.toString()).join('\n');

  /// Cattura errori di Flutter, errori non gestiti e debugPrint.
  static void install() {
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      e('flutter', details.exception, details.stack);
      previous?.call(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      e('dart', error, stack);
      return false; // lascia comunque gestire l'errore come prima
    };
    final original = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) _add('I', 'print', message);
      original(message, wrapWidth: wrapWidth);
    };
    i('app', 'Avvio · ${kIsWeb ? 'web' : defaultTargetPlatform.name} · ${kReleaseMode ? 'release' : 'debug'}');
  }
}

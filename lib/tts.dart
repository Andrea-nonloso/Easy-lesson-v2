import 'i18n.dart';
import 'native.dart';
import 'store.dart';
import 'tts_stub.dart' if (dart.library.js_interop) 'tts_web.dart';

/// Lettura ad alta voce (3.9): Android con TextToSpeech (MainActivity.kt), web con speechSynthesis.
/// Sulle altre piattaforme non c'è (i pulsanti non si vedono).
class Tts {
  Tts._();

  static bool get supported => NativeBridge.supported || webTtsSupported;

  /// Pulsanti "leggi" accesi (Impostazioni → Accessibilità).
  static bool enabled(AppStore s) => supported && s.opt('a11y.tts', false);

  /// Velocità scelta: 0.5 … 1.5 (1 = normale).
  static double rate(AppStore s) => (s.opt<num>('a11y.ttsRate', 1)).toDouble().clamp(0.5, 1.5);

  /// [lang] "it" / "en"; null = lingua dell'app.
  static Future<void> speak(AppStore s, String text, {String? lang}) async {
    final t = text.trim();
    if (t.isEmpty || !supported) return;
    final l = lang ?? (appEnglish ? 'en' : 'it');
    final tag = l == 'en' ? 'en-GB' : 'it-IT';
    if (NativeBridge.supported) {
      await NativeBridge.speak(t, tag, rate(s));
    } else {
      webSpeak(t, tag, rate(s));
    }
  }

  static Future<void> stop() async {
    if (NativeBridge.supported) {
      await NativeBridge.stopSpeaking();
    } else {
      webStop();
    }
  }
}

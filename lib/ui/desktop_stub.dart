import '../store.dart';

/// Versione web: niente notifiche desktop né icona nell'area di notifica.
class DesktopBridge {
  static bool get supported => false;
  static Future<void> init(AppStore store) async {}
  static void notify(String title, String body) {}
}

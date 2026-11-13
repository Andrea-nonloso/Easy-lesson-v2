import 'package:flutter/widgets.dart';

/// Gancio per le build private (es. "Easy Lesson Dev"): una scheda in più nella barra.
///
/// Nell'app pubblica non lo imposta nessuno: la scheda non c'è e qui non c'è altro codice.
/// La build privata ha un suo main che riempie [extraTab] prima di avviare l'app.
class DevHook {
  DevHook._();

  /// Costruisce la pagina della scheda in più (null = nessuna scheda).
  static WidgetBuilder? extraTab;

  /// true mentre la scheda in più è quella aperta (le serve per gestire il tasto "indietro").
  static final ValueNotifier<bool> extraVisible = ValueNotifier(false);

  /// Nome e icone della scheda in più.
  static String extraLabel = 'Admin';
  static IconData? extraIcon;
  static IconData? extraIconSelected;
}

import 'package:flutter/material.dart';

import '../i18n.dart';
import '../store.dart';
import '../tts.dart';

/// Pulsante 🔊 (3.9): legge [text] ad alta voce. Si vede solo con "Lettura ad alta voce" accesa.
class SpeakButton extends StatelessWidget {
  const SpeakButton({super.key, required this.text, this.lang, this.size});
  final String Function() text;
  final String? lang;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    if (!Tts.enabled(store)) return const SizedBox.shrink();
    return IconButton(
      iconSize: size,
      tooltip: tr('Leggi ad alta voce', 'Read aloud'),
      onPressed: () => Tts.speak(store, text(), lang: lang),
      icon: const Icon(Icons.volume_up_rounded),
    );
  }
}

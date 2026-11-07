import 'dart:async';

import 'package:flutter/material.dart';

import '../live.dart';
import '../i18n.dart';

/// Aggiornamento "in diretta" delle chat mentre la pagina è aperta.
///   - Con il canale in diretta (Live, 3.8): si ricarica appena il server dice che qualcosa è cambiato
///     ([relevant]), e una volta quando il canale si ricollega.
///   - Senza (rete strana, server vecchio, web senza canale): si ricarica da sola ogni [fallback] (5 s), mai ogni
///     secondo: le richieste passerebbero dal Worker di Cloudflare, che ne ha un numero limitato.
///   - Chat in pausa (risponde Cloudflare): ogni 30 s, giusto per vedere quando torna.
/// Quando si torna nell'app si ricarica subito; in background si ferma.
mixin LivePoll<T extends StatefulWidget> on State<T> {
  Timer? _livePollTimer;
  AppLifecycleListener? _livePollLife;
  StreamSubscription<LiveEvent>? _livePollSub;
  bool _livePollBusy = false;
  bool _livePollWasConnected = false;
  String? _livePollChat;
  /// Secondi dall'ultima ricarica (contati dal timer, non dall'orologio: vale anche se l'ora cambia).
  int _livePollAge = 1 << 30;

  /// Ricarica in silenzio (gli errori si ignorano: si riprova al giro dopo).
  Future<void> livePollRefresh();

  /// [chat] = "class:<id>", "adult", "notice": i suoi messaggi non contano come non letti mentre la pagina è aperta.
  /// [relevant] = quali eventi del canale in diretta fanno ricaricare questa pagina.
  void startLivePoll(
    Duration fallback, {
    String? chat,
    bool Function(LiveEvent e)? relevant,
  }) {
    final live = Live.instance;
    // Si può richiamare (es. conversazione nuova che riceve il suo id): prima si chiude quella di prima.
    if (_livePollChat != null && _livePollChat != chat) live.closeChat(_livePollChat!);
    live.removeListener(_livePollOnLive);
    _livePollChat = chat;
    if (chat != null) live.openChat(chat);
    _livePollSub?.cancel();
    if (relevant != null) {
      _livePollSub = live.events.where((e) => e.type != 'typing' && relevant(e)).listen((_) => _livePollTick());
    }
    _livePollWasConnected = live.connected;
    live.addListener(_livePollOnLive);
    _livePollTimer?.cancel();
    _livePollTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _livePollAge++;
      final st = WidgetsBinding.instance.lifecycleState;
      if (st != null && st != AppLifecycleState.resumed) return;
      if (live.connected && relevant != null) return; // ci pensa il canale in diretta
      final every = live.paused ? const Duration(seconds: 30) : fallback;
      if (_livePollAge >= every.inSeconds) _livePollTick();
    });
    _livePollLife ??= AppLifecycleListener(onResume: _livePollTick);
  }

  void _livePollOnLive() {
    final now = Live.instance.connected;
    // Appena ricollegati: una ricarica, potremmo esserci persi qualcosa.
    if (now && !_livePollWasConnected) _livePollTick();
    _livePollWasConnected = now;
  }

  Future<void> _livePollTick() async {
    if (_livePollBusy || !mounted) return;
    _livePollBusy = true;
    _livePollAge = 0;
    try {
      await livePollRefresh();
      if (_livePollChat != null) Live.instance.markRead(_livePollChat!);
    } catch (_) {
      // rete assente o server lento: si riprova al prossimo giro
    } finally {
      _livePollBusy = false;
    }
  }

  @override
  void dispose() {
    _livePollTimer?.cancel();
    _livePollLife?.dispose();
    _livePollSub?.cancel();
    Live.instance.removeListener(_livePollOnLive);
    if (_livePollChat != null) Live.instance.closeChat(_livePollChat!);
    super.dispose();
  }
}

/// Sotto i messaggi: "Marco sta scrivendo…" e, se risponde la riserva Cloudflare, la chat in pausa.
class LiveChatStatus extends StatelessWidget {
  const LiveChatStatus({super.key, required this.chat, this.typingText});
  final String chat;
  final String? typingText;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Live.instance,
      builder: (context, _) {
        final live = Live.instance;
        final who = live.typingIn(chat);
        final theme = Theme.of(context);
        if (live.paused) {
          return Container(
            width: double.infinity,
            color: theme.colorScheme.secondaryContainer,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              tr('Chat in pausa: il server principale è in manutenzione. Puoi leggere, si scrive appena torna.', 'Chat paused: the main server is under maintenance. You can read, writing comes back as soon as it\'s back.'),
              style: TextStyle(color: theme.colorScheme.onSecondaryContainer, fontSize: 13),
            ),
          );
        }
        if (who == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('$who ${typingText ?? tr('sta scrivendo…', 'is typing…')}',
                style: TextStyle(fontSize: 12.5, fontStyle: FontStyle.italic, color: theme.colorScheme.onSurfaceVariant)),
          ),
        );
      },
    );
  }
}

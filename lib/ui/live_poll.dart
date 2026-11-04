import 'dart:async';

import 'package:flutter/widgets.dart';

/// Aggiornamento "in diretta" delle chat: mentre la pagina è aperta e l'app è in primo piano
/// si ricarica ogni [every]; quando si torna nell'app si ricarica subito. In background si ferma.
/// Niente server push: funziona uguale con il server di casa e con la riserva Cloudflare.
mixin LivePoll<T extends StatefulWidget> on State<T> {
  Timer? _livePollTimer;
  AppLifecycleListener? _livePollLife;
  bool _livePollBusy = false;

  /// Ricarica in silenzio (gli errori si ignorano: si riprova al giro dopo).
  Future<void> livePollRefresh();

  void startLivePoll(Duration every) {
    _livePollTimer?.cancel();
    _livePollTimer = Timer.periodic(every, (_) {
      final st = WidgetsBinding.instance.lifecycleState;
      if (st == null || st == AppLifecycleState.resumed) _livePollTick();
    });
    _livePollLife ??= AppLifecycleListener(onResume: _livePollTick);
  }

  Future<void> _livePollTick() async {
    if (_livePollBusy || !mounted) return;
    _livePollBusy = true;
    try {
      await livePollRefresh();
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
    super.dispose();
  }
}

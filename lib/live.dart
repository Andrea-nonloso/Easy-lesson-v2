import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'cloud.dart';
import 'live_sse.dart';
import 'live_transport.dart';
import 'log.dart';
import 'native.dart';
import 'store.dart';
import 'ui/desktop.dart';
import 'i18n.dart';

/// Un evento del canale in diretta (vedi server/src/live.js). Sono "spinte": dicono cosa è cambiato, poi la pagina
/// rilegge con le chiamate di sempre.
class LiveEvent {
  LiveEvent(this.type, this.data);
  final String type;
  final Map<String, dynamic> data;

  String? get classId => data['classId'] is String ? data['classId'] as String : null;
  bool get mine => data['mine'] == true;

  /// La chat a cui si riferisce ("class:<id>", "adult", "notice") o null.
  String? get chat => switch (type) {
        'chat' when classId != null => 'class:$classId',
        'adult' => 'adult',
        'notice' => 'notice',
        'dm' when data['threadId'] is String => 'dm:${data['threadId']}',
        // 3.9: sfide a quiz (nuova sfida, l'amico ha giocato o rifiutato): un pallino solo per tutte.
        'quiz' => 'quiz',
        'typing' => data['chat'] is String ? data['chat'] as String : null,
        _ => null,
      };

  @override
  String toString() => 'LiveEvent($type, $data)';
}

class LiveTyping {
  LiveTyping(this.who, this.until);
  final String who;
  final DateTime until;
}

/// Canale in diretta (3.8). Si collega SOLO a un nostro server (casa, nodo 2): quando risponde la riserva
/// Cloudflare le chat sono in pausa ([paused]). Senza connessione le pagine si aggiornano da sole ogni tanto
/// (mixin LivePoll), come prima.
///
/// Tiene anche i messaggi non letti (pallini) di questa sessione e chi sta scrivendo.
class Live extends ChangeNotifier {
  Live._();
  static final Live instance = Live._();

  static const _types = ['hello', 'chat', 'adult', 'dm', 'typing', 'notice', 'friends', 'me', 'mod', 'progress', 'study', 'quiz', 'poll'];

  /// Collegato e in ascolto.
  bool connected = false;

  /// Risponde Cloudflare al posto dei nostri server: chat in pausa (si legge, non si scrive).
  bool paused = false;

  /// Il nostro server che risponde ("casa", "nodo2"), e il suo indirizzo diretto.
  String? node;
  String? base;

  /// Non letti di questa sessione, per chat ("class:<id>", "adult", "notice").
  final Map<String, int> unread = {};

  /// Chat aperte sullo schermo adesso (i loro messaggi non contano come non letti).
  final Set<String> viewing = {};

  /// Nomi da mostrare nelle notifiche (es. "class:abc" -> "1A IT"), li mettono le pagine.
  final Map<String, String> names = {};

  final Map<String, LiveTyping> _typing = {};
  final _events = StreamController<LiveEvent>.broadcast();
  Stream<LiveEvent> get events => _events.stream;

  AppStore? _store;
  StreamSubscription<SseFrame>? _sub;
  Timer? _retry;
  Timer? _bg;
  Timer? _typingTimer;
  AppLifecycleListener? _life;
  int _fails = 0;
  bool _running = false;
  bool _connecting = false;
  final Map<String, DateTime> _typingSent = {};

  int get totalUnread => unread.values.fold(0, (a, b) => a + b);
  int unreadOf(String chat) => unread[chat] ?? 0;
  int get unreadClasses => unread.entries.where((e) => e.key.startsWith('class:')).fold(0, (a, e) => a + e.value);

  /// Messaggi privati non letti (tutte le conversazioni).
  int get unreadDm => unread.entries.where((e) => e.key.startsWith('dm:')).fold(0, (a, e) => a + e.value);

  void markReadPrefix(String prefix) {
    final before = unread.length;
    unread.removeWhere((k, _) => k.startsWith(prefix));
    if (unread.length != before) notifyListeners();
  }

  /// Chi sta scrivendo in [chat] (null = nessuno).
  String? typingIn(String chat) {
    final t = _typing[chat];
    if (t == null || t.until.isBefore(DateTime.now())) return null;
    return t.who;
  }

  /// Notifiche dei messaggi (Impostazioni → Notifiche). Predefinito: accese.
  bool get notificationsOn => _store?.opt<bool>('n.chat', true) ?? true;

  // 3.8: notifiche push (Firebase, solo Android): cosa è registrato sul server in questa sessione.
  String? _pushKey;

  /// Con le notifiche dei messaggi accese il server avvisa questo telefono anche ad app chiusa; spente, il telefono
  /// cancella il suo token. Si chiama a ogni collegamento e quando si cambia l'interruttore. Errori: si riprova al
  /// prossimo collegamento.
  Future<void> syncPush() async {
    if (!NativeBridge.supported) return;
    final code = _store?.accountCode;
    final b = base;
    if (code == null || b == null) return;
    final on = notificationsOn;
    try {
      if (on) {
        final t = await NativeBridge.pushToken();
        if (t == null) return;
        final key = '$code|$t';
        if (key == _pushKey) return;
        await Cloud.pushRegister(b, code, t);
        _pushKey = key;
        _quietKey = null;
      } else {
        if (_pushKey == 'off') return;
        final was = _pushKey;
        if (was != null && was.startsWith('$code|')) await Cloud.pushUnregister(b, code, was.substring(code.length + 1));
        await NativeBridge.pushOff();
        _pushKey = 'off';
      }
    } catch (e) {
      AppLog.w('live', 'Notifiche push: $e');
    }
    await _syncQuiet();
  }

  // 3.9: silenzioso durante le lezioni (opzione "n.hold").
  String? _quietKey;
  final Map<String, int> _held = {};
  Timer? _heldTimer;

  bool get _holdOn => _store?.opt<bool>('n.hold', false) ?? false;

  /// Blocco di lezione in corso adesso (null = siamo fuori).
  List<int>? _windowNow() {
    final s = _store;
    if (s == null || !_holdOn) return null;
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final w in NativeBridge.holdWindows(s, DateTime.now())) {
      if (w[0] <= now && now < w[1]) return w;
    }
    return null;
  }

  /// Manda al server i blocchi di lezione di oggi e domani (vuoto = niente pausa). Solo se cambiano.
  Future<void> _syncQuiet() async {
    final s = _store;
    final code = s?.accountCode;
    final b = base;
    if (s == null || code == null || b == null || !NativeBridge.supported) return;
    final windows = _holdOn && notificationsOn ? NativeBridge.holdWindows(s, DateTime.now()) : const <List<int>>[];
    final key = '$code|${jsonEncode(windows)}';
    if (key == _quietKey) return;
    try {
      await Cloud.pushQuiet(b, code, windows);
      _quietKey = key;
    } catch (e) {
      AppLog.w('live', 'Pausa notifiche: $e');
    }
  }

  /// Si chiama da Impostazioni quando cambia "Silenzioso durante le lezioni".
  Future<void> syncQuiet() => _syncQuiet();

  /// Fine del blocco: un solo riassunto dei messaggi arrivati durante la lezione.
  void _flushHeld() {
    _heldTimer?.cancel();
    _heldTimer = null;
    if (_held.isEmpty) return;
    final total = _held.values.fold(0, (a, b) => a + b);
    final chats = _held.length;
    _held.clear();
    final title = tr('Mentre eri a lezione', 'While you were in class');
    final body = chats == 1
        ? tr(total == 1 ? '1 messaggio nuovo' : '$total messaggi nuovi', total == 1 ? '1 new message' : '$total new messages')
        : tr('$total messaggi in $chats chat', '$total messages in $chats chats');
    if (NativeBridge.supported) {
      NativeBridge.notifyChat(4, title, body).catchError((_) {});
    } else {
      DesktopBridge.notify(title, body);
    }
  }

  void start(AppStore store) {
    _store = store;
    _life ??= AppLifecycleListener(onStateChange: _onLife);
    if (_running) return;
    _running = true;
    _connect();
  }

  /// Account appena creato/cambiato: riprova subito.
  void restart() {
    if (!_running || _store == null) return;
    _close();
    _fails = 0;
    _connect();
  }

  void stop() {
    _running = false;
    _retry?.cancel();
    _bg?.cancel();
    _close();
  }

  void markRead(String chat) {
    if (unread.remove(chat) != null) notifyListeners();
  }

  void openChat(String chat) {
    viewing.add(chat);
    markRead(chat);
  }

  void closeChat(String chat) => viewing.remove(chat);

  /// "Sta scrivendo" in [chat]: al massimo uno ogni 2,5 s; gli errori si ignorano.
  void typing(String chat) {
    final code = _store?.accountCode;
    final b = base;
    if (!connected || code == null || b == null) return;
    final now = DateTime.now();
    final last = _typingSent[chat];
    if (last != null && now.difference(last) < const Duration(milliseconds: 2500)) return;
    _typingSent[chat] = now;
    Cloud.liveTyping(b, code, chat).catchError((_) {});
  }

  // ------------------------------------------------------------------ connessione

  void _onLife(AppLifecycleState st) {
    final mobile = !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);
    if (st == AppLifecycleState.resumed) {
      _bg?.cancel();
      if (_running && _sub == null && !_connecting) {
        _fails = 0;
        _connect();
      }
    } else if (mobile && (st == AppLifecycleState.paused || st == AppLifecycleState.hidden)) {
      // In background sul telefono si resta collegati ancora un po' (arrivano le notifiche), poi si chiude per
      // la batteria. Ad app chiusa ci penserà Firebase (fase 4 del piano).
      _bg ??= Timer(const Duration(minutes: 3), () {
        _bg = null;
        _close();
      });
    }
  }

  Future<void> _connect() async {
    _retry?.cancel();
    if (!_running || _connecting || _sub != null) return;
    final store = _store;
    final code = store?.accountCode;
    // Senza account non c'è niente da ascoltare: quando arriva, home_shell chiama restart().
    if (store == null || code == null) return;
    _connecting = true;
    try {
      final h = await Cloud.healthInfo();
      final wasPaused = paused;
      paused = h['chat'] == false;
      node = h['node'] is String ? h['node'] as String : null;
      final live = h['live'] is String ? (h['live'] as String).replaceAll(RegExp(r'/+$'), '') : null;
      if (paused || live == null || !Cloud.isTrustedLiveServer(Uri.parse(live))) {
        if (live != null && !paused) AppLog.w('live', 'Indirizzo diretto non attendibile, ignorato: $live');
        base = null;
        _setConnected(false, force: wasPaused != paused);
        _schedule(const Duration(minutes: 1));
        return;
      }
      base = live;
      final ticket = await Cloud.liveTicket(live, code);
      final url = Uri.parse('$live/v1/live?ticket=${Uri.encodeQueryComponent(ticket)}');
      _sub = openSse(url, _types).listen(_onFrame, onError: (Object e) => _drop('$e'), onDone: () => _drop('chiuso'), cancelOnError: true);
      if (wasPaused) notifyListeners();
    } catch (e) {
      _drop('$e');
    } finally {
      _connecting = false;
    }
  }

  void _close() {
    _sub?.cancel();
    _sub = null;
    _setConnected(false);
  }

  void _drop(String why) {
    _sub?.cancel();
    _sub = null;
    _setConnected(false);
    if (!_running) return;
    _fails++;
    const steps = [1, 2, 5, 10, 30, 60];
    final s = steps[(_fails - 1).clamp(0, steps.length - 1)];
    if (_fails <= 2) AppLog.i('live', 'Canale in diretta perso ($why), riprovo tra $s s');
    _schedule(Duration(seconds: s));
  }

  void _schedule(Duration d) {
    _retry?.cancel();
    if (_running) _retry = Timer(d, _connect);
  }

  void _setConnected(bool v, {bool force = false}) {
    if (connected == v && !force) return;
    connected = v;
    notifyListeners();
  }

  // ------------------------------------------------------------------ eventi

  void _onFrame(SseFrame f) {
    Map<String, dynamic> data = {};
    try {
      final j = jsonDecode(f.data);
      if (j is Map) data = Map<String, dynamic>.from(j);
    } catch (_) {}
    final ev = LiveEvent(f.event, data);
    handle(ev);
  }

  /// Un evento arrivato (pubblico per le prove).
  @visibleForTesting
  void handle(LiveEvent ev) {
    switch (ev.type) {
      case 'hello':
        _fails = 0;
        if (ev.data['node'] is String) node = ev.data['node'] as String;
        paused = false;
        _setConnected(true, force: true);
        syncPush();
        return;
      case 'progress':
        // La moderazione ha cambiato livello, monete o obiettivi: si prendono subito.
        final store = _store;
        if (store != null) unawaited(CloudSync.syncNow(store, quiet: true));
        break;
      case 'typing':
        final chat = ev.chat;
        if (chat == null) return;
        _typing[chat] = LiveTyping('${ev.data['who'] ?? 'Qualcuno'}', DateTime.now().add(const Duration(seconds: 5)));
        _typingTimer?.cancel();
        _typingTimer = Timer(const Duration(seconds: 5, milliseconds: 100), notifyListeners);
        notifyListeners();
        break;
      case 'chat':
      case 'adult':
      case 'notice':
      case 'dm':
      case 'quiz':
        final chat = ev.chat;
        if (chat != null) {
          // Arrivato un messaggio: chi scriveva ha finito.
          if (_typing.remove(chat) != null) notifyListeners();
          if (!ev.mine && !viewing.contains(chat)) {
            unread[chat] = (unread[chat] ?? 0) + 1;
            notifyListeners();
            _notify(chat);
          }
        }
        break;
    }
    if (!_events.isClosed) _events.add(ev);
  }

  void _notify(String chat) {
    if (!notificationsOn) return;
    final st = WidgetsBinding.instance.lifecycleState;
    // Con l'app davanti bastano i pallini.
    if (st == AppLifecycleState.resumed) return;
    final name = names[chat];
    final (title, body) = switch (chat) {
      'adult' => (tr('Chat dei grandi', 'Adults\' chat'), tr('Nuovo messaggio', 'New message')),
      'quiz' => (tr('Sfida a quiz', 'Quiz challenge'), tr('Novità nelle tue sfide a quiz', 'News in your quiz challenges')),
      'notice' => ('Moderazione', tr('Hai un nuovo messaggio dalla moderazione', 'You have a new message from moderation')),
      _ when chat.startsWith('dm:') => (tr('Messaggio privato', 'Private message'), tr('Nuovo messaggio privato', 'New private message')),
      _ => (name ?? tr('Chat della classe', 'Class chat'), name == null ? tr('Nuovo messaggio in classe', 'New message in class') : tr('Nuovo messaggio in $name', 'New message in $name')),
    };
    // 3.9: a lezione (blocco senza ricreazione) si aspetta; gli avvisi della moderazione passano sempre.
    final w = chat == 'notice' ? null : _windowNow();
    if (w != null) {
      _held[chat] = (_held[chat] ?? 0) + 1;
      _heldTimer ??= Timer(Duration(milliseconds: (w[1] - DateTime.now().millisecondsSinceEpoch).clamp(1000, 6 * 3600 * 1000)), _flushHeld);
      return;
    }
    final id = chat == 'adult' ? 1 : chat == 'notice' ? 2 : chat.startsWith('dm:') ? 3 : chat == 'quiz' ? 5 : 10 + (chat.hashCode.abs() % 900);
    if (NativeBridge.supported) {
      NativeBridge.notifyChat(id, title, body).catchError((_) {});
    } else {
      DesktopBridge.notify(title, body);
    }
  }
}

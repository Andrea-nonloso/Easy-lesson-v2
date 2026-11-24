import 'package:flutter/material.dart';

import 'dart:convert';

import 'package:cryptography/cryptography.dart' show Sha256;
import 'package:flutter/services.dart';

import '../cloud.dart';
import '../crypto_box.dart' show authToken;
import '../e2e.dart';
import '../live.dart';
import '../social.dart';
import '../store.dart';
import 'adult_media.dart';
import 'live_poll.dart';
import '../i18n.dart';

// 3.8: messaggi privati tra grandi (18+ verificati). Il server controlla tutto a ogni richiesta; qui si mostra.
// La moderazione può leggere i privati: lo si dice prima ("Ho capito") e resta scritto in cima a ogni conversazione.

String get _encNote => tr('🔒 Conversazione cifrata: solo voi due potete leggere questi messaggi, nemmeno la moderazione. '
    'Tocca qui per il codice di sicurezza.', '🔒 Encrypted conversation: only the two of you can read these messages, not even moderation. '
    'Tap here for the safety code.');

/// 3.11: se la moderazione mi ha autorizzato ai cifrati, il server deve avere la chiave pubblica di questo telefono
/// (così gli altri mi possono scrivere cifrato anche prima che io apra la conversazione). Silenziosa se fallisce.
Future<void> syncE2eKey(AppStore store) async {
  try {
    final st = await Social.e2eStatus(store);
    if (st.$1 != true) return;
    final account = await _e2eAccount(store);
    if (account == null) return;
    final k = await E2e.myKeys(account);
    if (k != null && st.$2 != k.$2) await Social.e2eSetKey(store, k.$2);
  } catch (_) {}
}

/// Impronta dell'account per la chiave salvata (mai il codice stesso).
Future<String?> _e2eAccount(AppStore store) async {
  final code = store.accountCode;
  if (code == null) return null;
  final h = await Sha256().hash(utf8.encode('easylesson-e2e-account:${await authToken(code)}'));
  return base64Url.encode(h.bytes.sublist(0, 12)).replaceAll('=', '');
}

String get _modNote => tr('La moderazione di Easy Lesson può leggere i messaggi privati. I messaggi durano 7 giorni.', 'Easy Lesson moderation can read private messages. Messages last 7 days.');

/// "Ho capito": la prima volta che si usano i privati. true = si può andare avanti.
Future<bool> ensureDmAck(BuildContext context) async {
  final store = StoreScope.read(context);
  final (ack, _) = await Social.dmList(store);
  if (ack || !context.mounted) return ack;
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (c) => AlertDialog(
      icon: const Icon(Icons.visibility_outlined),
      title: Text(tr('Prima di scrivere in privato', 'Before messaging privately')),
      content: Text(
        tr('I messaggi privati non sono segreti: la moderazione di Easy Lesson può leggerli tutti, '
        'con foto e sticker, per tenere tutti al sicuro.\n\n'
        'Restano 7 giorni, poi spariscono. Puoi bloccare chiunque e segnalare un messaggio tenendolo premuto.', 'Private messages aren\'t secret: Easy Lesson moderation can read them all, with photos and stickers, to keep everyone safe.\n\nThey stay for 7 days, then disappear. You can block anyone and report a message by pressing and holding it.'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('Annulla', 'Cancel'))),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(tr('Ho capito', 'Got it'))),
      ],
    ),
  );
  if (ok != true) return false;
  await Social.dmAck(store);
  return true;
}

/// Scrivi in privato a qualcuno della chat dei grandi.
Future<void> openDmWith(BuildContext context, {required String handle, required String name}) async {
  try {
    if (!await ensureDmAck(context) || !context.mounted) return;
    final (_, threads) = await Social.dmList(StoreScope.read(context));
    final t = threads.where((x) => x.other.handle == handle).firstOrNull;
    if (!context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => DmThreadPage(threadId: t?.id, handle: handle, name: name),
    ));
  } on CloudException catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
  }
}

Future<void> openDmList(BuildContext context) async {
  try {
    if (!await ensureDmAck(context) || !context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const DmListPage()));
  } on CloudException catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
  }
}

String _when(DateTime t) {
  final now = DateTime.now();
  final hm = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  if (t.year == now.year && t.month == now.month && t.day == now.day) return hm;
  return '${t.day}/${t.month} $hm';
}

// ------------------------------------------------------------------ elenco

class DmListPage extends StatefulWidget {
  const DmListPage({super.key});
  @override
  State<DmListPage> createState() => _DmListPageState();
}

class _DmListPageState extends State<DmListPage> with LivePoll {
  List<DmThread>? _list;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
    syncE2eKey(StoreScope.read(context));
    startLivePoll(const Duration(seconds: 10), relevant: (e) => e.type == 'dm' || e.type == 'me');
  }

  @override
  Future<void> livePollRefresh() => _load(quiet: true);

  Future<void> _load({bool quiet = false}) async {
    try {
      final (_, l) = await Social.dmList(StoreScope.read(context));
      if (mounted) setState(() => _list = l);
    } on CloudException catch (e) {
      if (e.status == 404 && mounted) Navigator.of(context).maybePop();
      if (mounted && !quiet) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _list;
    final scheme = Theme.of(context).colorScheme;
    final requests = list?.where((t) => t.isRequestForMe).toList() ?? const <DmThread>[];
    final others = list?.where((t) => !t.isRequestForMe).toList() ?? const <DmThread>[];
    Widget tile(DmThread t) => ListTile(
          leading: ProfileAvatar(photo: t.other.photo, emoji: t.other.avatar),
          title: Text(t.other.nickname, style: TextStyle(fontWeight: t.unread > 0 ? FontWeight.w700 : FontWeight.w500)),
          subtitle: Text(
            t.status == 'blocked'
                ? tr('Bloccata da te', 'Blocked by you')
                : t.status == 'pending' && t.startedByMe
                    ? '${tr('Richiesta inviata', 'Request sent')} · ${t.lastText}'
                    : t.lastText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
            if (t.lastAt != null) Text(_when(t.lastAt!), style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            if (t.unread > 0) Badge(label: Text('${t.unread}')),
          ]),
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute<void>(builder: (_) => DmThreadPage(threadId: t.id, handle: t.other.handle, name: t.other.label)))
              .then((_) => _load(quiet: true)),
        );
    return Scaffold(
      appBar: AppBar(title: Text(tr('Messaggi privati', 'Private messages'))),
      body: list == null
          ? Center(child: _error == null ? const CircularProgressIndicator() : Text('$_error'))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Text(_modNote, style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant)),
                ),
                if (requests.isNotEmpty) ...[
                  Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), child: Text(tr('Richieste', 'Requests'), style: const TextStyle(fontWeight: FontWeight.w700))),
                  for (final t in requests) tile(t),
                  const Divider(),
                ],
                if (others.isEmpty && requests.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      tr('Ancora niente. Per scrivere a qualcuno, nella chat dei grandi tieni premuto un suo messaggio → "Scrivi in privato".', 'Nothing yet. To write to someone, in the adults\' chat press and hold one of their messages → "Message privately".'),
                      textAlign: TextAlign.center,
                    ),
                  ),
                for (final t in others) tile(t),
              ]),
            ),
    );
  }
}

// ------------------------------------------------------------------ conversazione

class DmThreadPage extends StatefulWidget {
  /// [threadId] null = conversazione nuova con [handle] (si apre al primo messaggio).
  const DmThreadPage({super.key, required this.threadId, required this.handle, required this.name});
  final String? threadId;
  final String handle;
  final String name;
  @override
  State<DmThreadPage> createState() => _DmThreadPageState();
}

class _DmThreadPageState extends State<DmThreadPage> with LivePoll {
  late String? _id = widget.threadId;
  DmThread? _thread;
  List<DmMessage> _messages = const [];
  bool _gone = false;

  // 3.11: cifrati. _keys = (privata, pubblica) di questo telefono; _plain = testi decifrati (solo in memoria).
  (String, String)? _keys;
  bool _secure = false;
  bool _secureChosen = false;
  final Map<String, String?> _plain = {};
  String? _safety;
  bool _peerChanged = false;

  /// Si può scrivere cifrato: io autorizzato con la chiave caricata, e l'altro con la sua.
  bool get _canSecure {
    final t = _thread;
    return t != null && t.e2eMe && _keys != null && t.e2eMyKey == _keys!.$2 && t.e2ePeerKey != null;
  }

  @override
  void initState() {
    super.initState();
    _load();
    _startLive();
  }

  void _startLive() {
    final id = _id;
    startLivePoll(
      const Duration(seconds: 5),
      chat: id == null ? null : 'dm:$id',
      relevant: (e) => (e.type == 'dm' && e.data['threadId'] == id) || e.type == 'me',
    );
  }

  @override
  Future<void> livePollRefresh() => _load();

  Future<void> _load() async {
    final id = _id;
    if (id == null || _gone) return;
    try {
      final store = StoreScope.read(context);
      final (t, m) = await Social.dmThread(store, id);
      await _prepareE2e(store, t, m);
      if (mounted) {
        setState(() {
          _thread = t;
          _messages = m;
          // La prima volta, se si può, la conversazione parte cifrata.
          if (!_secureChosen) _secure = _canSecure;
          if (!_canSecure) _secure = false;
        });
      }
    } on CloudException catch (e) {
      if (e.status == 404) _closed();
    }
  }

  /// Chiave di questo telefono (caricata sul server se serve), codice di sicurezza, testi decifrati.
  Future<void> _prepareE2e(AppStore store, DmThread t, List<DmMessage> msgs) async {
    if (!t.e2eMe) return;
    final account = await _e2eAccount(store);
    if (account == null) return;
    _keys ??= await E2e.myKeys(account);
    final k = _keys;
    if (k == null) return;
    if (t.e2eMyKey != k.$2) {
      // Nuovo telefono (o prima volta): il server deve avere la mia chiave pubblica.
      try {
        await Social.e2eSetKey(store, k.$2);
        t.j['e2e'] = {...?(t.j['e2e'] as Map?)?.cast<String, dynamic>(), 'myKey': k.$2};
      } catch (_) {
        return;
      }
    }
    final peer = t.e2ePeerKey;
    if (peer == null) return;
    // La chiave dell'altro è cambiata da quando l'ho vista l'ultima volta? (nuovo telefono, o qualcuno in mezzo)
    final seenKey = 'e2e.peer.${t.id}';
    final seen = store.opt<String?>(seenKey, null);
    if (seen != null && seen != peer) _peerChanged = true;
    if (seen != peer) await store.setOpt(seenKey, peer);
    _safety = await E2e.safetyCode(k.$2, peer);
    for (final m in msgs) {
      if (!m.enc || _plain.containsKey(m.id)) continue;
      _plain[m.id] = await E2e.decrypt(threadId: t.id, myPriv: k.$1, myPub: k.$2, peerPub: peer, text: m.text);
    }
  }

  Future<void> _showSafety() async {
    final code = _safety;
    if (code == null) return;
    final name = _thread?.other.label ?? widget.name;
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        icon: const Icon(Icons.lock_rounded),
        title: Text(tr('Codice di sicurezza', 'Safety code')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          SelectableText(code, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: 2)),
          const SizedBox(height: 12),
          Text(tr('Confrontalo con $name, di persona o a voce. Se sul suo telefono c\'è lo stesso codice, nessuno può leggere i vostri messaggi. '
              'Se è diverso, non scrivere niente di importante e avvisa la moderazione.',
              'Compare it with $name, in person or by voice. If their phone shows the same code, nobody can read your messages. '
              'If it is different, do not write anything important and tell moderation.')),
        ]),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              Navigator.pop(c);
            },
            child: Text(tr('Copia', 'Copy')),
          ),
          FilledButton(
            onPressed: () {
              setState(() => _peerChanged = false);
              Navigator.pop(c);
            },
            child: Text(tr('Ok', 'Ok')),
          ),
        ],
      ),
    );
  }

  void _closed() {
    if (_gone || !mounted) return;
    _gone = true;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Questa conversazione non c\'è più', 'This conversation no longer exists'))));
    Navigator.of(context).maybePop();
  }

  void _toast(Object e) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(e is CloudException ? e.message : '$e')));

  Future<void> _send({String text = '', String? media, String kind = 'text'}) async {
    final store = StoreScope.read(context);
    if (_secure && _id != null) {
      if (media != null) {
        throw CloudException(tr('Foto e sticker non si possono mandare cifrati: togli il lucchetto per mandarli.',
            'Photos and stickers cannot be sent encrypted: turn off the lock to send them.'));
      }
      // Il server accetta al massimo ~4 KB cifrati: con tante emoji composte 1000 caratteri possono essere di più.
      if (utf8.encode(text).length > E2e.maxBytes) {
        throw CloudException(tr('Messaggio troppo lungo per essere cifrato: dividilo in due.', 'Message too long to encrypt: split it in two.'));
      }
      final t = _thread!;
      final k = _keys!;
      final peer = t.e2ePeerKey!;
      final box = await E2e.encrypt(threadId: t.id, myPriv: k.$1, myPub: k.$2, peerPub: peer, text: text);
      try {
        await Social.dmSendEncrypted(store, _id!, text: box, peerKey: peer);
      } on CloudException catch (e) {
        // La chiave dell'altro è cambiata mentre scrivevo: ricarico e lo dico, senza mandare.
        if (e.status == 409) {
          await _load();
          throw CloudException(tr('La chiave di ${t.other.label} è cambiata: controlla il codice di sicurezza e riprova.',
              '${t.other.label}\'s key changed: check the safety code and try again.'));
        }
        rethrow;
      }
      await _load();
      return;
    }
    if (_id == null) {
      _id = await Social.dmStart(store, widget.handle, text: text, media: media, kind: kind);
      _startLive();
    } else {
      await Social.dmSend(store, _id!, text: text, media: media, kind: kind);
    }
    await _load();
  }

  Future<void> _action(String a) async {
    final id = _id;
    if (id == null) return;
    try {
      await Social.dmAction(StoreScope.read(context), id, a);
      if (a == 'decline') return _closed();
      await _load();
    } catch (e) {
      if (mounted) _toast(e);
    }
  }

  Future<void> _menu(DmMessage m) async {
    final store = StoreScope.read(context);
    final a = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (m.byMe)
            ListTile(leading: const Icon(Icons.delete_outline_rounded), title: Text(tr('Togli il messaggio', 'Remove the message')), onTap: () => Navigator.pop(c, 'del'))
          else if (m.mod)
            ListTile(leading: const Icon(Icons.shield_outlined), title: Text(tr('Messaggio della moderazione', 'Message from moderation')))
          else
            ListTile(leading: const Icon(Icons.flag_outlined), title: Text(tr('Segnala alla moderazione', 'Report to moderation')), onTap: () => Navigator.pop(c, 'rep')),
        ]),
      ),
    );
    if (a == null || _id == null || !mounted) return;
    if (a == 'rep' && m.enc) {
      // Cifrato: il server non lo sa leggere, quindi la segnalazione porta con sé il testo (solo dopo l'ok).
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(tr('Segnalare questo messaggio?', 'Report this message?')),
          content: Text(tr('È un messaggio cifrato: per farlo vedere alla moderazione, insieme alla segnalazione le mandiamo il testo che vedi qui.',
              'This is an encrypted message: to show it to moderation, the text you see here is sent along with the report.')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('Annulla', 'Cancel'))),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(tr('Segnala', 'Report'))),
          ],
        ),
      );
      if (ok != true) return;
    }
    try {
      if (a == 'del') await Social.dmDelete(store, _id!, m.id);
      if (a == 'rep') await Social.report(store, kind: 'adult-dm', target: m.id, evidence: m.enc ? (_plain[m.id] ?? '') : null);
      if (mounted) _toast(a == 'del' ? tr('Tolto', 'Removed') : tr('Segnalato alla moderazione, grazie', 'Reported to moderation, thanks'));
      await _load();
    } catch (e) {
      if (mounted) _toast(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = _thread;
    final pendingForMe = t?.isRequestForMe ?? false;
    final blocked = t?.status == 'blocked';
    final mineSent = _messages.where((m) => m.byMe).length;
    return Scaffold(
      appBar: AppBar(
        title: Text(t?.other.label ?? widget.name),
        actions: [
          if (_canSecure)
            IconButton(
              tooltip: _secure ? tr('Scrivi senza cifrare', 'Write without encryption') : tr('Scrivi cifrato', 'Write encrypted'),
              isSelected: _secure,
              icon: const Icon(Icons.lock_open_rounded),
              selectedIcon: const Icon(Icons.lock_rounded),
              onPressed: () => setState(() {
                _secure = !_secure;
                _secureChosen = true;
              }),
            ),
          if (_id != null)
            PopupMenuButton<String>(
              onSelected: _action,
              itemBuilder: (_) => [
                if (!blocked) PopupMenuItem(value: 'block', child: Text(tr('Blocca', 'Block'))),
                if (blocked && (t?.blockedByMe ?? false)) PopupMenuItem(value: 'unblock', child: Text(tr('Sblocca', 'Unblock'))),
              ],
            ),
        ],
      ),
      body: Column(children: [
        if (_secure)
          Material(
            color: _peerChanged ? scheme.errorContainer : scheme.secondaryContainer,
            child: InkWell(
              onTap: _showSafety,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(
                  _peerChanged
                      ? tr('⚠️ La chiave di ${t?.other.label ?? widget.name} è cambiata (nuovo telefono?). Tocca qui e riconfrontate il codice di sicurezza.',
                          '⚠️ ${t?.other.label ?? widget.name}\'s key changed (new phone?). Tap here and compare the safety code again.')
                      : _encNote,
                  style: TextStyle(fontSize: 12, color: _peerChanged ? scheme.onErrorContainer : scheme.onSecondaryContainer),
                ),
              ),
            ),
          )
        else
          Container(
            width: double.infinity,
            color: scheme.surfaceContainerHigh,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(_modNote, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          ),
        Expanded(
          child: ListView.builder(
            reverse: true,
            padding: const EdgeInsets.all(12),
            itemCount: _messages.length,
            itemBuilder: (context, i) {
              final m = _messages[_messages.length - 1 - i];
              return Align(
                alignment: m.mod ? Alignment.center : m.byMe ? Alignment.centerRight : Alignment.centerLeft,
                child: GestureDetector(
                  onLongPress: () => _menu(m),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 320),
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                    decoration: BoxDecoration(
                      color: m.kind == 'sticker' ? Colors.transparent : (m.mod ? scheme.tertiaryContainer : m.byMe ? scheme.primaryContainer : scheme.surfaceContainerHigh),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(crossAxisAlignment: m.byMe ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
                      if (m.media != null) AdultImage(media: m.media!, kind: m.kind),
                      if (m.enc)
                        _plain[m.id] != null
                            ? SelectableText(_plain[m.id]!, style: const TextStyle(fontSize: 15.5))
                            : Text(tr('🔒 Non si può leggere su questo telefono (chiave cambiata)', '🔒 Cannot be read on this phone (key changed)'),
                                style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: scheme.onSurfaceVariant))
                      else if (m.text.isNotEmpty)
                        SelectableText(m.text, style: const TextStyle(fontSize: 15.5)),
                      Text(
                        '${m.enc ? '🔒 ' : ''}${_when(m.at)}${m.byMe && m.read ? ' · letto' : ''}',
                        style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                      ),
                    ]),
                  ),
                ),
              );
            },
          ),
        ),
        if (_id != null) LiveChatStatus(chat: 'dm:$_id'),
        if (pendingForMe)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                Text(tr('${t!.other.label} vuole scriverti in privato.', '${t.other.label} wants to message you privately.'), textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Wrap(spacing: 8, alignment: WrapAlignment.center, children: [
                  FilledButton(onPressed: () => _action('accept'), child: Text(tr('Accetta', 'Accept'))),
                  OutlinedButton(onPressed: () => _action('decline'), child: Text(tr('Rifiuta', 'Decline'))),
                  TextButton(onPressed: () => _action('block'), child: Text(tr('Blocca', 'Block'))),
                ]),
              ]),
            ),
          )
        else if (blocked)
          SafeArea(top: false, child: Padding(padding: const EdgeInsets.all(16), child: Text(tr('Conversazione bloccata.', 'Conversation blocked.'))))
        else ...[
          if (t?.status == 'pending' && t!.startedByMe)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                tr('Richiesta inviata: finché non accetta puoi mandare ancora ${(3 - mineSent).clamp(0, 3)} messaggi.', 'Request sent: until they accept you can send ${(3 - mineSent).clamp(0, 3)} more messages.'),
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ),
          AdultComposer(chat: _id == null ? 'adult' : 'dm:$_id', onSend: _send, media: !_secure),
        ],
      ]),
    );
  }
}

/// Riga "Messaggi privati" nella scheda Amici (solo 18+), con i non letti in diretta.
class DmEntryTile extends StatelessWidget {
  const DmEntryTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.mail_outline_rounded),
        title: Text(tr('Messaggi privati', 'Private messages')),
        subtitle: Text(tr('Solo tra maggiorenni verificati · la moderazione può leggerli', 'Only between verified adults · moderation can read them')),
        trailing: ListenableBuilder(
          listenable: Live.instance,
          builder: (context, _) {
            final n = Live.instance.unreadDm;
            return Row(mainAxisSize: MainAxisSize.min, children: [
              if (n > 0) Badge(label: Text('$n')),
              const Icon(Icons.chevron_right_rounded),
            ]);
          },
        ),
        onTap: () {
          Live.instance.markReadPrefix('dm:');
          openDmList(context);
        },
      ),
    );
  }
}

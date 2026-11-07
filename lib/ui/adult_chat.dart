import 'package:flutter/material.dart';

import '../cloud.dart';
import '../social.dart';
import '../store.dart';
import 'adult_dm.dart';
import 'adult_media.dart';
import 'live_poll.dart';
import '../i18n.dart';

/// Chat dei grandi (3.7.1): testo libero, solo tra maggiorenni verificati di persona dalla moderazione.
/// 3.8: in diretta, foto, sticker e GIF; dal menu di un messaggio si scrive in privato a chi l'ha scritto.
/// Se l'abilitazione viene tolta, il server risponde 404 e la pagina si chiude.
class AdultChatPage extends StatefulWidget {
  const AdultChatPage({super.key});
  @override
  State<AdultChatPage> createState() => _AdultChatPageState();
}

class _AdultChatPageState extends State<AdultChatPage> with LivePoll {
  static const _max = 500;
  List<ChatMessage>? _messages;
  Object? _error;
  bool _gone = false;

  @override
  void initState() {
    super.initState();
    _load();
    startLivePoll(const Duration(seconds: 5), chat: 'adult', relevant: (e) => e.type == 'adult' || e.type == 'me');
  }

  @override
  Future<void> livePollRefresh() => _load(quiet: true);

  Future<void> _load({bool quiet = false}) async {
    if (_gone) return;
    try {
      final list = await Social.adultChat(StoreScope.read(context));
      if (mounted) {
        setState(() {
          _messages = list;
          _error = null;
        });
      }
    } on CloudException catch (e) {
      if (e.status == 404) return _closed();
      if (mounted && !quiet) setState(() => _error = e);
    } catch (e) {
      if (mounted && !quiet) setState(() => _error = e);
    }
  }

  /// Abilitazione tolta: fuori subito.
  void _closed() {
    if (_gone || !mounted) return;
    _gone = true;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Non hai più accesso alla chat dei grandi', 'You no longer have access to the adults\' chat'))));
    Navigator.of(context).maybePop();
  }

  void _toast(Object e) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(e is CloudException ? e.message : '$e')));

  Future<void> _send({String text = '', String? media, String kind = 'text'}) async {
    try {
      await Social.sendAdult(StoreScope.read(context), text, media: media, kind: kind);
      await _load();
    } on CloudException catch (e) {
      if (e.status == 404) return _closed();
      rethrow;
    }
  }

  Future<void> _menu(ChatMessage m) async {
    final store = StoreScope.read(context);
    final a = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            title: Text(m.text.isNotEmpty ? m.text : (m.kind == 'sticker' ? tr('Sticker', 'Sticker') : tr('Foto', 'Photo')), maxLines: 4, overflow: TextOverflow.ellipsis),
            subtitle: Text(m.author),
          ),
          if (!m.byMe && m.handle != null)
            ListTile(leading: const Icon(Icons.mail_outline_rounded), title: Text(tr('Scrivi in privato', 'Message privately')), onTap: () => Navigator.pop(c, 'dm')),
          if (m.byMe)
            ListTile(leading: const Icon(Icons.delete_outline_rounded), title: Text(tr('Togli il messaggio', 'Remove the message')), onTap: () => Navigator.pop(c, 'del'))
          else
            ListTile(leading: const Icon(Icons.flag_outlined), title: Text(tr('Segnala', 'Report')), onTap: () => Navigator.pop(c, 'rep')),
        ]),
      ),
    );
    if (a == null) return;
    if (a == 'dm' && mounted) return openDmWith(context, handle: m.handle!, name: m.author);
    try {
      if (a == 'del') await Social.deleteAdult(store, m.id);
      if (a == 'rep') await Social.report(store, kind: 'adult', target: m.id);
      if (mounted) _toast(a == 'del' ? tr('Tolto', 'Removed') : tr('Segnalato alla moderazione, grazie', 'Reported to moderation, thanks'));
      await _load();
    } catch (e) {
      if (mounted) _toast(e);
    }
  }

  String _hm(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final list = _messages;
    return Scaffold(
      appBar: AppBar(title: Text(tr('🔞 Chat dei grandi', '🔞 Adults\' chat'))),
      body: Column(children: [
        Expanded(
          child: list == null
              ? Center(
                  child: _error == null
                      ? const CircularProgressIndicator()
                      : Padding(padding: const EdgeInsets.all(24), child: Text(_error is CloudException ? (_error as CloudException).message : '$_error')),
                )
              : list.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(tr('Ancora niente. Qui scrivono solo i maggiorenni verificati dalla moderazione.\n'
                            'I messaggi spariscono dopo 24 ore.', 'Nothing yet. Only adults verified by moderation write here.\nMessages disappear after 24 hours.'), textAlign: TextAlign.center),
                      ),
                    )
                  : ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.all(12),
                      itemCount: list.length,
                      itemBuilder: (context, i) {
                        final m = list[list.length - 1 - i];
                        return Align(
                          alignment: m.byMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: GestureDetector(
                            onLongPress: () => _menu(m),
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 340),
                              margin: const EdgeInsets.symmetric(vertical: 3),
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                              decoration: BoxDecoration(
                                color: m.byMe ? scheme.primaryContainer : scheme.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                if (!m.byMe) Text(m.author, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: scheme.primary)),
                                if (m.media != null)
                                  Padding(padding: const EdgeInsets.only(top: 4, bottom: 2), child: AdultImage(media: m.media!, kind: m.kind)),
                                if (m.text.isNotEmpty) SelectableText(m.text, style: const TextStyle(fontSize: 15.5)),
                                Text(_hm(m.at), style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                              ]),
                            ),
                          ),
                        );
                      },
                    ),
        ),
        const LiveChatStatus(chat: 'adult'),
        AdultComposer(chat: 'adult', maxLength: _max, onSend: _send),
      ]),
    );
  }
}

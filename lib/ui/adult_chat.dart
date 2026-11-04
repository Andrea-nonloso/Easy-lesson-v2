import 'package:flutter/material.dart';

import '../cloud.dart';
import '../social.dart';
import '../store.dart';
import 'live_poll.dart';

/// Chat dei grandi (3.7.1): testo libero, solo tra maggiorenni verificati di persona dalla moderazione.
/// Si aggiorna ogni secondo. Se l'abilitazione viene tolta, il server risponde 404 e la pagina si chiude.
class AdultChatPage extends StatefulWidget {
  const AdultChatPage({super.key});
  @override
  State<AdultChatPage> createState() => _AdultChatPageState();
}

class _AdultChatPageState extends State<AdultChatPage> with LivePoll {
  static const _max = 500;
  List<ChatMessage>? _messages;
  Object? _error;
  bool _sending = false;
  bool _gone = false;
  final _text = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    startLivePoll(const Duration(seconds: 1));
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
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
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Non hai più accesso alla chat dei grandi')));
    Navigator.of(context).maybePop();
  }

  void _toast(Object e) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(e is CloudException ? e.message : '$e')));

  Future<void> _send() async {
    final t = _text.text.trim();
    if (t.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await Social.sendAdult(StoreScope.read(context), t);
      _text.clear();
      await _load();
    } on CloudException catch (e) {
      if (e.status == 404) return _closed();
      if (mounted) _toast(e);
    } catch (e) {
      if (mounted) _toast(e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _menu(ChatMessage m) async {
    final store = StoreScope.read(context);
    final a = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(title: Text(m.text, maxLines: 4, overflow: TextOverflow.ellipsis), subtitle: Text(m.author)),
          if (m.byMe)
            ListTile(leading: const Icon(Icons.delete_outline_rounded), title: const Text('Togli il messaggio'), onTap: () => Navigator.pop(c, 'del'))
          else
            ListTile(leading: const Icon(Icons.flag_outlined), title: const Text('Segnala'), onTap: () => Navigator.pop(c, 'rep')),
        ]),
      ),
    );
    if (a == null) return;
    try {
      if (a == 'del') await Social.deleteAdult(store, m.id);
      if (a == 'rep') await Social.report(store, kind: 'adult', target: m.id);
      if (mounted) _toast(a == 'del' ? 'Tolto' : 'Segnalato alla moderazione, grazie');
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
      appBar: AppBar(title: const Text('🔞 Chat dei grandi')),
      body: Column(children: [
        Expanded(
          child: list == null
              ? Center(
                  child: _error == null
                      ? const CircularProgressIndicator()
                      : Padding(padding: const EdgeInsets.all(24), child: Text(_error is CloudException ? (_error as CloudException).message : '$_error')),
                )
              : list.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('Ancora niente. Qui scrivono solo i maggiorenni verificati dalla moderazione.\n'
                            'I messaggi spariscono dopo 24 ore.', textAlign: TextAlign.center),
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
                                SelectableText(m.text, style: const TextStyle(fontSize: 15.5)),
                                Text(_hm(m.at), style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                              ]),
                            ),
                          ),
                        );
                      },
                    ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 8, 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(
                child: TextField(
                  controller: _text,
                  minLines: 1,
                  maxLines: 5,
                  maxLength: _max,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(hintText: 'Scrivi un messaggio', counterText: '', border: OutlineInputBorder()),
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filled(
                tooltip: 'Manda',
                onPressed: _sending ? null : _send,
                icon: const Icon(Icons.send_rounded),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

import 'package:flutter/material.dart';

import '../cloud.dart';
import '../log.dart';
import '../social.dart';
import '../store.dart';

/// Avvisi della moderazione (3.0): li manda Andrea dall'app "Easy Lesson Moderazione".
/// Si mostrano uno alla volta, finché non si preme "Ho capito". Si può contestare solo con motivi fissi.
class ModNotices {
  ModNotices._();
  static bool _showing = false;
  static DateTime? _lastCheck;

  /// All'avvio e quando si torna nell'app (al massimo ogni 10 minuti), solo con account e soprannome.
  static Future<void> check(BuildContext context, {bool force = false}) async {
    final store = StoreScope.read(context);
    if (_showing || store.accountCode == null || store.opt<String?>('social.nick', null) == null) return;
    if (!force && _lastCheck != null && DateTime.now().difference(_lastCheck!) < const Duration(minutes: 10)) return;
    _lastCheck = DateTime.now();
    try {
      final (list, reasons) = await Social.notices(store);
      for (final n in list.reversed.where((n) => !n.read)) {
        if (!context.mounted) return;
        _showing = true;
        await _show(context, store, n, reasons);
        _showing = false;
      }
      // La moderazione ha risposto a un messaggio: si apre la conversazione.
      final answered = list.where((n) => n.read && n.replies.any((r) => !r.mine) && n.replies.last.mine == false).toList();
      if (Social.unreadModReplies > 0 && answered.isNotEmpty && context.mounted) {
        final n = answered.first;
        final open = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            icon: const Icon(Icons.mark_chat_unread_outlined, size: 32),
            title: const Text('La moderazione ti ha risposto'),
            content: Text('Su: ${n.title}'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Dopo')),
              FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Leggi')),
            ],
          ),
        );
        if (open == true && context.mounted) {
          await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => NoticeThreadPage(notice: n)));
        }
      }
    } on CloudException catch (e) {
      AppLog.w('moderazione', 'Avvisi non scaricati: ${e.message}');
    } finally {
      _showing = false;
    }
  }

  static (IconData, String) style(String level) => switch (level) {
        'warning' => (Icons.warning_amber_rounded, 'Avviso'),
        'final' => (Icons.report_gmailerrorred_rounded, 'Ultimo avviso'),
        'suspension' => (Icons.block_rounded, 'Sospensione'),
        _ => (Icons.info_outline_rounded, 'Messaggio della moderazione'),
      };

  static Future<void> _show(BuildContext context, AppStore store, ModNotice n, Map<String, String> reasons) async {
    final scheme = Theme.of(context).colorScheme;
    final (icon, label) = style(n.level);
    final answered = n.appeal == 'accepted' || n.appeal == 'rejected';
    final action = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        icon: Icon(icon, size: 36, color: n.level == 'info' ? scheme.primary : scheme.error),
        title: Text(answered ? 'Risposta alla tua contestazione' : n.title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              const SizedBox(height: 8),
              if (answered) ...[
                Text(n.reply ?? ''),
                const SizedBox(height: 12),
                Text('Avviso: ${n.title}', style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant)),
              ] else
                Text(n.body),
            ],
          ),
        ),
        actions: [
          if (n.canAppeal && !answered) TextButton(onPressed: () => Navigator.pop(c, 'appeal'), child: const Text('Non è giusto')),
          if (!n.closed) TextButton(onPressed: () => Navigator.pop(c, 'write'), child: const Text('Rispondi')),
          FilledButton(onPressed: () => Navigator.pop(c, 'ok'), child: const Text('Ho capito')),
        ],
      ),
    );
    if (!context.mounted) return;
    if (action == 'write') {
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => NoticeThreadPage(notice: n)));
      return;
    }
    if (action == 'appeal') {
      final reason = await showDialog<String>(
        context: context,
        builder: (c) => SimpleDialog(
          title: const Text('Perché non è giusto?'),
          children: [
            for (final e in reasons.entries)
              SimpleDialogOption(onPressed: () => Navigator.pop(c, e.key), child: Text(e.value)),
            SimpleDialogOption(onPressed: () => Navigator.pop(c), child: const Text('Annulla')),
          ],
        ),
      );
      if (reason == null) {
        // Non ha scelto: si rimostra la prossima volta.
        return;
      }
      try {
        await Social.appealNotice(store, n.id, reason);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contestazione mandata: ti arriverà una risposta qui')));
        }
      } on CloudException catch (e) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
      return;
    }
    try {
      await Social.readNotice(store, n.id);
    } on CloudException catch (_) {}
  }
}

/// Elenco di tutti gli avvisi ricevuti (Classe e amici → Avvisi della moderazione).
class NoticesPage extends StatefulWidget {
  const NoticesPage({super.key});
  @override
  State<NoticesPage> createState() => _NoticesPageState();
}

class _NoticesPageState extends State<NoticesPage> {
  late Future<(List<ModNotice>, Map<String, String>)> _f = Social.notices(StoreScope.read(context));

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Avvisi della moderazione')),
      body: FutureBuilder<(List<ModNotice>, Map<String, String>)>(
        future: _f,
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('${snap.error}'));
          final list = snap.data?.$1;
          if (list == null) return const Center(child: CircularProgressIndicator());
          if (list.isEmpty) return const Center(child: Text('Nessun avviso 👍'));
          return RefreshIndicator(
            onRefresh: () async {
              setState(() => _f = Social.notices(StoreScope.read(context)));
              await _f;
            },
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                for (final n in list)
                  Card(
                    child: ListTile(
                      onTap: () async {
                        await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => NoticeThreadPage(notice: n)));
                        if (mounted) setState(() => _f = Social.notices(StoreScope.read(context)));
                      },
                      trailing: n.replies.isEmpty ? null : Badge(label: Text('${n.replies.length}'), child: const Icon(Icons.forum_outlined)),
                      leading: Icon(ModNotices.style(n.level).$1, color: n.level == 'info' ? scheme.primary : scheme.error),
                      title: Text(n.read ? n.title : '● ${n.title}', style: n.read ? null : const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text([
                        n.body,
                        if (n.appeal == 'open') '⏳ Contestazione in attesa di risposta',
                        if (n.appeal == 'accepted') '✅ Contestazione accettata: ${n.reply ?? ''}',
                        if (n.appeal == 'rejected') '❌ Contestazione respinta: ${n.reply ?? ''}',
                      ].join('\n')),
                      isThreeLine: true,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Conversazione con la moderazione su un avviso: si può spiegare con parole proprie.
/// La leggono solo i moderatori (mai gli altri utenti).
class NoticeThreadPage extends StatefulWidget {
  const NoticeThreadPage({super.key, required this.notice});
  final ModNotice notice;
  @override
  State<NoticeThreadPage> createState() => _NoticeThreadPageState();
}

class _NoticeThreadPageState extends State<NoticeThreadPage> {
  late ModNotice _n = widget.notice;
  final _text = TextEditingController();
  bool _sending = false;

  bool _marking = false;

  @override
  void initState() {
    super.initState();
    // Avviso già letto: aprendo la conversazione si segnano lette le risposte.
    // Avviso nuovo (3.6): si segna letto solo con "Ho letto" in fondo all'avviso.
    if (_n.read) Social.readNotice(StoreScope.read(context), _n.id).catchError((_) {});
  }

  Future<void> _markRead() async {
    setState(() => _marking = true);
    try {
      await Social.readNotice(StoreScope.read(context), _n.id);
      await _reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Letto: chat, classi e amici tornano a posto')));
      }
    } on CloudException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _marking = false);
    }
  }

  Future<void> _reload() async {
    final (list, _) = await Social.notices(StoreScope.read(context));
    final again = list.where((x) => x.id == _n.id);
    if (again.isNotEmpty && mounted) setState(() => _n = again.first);
  }

  Future<void> _send() async {
    final t = _text.text.trim();
    if (t.length < 2) return;
    setState(() => _sending = true);
    try {
      await Social.replyNotice(StoreScope.read(context), _n.id, t);
      _text.clear();
      await _reload();
    } on CloudException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _when(DateTime t) =>
      '${t.day.toString().padLeft(2, '0')}/${t.month.toString().padLeft(2, '0')} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, label) = ModNotices.style(_n.level);
    return Scaffold(
      appBar: AppBar(title: const Text('Moderazione')),
      body: Column(children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: _reload,
            child: ListView(padding: const EdgeInsets.all(16), children: [
              Card(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  ListTile(
                    leading: Icon(icon, color: _n.level == 'info' ? scheme.primary : scheme.error),
                    title: Text(_n.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('$label · ${_when(_n.createdAt)}\n${_n.body}'),
                    isThreeLine: true,
                  ),
                  if (!_n.read)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: FilledButton.icon(
                        onPressed: _marking ? null : _markRead,
                        icon: const Icon(Icons.done_rounded),
                        label: const Text('Ho letto'),
                      ),
                    ),
                ]),
              ),
              const SizedBox(height: 8),
              Text(
                'Qui puoi spiegare cosa è successo. Lo leggono solo i moderatori, nessun altro utente.',
                style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              for (final r in _n.replies)
                Align(
                  alignment: r.mine ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 340),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                    decoration: BoxDecoration(
                      color: r.mine ? scheme.primaryContainer : scheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if (!r.mine) Text('🛡️ ${r.who}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: scheme.primary)),
                      Text(r.text),
                      Text(_when(r.at), style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                    ]),
                  ),
                ),
              if (_n.closed)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text('La moderazione ha chiuso questa conversazione.', textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.onSurfaceVariant)),
                ),
            ]),
          ),
        ),
        if (!_n.closed)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _text,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 500,
                    decoration: const InputDecoration(hintText: 'Scrivi alla moderazione…', counterText: ''),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(onPressed: _sending ? null : _send, icon: const Icon(Icons.send_rounded)),
              ]),
            ),
          ),
      ]),
    );
  }
}

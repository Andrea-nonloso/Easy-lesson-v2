import 'dart:async';

import 'package:flutter/material.dart';

import '../cloud.dart';
import '../social.dart';
import '../store.dart';

/// Chat rapida della classe: solo frasi pronte (le decide la moderazione), niente testo libero.
/// {materia} e {giorno} si scelgono da elenchi. I messaggi spariscono dopo 24 ore.
class ClassChatTab extends StatefulWidget {
  const ClassChatTab({super.key, required this.classId, required this.admin});
  final String classId;
  final bool admin;
  @override
  State<ClassChatTab> createState() => _ClassChatTabState();
}

const _categories = {'saluti': '👋 Saluti', 'scuola': '🏫 Scuola', 'umore': '😄 Umore', 'sfide': '🏆 Sfide'};

class _ClassChatTabState extends State<ClassChatTab> {
  ChatData? _data;
  Object? _error;
  Timer? _timer;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
    // Mentre la chat è aperta si aggiorna da sola.
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final d = await Social.chat(StoreScope.read(context), widget.classId);
      if (mounted) {
        setState(() {
          _data = d;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _toast(Object e) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(e is CloudException ? e.message : '$e')));

  Future<String?> _pick(String title, List<String> options) => showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (c) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(c).height * 0.7),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(padding: const EdgeInsets.all(8), child: Text(title, style: Theme.of(c).textTheme.titleMedium)),
              Flexible(
                child: ListView(shrinkWrap: true, children: [
                  for (final o in options) ListTile(title: Text(o), onTap: () => Navigator.pop(c, o)),
                ]),
              ),
            ]),
          ),
        ),
      );

  Future<void> _write() async {
    final d = _data;
    if (d == null) return;
    var cat = _categories.keys.first;
    final phrase = await showModalBottomSheet<QuickPhrase>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => StatefulBuilder(
        builder: (c, setState) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(c).height * 0.75),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Wrap(spacing: 6, children: [
                for (final e in _categories.entries)
                  ChoiceChip(label: Text(e.value), selected: cat == e.key, onSelected: (_) => setState(() => cat = e.key)),
              ]),
              const SizedBox(height: 8),
              Flexible(
                child: ListView(shrinkWrap: true, children: [
                  for (final p in d.phrases.where((p) => p.category == cat))
                    ListTile(
                      title: Text(p.render()),
                      trailing: p.slots.isEmpty ? const Icon(Icons.send_rounded, size: 20) : const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.pop(c, p),
                    ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
    if (phrase == null || !mounted) return;
    String? subject;
    String? day;
    if (phrase.slots.contains('materia')) {
      subject = await _pick('Quale materia?', d.subjects);
      if (subject == null) return;
    }
    if (phrase.slots.contains('giorno')) {
      day = await _pick('Quale giorno?', d.days);
      if (day == null) return;
    }
    if (!mounted) return;
    setState(() => _sending = true);
    try {
      await Social.sendChat(StoreScope.read(context), widget.classId, phrase, subject: subject, day: day);
      await _load();
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
          ListTile(title: Text(m.text), subtitle: Text(m.author)),
          if (m.canDelete)
            ListTile(leading: const Icon(Icons.delete_outline_rounded), title: const Text('Togli il messaggio'), onTap: () => Navigator.pop(c, 'del')),
          if (!m.byMe)
            ListTile(leading: const Icon(Icons.flag_outlined), title: const Text('Segnala'), onTap: () => Navigator.pop(c, 'rep')),
        ]),
      ),
    );
    if (a == null) return;
    try {
      if (a == 'del') await Social.deleteChat(store, widget.classId, m.id);
      if (a == 'rep') await Social.report(store, kind: 'chat', target: m.id);
      if (mounted) _toast(a == 'del' ? 'Tolto' : 'Segnalato, grazie');
      await _load();
    } catch (e) {
      if (mounted) _toast(e);
    }
  }

  String _hm(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final d = _data;
    if (d == null) {
      return Center(
        child: _error == null
            ? const CircularProgressIndicator()
            : Padding(padding: const EdgeInsets.all(24), child: Text(_error is CloudException ? (_error as CloudException).message : '$_error')),
      );
    }
    return Column(children: [
      if (widget.admin)
        SwitchListTile(
          dense: true,
          title: const Text('Chat rapida accesa'),
          subtitle: const Text('Solo frasi pronte, i messaggi spariscono dopo 24 ore'),
          value: d.enabled,
          onChanged: (v) async {
            try {
              await Social.setChat(StoreScope.read(context), widget.classId, v);
              await _load();
            } catch (e) {
              if (mounted) _toast(e);
            }
          },
        ),
      Expanded(
        child: !d.enabled
            ? const Center(child: Text('La chat di questa classe è spenta'))
            : d.messages.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('Ancora niente oggi. Scrivi la prima frase! 👋\nSi usano solo frasi pronte, e spariscono dopo 24 ore.',
                          textAlign: TextAlign.center),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                      itemCount: d.messages.length,
                      itemBuilder: (context, i) {
                        final m = d.messages[d.messages.length - 1 - i];
                        return Align(
                          alignment: m.byMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: GestureDetector(
                            onLongPress: () => _menu(m),
                            onTap: () => _menu(m),
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 320),
                              margin: const EdgeInsets.symmetric(vertical: 3),
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                              decoration: BoxDecoration(
                                color: m.byMe ? scheme.primaryContainer : scheme.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                if (!m.byMe)
                                  Text(m.author, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: scheme.primary)),
                                Text(m.text, style: const TextStyle(fontSize: 15.5)),
                                Text(_hm(m.at), style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                              ]),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
      ),
      if (d.enabled)
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _sending ? null : _write,
                icon: const Icon(Icons.chat_bubble_outline_rounded),
                label: const Text('Scrivi una frase'),
              ),
            ),
          ),
        ),
    ]);
  }
}

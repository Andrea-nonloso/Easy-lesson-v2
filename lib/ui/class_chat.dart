import 'package:flutter/material.dart';

import '../cloud.dart';
import '../live.dart';
import '../social.dart';
import '../store.dart';
import 'live_poll.dart';
import '../i18n.dart';

/// Chat rapida della classe: solo frasi pronte (le decide la moderazione), niente testo libero.
/// {materia} e {giorno} si scelgono da elenchi. I messaggi spariscono dopo 24 ore.
class ClassChatTab extends StatefulWidget {
  const ClassChatTab({super.key, required this.classId, required this.admin});
  final String classId;
  final bool admin;
  @override
  State<ClassChatTab> createState() => _ClassChatTabState();
}

Map<String, String> get _categories => {'saluti': tr('👋 Saluti', '👋 Greetings'), 'scuola': tr('🏫 Scuola', '🏫 School'), 'umore': tr('😄 Umore', '😄 Mood'), 'sfide': tr('🏆 Sfide', '🏆 Challenges')};

class _ClassChatTabState extends State<ClassChatTab> with LivePoll {
  ChatData? _data;
  List<ClassPoll> _polls = const [];
  Object? _error;
  bool _sending = false;
  String get _chat => 'class:${widget.classId}';

  @override
  void initState() {
    super.initState();
    _load();
    // Mentre la chat è aperta si aggiorna appena arriva un messaggio (canale in diretta), altrimenti ogni 5 s.
    startLivePoll(
      const Duration(seconds: 5),
      chat: _chat,
      relevant: (e) => ((e.type == 'chat' || e.type == 'poll') && e.classId == widget.classId) || e.type == 'me',
    );
  }

  @override
  Future<void> livePollRefresh() async {
    final store = StoreScope.read(context);
    final d = await Social.chat(store, widget.classId);
    final p = await _loadPolls(store);
    if (mounted) {
      setState(() {
        _data = d;
        if (p != null) _polls = p;
        _error = null;
      });
    }
  }

  /// I sondaggi sono un extra: se il server è vecchio (o non risponde) la chat va lo stesso.
  Future<List<ClassPoll>?> _loadPolls(AppStore store) async {
    try {
      return await Social.polls(store, widget.classId);
    } catch (_) {
      return null;
    }
  }

  Future<void> _load() async {
    try {
      final store = StoreScope.read(context);
      final d = await Social.chat(store, widget.classId);
      final p = await _loadPolls(store);
      if (mounted) {
        setState(() {
          _data = d;
          if (p != null) _polls = p;
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

  Future<String?> _pick(String title, List<String> options, [List<String> labels = const []]) => showModalBottomSheet<String>(
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
                  for (var i = 0; i < options.length; i++)
                    ListTile(
                      title: Text(labels.length == options.length ? labels[i] : options[i]),
                      onTap: () => Navigator.pop(c, options[i]),
                    ),
                ]),
              ),
            ]),
          ),
        ),
      );

  Future<void> _write() async {
    final d = _data;
    if (d == null) return;
    // Gli altri vedono "sta scegliendo una frase…" (non si salva da nessuna parte).
    Live.instance.typing(_chat);
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
      subject = await _pick(tr('Quale materia?', 'Which subject?'), d.subjects, d.subjectLabels);
      if (subject == null) return;
    }
    if (phrase.slots.contains('giorno')) {
      day = await _pick(tr('Quale giorno?', 'Which day?'), d.days, d.dayLabels);
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
            ListTile(leading: const Icon(Icons.delete_outline_rounded), title: Text(tr('Togli il messaggio', 'Remove the message')), onTap: () => Navigator.pop(c, 'del')),
          if (!m.byMe)
            ListTile(leading: const Icon(Icons.flag_outlined), title: Text(tr('Segnala', 'Report')), onTap: () => Navigator.pop(c, 'rep')),
        ]),
      ),
    );
    if (a == null) return;
    try {
      if (a == 'del') await Social.deleteChat(store, widget.classId, m.id);
      if (a == 'rep') await Social.report(store, kind: 'chat', target: m.id);
      if (mounted) _toast(a == 'del' ? tr('Tolto', 'Removed') : tr('Segnalato, grazie', 'Reported, thanks'));
      await _load();
    } catch (e) {
      if (mounted) _toast(e);
    }
  }

  Future<void> _newPoll() async {
    final store = StoreScope.read(context);
    PollTemplates t;
    try {
      t = await Social.pollTemplates(store);
    } catch (e) {
      if (mounted) _toast(e);
      return;
    }
    if (!mounted) return;
    if (t.templates.isEmpty) {
      _toast(tr('Non ci sono ancora sondaggi pronti', 'No ready-made polls yet'));
      return;
    }
    final tpl = await showModalBottomSheet<PollTemplate>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(c).height * 0.7),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(tr('Che sondaggio fai?', 'Which poll?'), style: Theme.of(c).textTheme.titleMedium),
            Flexible(
              child: ListView(shrinkWrap: true, children: [
                for (final p in t.templates)
                  ListTile(
                    leading: const Icon(Icons.poll_outlined),
                    title: Text(p.text),
                    subtitle: p.options.isEmpty ? null : Text(p.options.join(' · '), maxLines: 2, overflow: TextOverflow.ellipsis),
                    onTap: () => Navigator.pop(c, p),
                  ),
              ]),
            ),
          ]),
        ),
      ),
    );
    if (tpl == null || !mounted) return;
    List<String>? options;
    if (tpl.source != 'fixed') {
      final days = tpl.source == 'days';
      final values = days ? t.days : t.subjects;
      final labels = days ? t.dayLabels : t.subjectLabels;
      options = await showModalBottomSheet<List<String>>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (c) => _PollOptionsSheet(values: values, labels: labels.length == values.length ? labels : values, days: days),
      );
      if (options == null || !mounted) return;
    }
    try {
      await Social.newPoll(store, widget.classId, tpl.id, options: options);
      await _load();
    } catch (e) {
      if (mounted) _toast(e);
    }
  }

  Future<void> _vote(ClassPoll p, int i) async {
    try {
      await Social.votePoll(StoreScope.read(context), widget.classId, p.id, i);
      await _load();
    } catch (e) {
      if (mounted) _toast(e);
    }
  }

  Future<void> _deletePoll(ClassPoll p) async {
    try {
      await Social.deletePoll(StoreScope.read(context), widget.classId, p.id);
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
          title: Text(tr('Chat rapida accesa', 'Quick chat on')),
          subtitle: Text(tr('Solo frasi pronte, i messaggi spariscono dopo 24 ore', 'Ready-made phrases only, messages disappear after 24 hours')),
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
      if (d.enabled && _polls.isNotEmpty)
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.35),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            children: [
              for (final p in _polls)
                PollCard(
                  poll: p,
                  onVote: Live.instance.paused ? null : (i) => _vote(p, i),
                  onDelete: p.canDelete ? () => _deletePoll(p) : null,
                ),
            ],
          ),
        ),
      Expanded(
        child: !d.enabled
            ? Center(child: Text(tr('La chat di questa classe è spenta', 'This class\'s chat is off')))
            : d.messages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(tr('Ancora niente oggi. Scrivi la prima frase! 👋\nSi usano solo frasi pronte, e spariscono dopo 24 ore.', 'Nothing yet today. Write the first phrase! 👋\nOnly ready-made phrases, and they disappear after 24 hours.'),
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
      LiveChatStatus(chat: _chat, typingText: tr('sta scegliendo una frase…', 'is picking a phrase…')),
      if (d.enabled)
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
            child: Row(children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _sending || Live.instance.paused ? null : _write,
                  icon: const Icon(Icons.chat_bubble_outline_rounded),
                  label: Text(tr('Scrivi una frase', 'Write a phrase')),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: tr('Fai un sondaggio', 'Make a poll'),
                onPressed: _sending || Live.instance.paused ? null : _newPoll,
                icon: const Icon(Icons.poll_outlined),
              ),
            ]),
          ),
        ),
    ]);
  }
}

/// Scelta delle opzioni di un sondaggio "materie" o "giorni": da 2 a 5, dagli elenchi.
class _PollOptionsSheet extends StatefulWidget {
  const _PollOptionsSheet({required this.values, required this.labels, required this.days});
  final List<String> values;
  final List<String> labels;
  final bool days;
  @override
  State<_PollOptionsSheet> createState() => _PollOptionsSheetState();
}

class _PollOptionsSheetState extends State<_PollOptionsSheet> {
  final List<String> _picked = [];

  @override
  Widget build(BuildContext context) {
    final ok = _picked.length >= 2 && _picked.length <= 5;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(widget.days ? tr('Quali giorni? (da 2 a 5)', 'Which days? (2 to 5)') : tr('Quali materie? (da 2 a 5)', 'Which subjects? (2 to 5)'),
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Flexible(
            child: SingleChildScrollView(
              child: Wrap(spacing: 6, runSpacing: 6, children: [
                for (var i = 0; i < widget.values.length; i++)
                  FilterChip(
                    label: Text(widget.labels[i]),
                    selected: _picked.contains(widget.values[i]),
                    onSelected: (v) => setState(() {
                      if (v && _picked.length < 5) {
                        _picked.add(widget.values[i]);
                      } else {
                        _picked.remove(widget.values[i]);
                      }
                    }),
                  ),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: ok ? () => Navigator.pop(context, List<String>.of(_picked)) : null, child: Text(tr('Fai il sondaggio', 'Create the poll'))),
        ]),
      ),
    );
  }
}

/// Un sondaggio con le barre dei voti. Si può cambiare voto finché è aperto.
class PollCard extends StatelessWidget {
  const PollCard({super.key, required this.poll, this.onVote, this.onDelete});
  final ClassPoll poll;
  final void Function(int choice)? onVote;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final total = poll.votes;
    final best = poll.counts.isEmpty ? 0 : poll.counts.reduce((a, b) => a > b ? a : b);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.poll_outlined, size: 18, color: scheme.primary),
            const SizedBox(width: 6),
            Expanded(child: Text(poll.question, style: const TextStyle(fontWeight: FontWeight.w700))),
            if (onDelete != null)
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: tr('Togli il sondaggio', 'Remove the poll'),
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                onPressed: onDelete,
              ),
          ]),
          for (var i = 0; i < poll.options.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 8, top: 4),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: poll.open && onVote != null ? () => onVote!(i) : null,
                child: Stack(children: [
                  Positioned.fill(
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: total == 0 ? 0 : (i < poll.counts.length ? poll.counts[i] : 0) / total,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: (poll.myChoice == i ? scheme.primary : scheme.secondary).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Row(children: [
                      Icon(poll.myChoice == i ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, size: 18, color: scheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(poll.options[i],
                            style: TextStyle(fontWeight: total > 0 && i < poll.counts.length && poll.counts[i] == best ? FontWeight.w700 : FontWeight.w400)),
                      ),
                      Text('${i < poll.counts.length ? poll.counts[i] : 0}', style: TextStyle(color: scheme.onSurfaceVariant)),
                    ]),
                  ),
                ]),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              poll.open
                  ? tr('$total voti · chiude alle ${_two(poll.endsAt.hour)}:${_two(poll.endsAt.minute)}', '$total votes · closes at ${_two(poll.endsAt.hour)}:${_two(poll.endsAt.minute)}')
                  : tr('$total voti · chiuso', '$total votes · closed'),
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ),
        ]),
      ),
    );
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
}

import 'package:flutter/material.dart';

import '../models.dart';
import '../native.dart';
import '../store.dart';
import 'widgets.dart';

// ---------------------------------------------------------------------------
// Pagine "Personalizza": soprannomi ed emoji, campanelle, home, icona, notifiche.

void openNicknames(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const NicknamesPage()));

void openBells(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const BellsPage()));

void openHomeOptions(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const HomeOptionsPage()));

void openNotifications(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const NotificationsPage()));

/// Pagina con larghezza massima, come le altre impostazioni.
class _Page extends StatelessWidget {
  const _Page({required this.title, required this.children, this.actions, this.fab});

  final String title;
  final List<Widget> children;
  final List<Widget>? actions;
  final Widget? fab;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title), actions: actions),
        floatingActionButton: fab,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 96), children: children),
          ),
        ),
      );
}

String _hhmm(int m) => TimeSlot.fmt(m);

Future<int?> _pickTime(BuildContext context, int minutes, {String? help}) async {
  final t = await showTimePicker(
    context: context,
    helpText: help,
    initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
    builder: (c, child) => MediaQuery(
      data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true),
      child: child ?? const SizedBox(),
    ),
  );
  return t == null ? null : t.hour * 60 + t.minute;
}

// ---------------------------------------------------------------------------
// Soprannomi ed emoji

/// Emoji proposte nel dialogo (si può scriverne qualsiasi altra).
const _emojiIdeas = [
  '🧮', '📐', '📏', '🧪', '🔬', '⚛️', '💻', '🖥️', '📚', '📖', '✍️', '🗣️', '🇬🇧', '🇫🇷', '🇪🇸', '🇩🇪',
  '🌍', '🏛️', '⚖️', '💶', '🏀', '⚽', '🏃', '🎨', '🎵', '⚡', '⚙️', '🛠️', '🧬', '🌱', '🩺', '🙏',
  '😴', '😎', '🔥', '💀', '🤯', '⭐', '❤️', '👻',
];

/// Nomi dell'orario che si possono rinominare: materie e persone degli orari salvati.
({List<String> subjects, List<String> people}) nicknameCandidates(AppStore store) {
  final subjects = <String>{};
  final people = <String>{};
  final mine = store.myRef;
  final saved = [
    if (mine != null && store.cached(mine) != null) store.cached(mine)!,
    ...store.favorites,
    ...store.recents,
  ];
  for (final s in saved) {
    for (final d in s.week.days) {
      for (final l in d.lessons) {
        if (l.isEmpty) continue;
        subjects.add(l.rawTitle);
        if (l.rawLines.length > 1) {
          for (final p in l.rawLines[1].split(' · ')) {
            if (p.trim().isNotEmpty) people.add(p.trim());
          }
        }
      }
    }
  }
  // Anche i nomi già rinominati (magari di orari non più salvati).
  for (final k in [...nicknames.keys, ...subjectEmojis.keys]) {
    if (!subjects.contains(k) && !people.contains(k)) subjects.add(k);
  }
  int cmp(String a, String b) => a.toLowerCase().compareTo(b.toLowerCase());
  return (subjects: subjects.toList()..sort(cmp), people: (people.difference(subjects)).toList()..sort(cmp));
}

Future<void> editNickname(BuildContext context, String original, {bool withEmoji = true}) async {
  final store = StoreScope.read(context);
  final name = TextEditingController(text: nicknames[original] ?? '');
  final emoji = TextEditingController(text: subjectEmojis[original] ?? '');
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setState) => AlertDialog(
        title: Text(original),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: name,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(labelText: 'Soprannome', hintText: original, helperText: 'Vuoto = nome originale'),
              ),
              if (withEmoji) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: emoji,
                  decoration: const InputDecoration(labelText: 'Emoji', helperText: 'Compare davanti al nome'),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (final e in _emojiIdeas)
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => setState(() => emoji.text = e),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: emoji.text == e ? Theme.of(c).colorScheme.primaryContainer : null,
                          ),
                          child: Text(e, style: const TextStyle(fontSize: 20)),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              name.clear();
              emoji.clear();
              Navigator.pop(c, true);
            },
            child: const Text('Ripristina'),
          ),
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annulla')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Salva')),
        ],
      ),
    ),
  );
  if (ok == true) {
    await store.setNickname(original, name: name.text, emoji: withEmoji ? emoji.text : null);
  }
}

class NicknamesPage extends StatelessWidget {
  const NicknamesPage({super.key});

  Future<void> _addManual(BuildContext context) async {
    final ctrl = TextEditingController();
    final v = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Rinomina un nome'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nome esatto come nell\'orario',
            hintText: 'Es. Matematica, Rossi, 3B',
          ),
          onSubmitted: (v) => Navigator.pop(c, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annulla')),
          FilledButton(onPressed: () => Navigator.pop(c, ctrl.text), child: const Text('Avanti')),
        ],
      ),
    );
    if (v != null && v.trim().isNotEmpty && context.mounted) await editNickname(context, v.trim());
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final c = nicknameCandidates(store);
    Widget row(String original, {required bool subject}) {
      final n = nicknames[original];
      final e = subjectEmojis[original];
      final changed = n != null || e != null;
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          backgroundColor: changed ? scheme.primaryContainer : scheme.surfaceContainerHighest,
          child: Text(e ?? (subject ? '📘' : '👤'), style: const TextStyle(fontSize: 18)),
        ),
        title: Text(changed ? decorateSubject(original) : original),
        subtitle: changed ? Text('Originale: $original') : null,
        trailing: const Icon(Icons.edit_outlined, size: 20),
        onTap: () => editNickname(context, original),
      );
    }

    return _Page(
      title: 'Soprannomi ed emoji',
      actions: [
        if (nicknames.isNotEmpty || subjectEmojis.isNotEmpty)
          IconButton(
            tooltip: 'Togli tutti i soprannomi',
            icon: const Icon(Icons.restart_alt_rounded),
            onPressed: () => store.resetNicknames(),
          ),
      ],
      fab: FloatingActionButton.extended(
        onPressed: () => _addManual(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Altro nome'),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            'Dai un soprannome e un\'emoji a materie, prof e classi: li vedrai nell\'orario, '
            'nella home, nel widget e nelle notifiche. Solo su questo dispositivo.',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ),
        if (c.subjects.isEmpty && c.people.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 32),
            child: Text('Salva prima il tuo orario: qui compariranno le materie e i prof.'),
          ),
        if (c.subjects.isNotEmpty) const SectionLabel('Materie'),
        for (final s in c.subjects) row(s, subject: true),
        if (c.people.isNotEmpty) const SectionLabel('Prof e classi'),
        for (final p in c.people) row(p, subject: false),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Orari delle campanelle

class BellsPage extends StatefulWidget {
  const BellsPage({super.key});

  @override
  State<BellsPage> createState() => _BellsPageState();
}

class _BellsPageState extends State<BellsPage> {
  late List<(int, int)> _bells;
  bool _dirty = false;

  static List<(int, int)> _fromSlots(List<TimeSlot> slots) => [
        for (final s in slots)
          if (s.start != null && s.end != null) (s.start!, s.end!),
      ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_dirty) {
      final store = StoreScope.read(context);
      _bells = [...(store.customBells ?? _fromSlots(store.slots))];
    }
  }

  String? get _error {
    for (var i = 0; i < _bells.length; i++) {
      if (_bells[i].$2 <= _bells[i].$1) return 'La ${i + 1}ª ora finisce prima di iniziare';
      if (i > 0 && _bells[i].$1 < _bells[i - 1].$2) return 'La ${i + 1}ª ora inizia prima della fine della $iª';
    }
    return null;
  }

  void _set(void Function() f) => setState(() {
        f();
        _dirty = true;
      });

  Future<void> _edit(int i, bool start) async {
    final b = _bells[i];
    final v = await _pickTime(context, start ? b.$1 : b.$2, help: '${i + 1}ª ora · ${start ? 'inizio' : 'fine'}');
    if (v == null) return;
    _set(() => _bells[i] = start ? (v, b.$2) : (b.$1, v));
  }

  void _shift(int minutes) => _set(() => _bells = [for (final b in _bells) (b.$1 + minutes, b.$2 + minutes)]);

  Future<void> _save() async {
    final store = StoreScope.read(context);
    final school = _fromSlots(store.schoolSlots);
    final same = school.length == _bells.length &&
        [for (var i = 0; i < school.length; i++) school[i] == _bells[i]].every((x) => x);
    await store.setCustomBells(same ? null : _bells);
    if (!mounted) return;
    setState(() => _dirty = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(same ? 'Si usano gli orari della scuola' : 'Orari salvati: valgono in tutta l\'app')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final error = _error;
    final pauses = breaksOf(TimeSlot.parseAll(bellLabels(_bells)));
    return _Page(
      title: 'Orari delle campanelle',
      actions: [
        PopupMenuButton<String>(
          onSelected: (v) {
            switch (v) {
              case 'school':
                _set(() => _bells = _fromSlots(store.schoolSlots));
              case 'default':
                _set(() => _bells = _fromSlots(TimeSlot.parseAll(defaultOreLabels)));
              case 'plus5':
                _shift(5);
              case 'minus5':
                _shift(-5);
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'school', child: Text('Orari della scuola')),
            PopupMenuItem(value: 'default', child: Text('Orari predefiniti dell\'app')),
            PopupMenuItem(value: 'plus5', child: Text('Sposta tutto di +5 min')),
            PopupMenuItem(value: 'minus5', child: Text('Sposta tutto di −5 min')),
          ],
        ),
      ],
      fab: _dirty
          ? FloatingActionButton.extended(
              onPressed: error == null ? _save : null,
              icon: const Icon(Icons.save_rounded),
              label: const Text('Salva'),
            )
          : null,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: Text(
            store.customBells == null
                ? 'Ora si usano gli orari della scuola. Se cambiano (es. la ricreazione passa alle 10:10) '
                    'correggili qui: valgono per orario, home, widget e notifiche.'
                : 'Stai usando orari scelti da te. Dal menù ⋮ puoi tornare a quelli della scuola.',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ),
        for (var i = 0; i < _bells.length; i++) ...[
          Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 48,
                    child: Text('${i + 1}ª', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  ),
                  TextButton(onPressed: () => _edit(i, true), child: Text(_hhmm(_bells[i].$1))),
                  const Text('–'),
                  TextButton(onPressed: () => _edit(i, false), child: Text(_hhmm(_bells[i].$2))),
                  const Spacer(),
                  Text('${_bells[i].$2 - _bells[i].$1} min', style: TextStyle(color: scheme.onSurfaceVariant)),
                  if (i == _bells.length - 1 && _bells.length > 1)
                    IconButton(
                      tooltip: 'Togli l\'ultima ora',
                      onPressed: () => _set(() => _bells.removeLast()),
                      icon: const Icon(Icons.remove_circle_outline_rounded),
                    ),
                ],
              ),
            ),
          ),
          for (final p in pauses)
            if (p.afterIndex == i)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 12),
                child: Text('☕ ${p.label} (${p.end - p.start} min)', style: TextStyle(color: scheme.tertiary)),
              ),
        ],
        const SizedBox(height: 8),
        if (_bells.length < 10)
          OutlinedButton.icon(
            onPressed: () => _set(() {
              final last = _bells.isEmpty ? (8 * 60, 8 * 60) : _bells.last;
              final len = _bells.isEmpty ? 60 : last.$2 - last.$1;
              _bells.add((last.$2, last.$2 + len));
            }),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Aggiungi un\'ora'),
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text('⚠️ $error', style: TextStyle(color: scheme.error)),
          ),
        const SizedBox(height: 12),
        Text(
          'Per la ricreazione lascia un buco tra la fine di un\'ora e l\'inizio della successiva.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Home e app

class HomeOptionsPage extends StatelessWidget {
  const HomeOptionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    Widget sw(String key, IconData icon, String title, String? subtitle, {bool def = true}) => SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: Icon(icon, color: scheme.primary),
          title: Text(title),
          subtitle: subtitle == null ? null : Text(subtitle),
          value: store.opt(key, def),
          onChanged: (v) => store.setOpt(key, v == def ? null : v),
        );
    return _Page(
      title: 'Home e app',
      children: [
        const SectionLabel('All\'apertura'),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, icon: Icon(Icons.home_rounded), label: Text('Home')),
              ButtonSegment(value: 1, icon: Icon(Icons.today_rounded), label: Text('Il mio orario')),
              ButtonSegment(value: 2, icon: Icon(Icons.search_rounded), label: Text('Cerca')),
            ],
            selected: {store.opt('start.tab', 0)},
            onSelectionChanged: (s) => store.setOpt('start.tab', s.first == 0 ? null : s.first),
          ),
        ),
        const SectionLabel('Cosa mostrare nella home'),
        sw('home.countdown', Icons.timer_outlined, 'Conto alla rovescia', 'Fine dell\'ora, fine della scuola, vacanze'),
        sw('home.agenda', Icons.event_note_outlined, 'Compiti e verifiche in arrivo', null),
        sw('home.bag', Icons.backpack_outlined, 'Zaino per domani', null),
        sw('home.next', Icons.view_agenda_outlined, 'Lezioni del giorno', null),
        sw('home.recents', Icons.history_rounded, 'Orari salvati e recenti', null),
        sw('home.shortcuts', Icons.bolt_rounded, 'Scorciatoie rapide', 'Dov\'è il prof, Agenda, Zaino…'),
        const SectionLabel('Lingua'),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'it', label: Text('🇮🇹 Italiano')),
            ButtonSegment(value: 'en', label: Text('🇬🇧 English (beta)')),
          ],
          selected: {store.opt('lang', 'it')},
          onSelectionChanged: (s) => store.setLanguage(s.first),
        ),
        if (store.opt('lang', 'it') == 'en')
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Menus, days, dates and main screens are in English; some pages are still in Italian.',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
            ),
          ),
        const SectionLabel('Accessibilità'),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.format_size_rounded, color: scheme.primary),
          title: const Text('Dimensione del testo'),
          subtitle: Slider(
            value: store.opt('a11y.text', 100).toDouble(),
            min: 85,
            max: 160,
            divisions: 15,
            label: '${store.opt('a11y.text', 100)}%',
            onChanged: (v) => store.setOpt('a11y.text', v.round() == 100 ? null : v.round()),
          ),
          trailing: Text('${store.opt('a11y.text', 100)}%'),
        ),
        sw('a11y.contrast', Icons.contrast_rounded, 'Alto contrasto', 'Testi grigi più scuri e bordi più marcati', def: false),
        sw('a11y.motion', Icons.animation_rounded, 'Riduci le animazioni', 'Meno movimento negli sfondi e nei passaggi',
            def: false),
        sw('a11y.font', Icons.font_download_outlined, 'Font ad alta leggibilità',
            'Lexend, con più spazio tra lettere e righe: aiuta con la dislessia (la prima volta serve internet)',
            def: false),
        const SectionLabel('Orario'),
        sw('ui.emoji', Icons.emoji_emotions_outlined, 'Emoji dei laboratori', '🧪 Chimica, 💻 Informatica…'),
        sw('ui.haptic', Icons.vibration_rounded, 'Vibrazione', 'Un piccolo tocco quando cambi pagina', def: false),
      ],
    );
  }
}

/// Icone dell'app (Android): nome, colore mostrato nella scelta.
const appIconChoices = [
  ('default', 'Verde', Color(0xFF16A34A)),
  ('blue', 'Blu', Color(0xFF2563EB)),
  ('purple', 'Viola', Color(0xFF7C3AED)),
  ('red', 'Rosso', Color(0xFFDC2626)),
  ('orange', 'Arancione', Color(0xFFEA580C)),
  ('pink', 'Rosa', Color(0xFFDB2777)),
  ('black', 'Nero', Color(0xFF111827)),
];

Future<void> pickAppIcon(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  final current = await NativeBridge.appIcon();
  if (!context.mounted) return;
  final id = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Icona dell\'app', style: Theme.of(c).textTheme.titleLarge),
            const SizedBox(height: 4),
            const Text('Il telefono può metterci qualche secondo a cambiarla.'),
            const SizedBox(height: 16),
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                for (final (key, name, color) in appIconChoices)
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => Navigator.pop(c, key),
                    child: SizedBox(
                      width: 72,
                      child: Column(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: key == current
                                  ? Border.all(color: Theme.of(c).colorScheme.primary, width: 3)
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: const Text('🍃', style: TextStyle(fontSize: 26)),
                          ),
                          const SizedBox(height: 4),
                          Text(name, style: Theme.of(c).textTheme.labelMedium),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  if (id == null || id == current) return;
  await NativeBridge.setAppIcon(id);
  messenger.showSnackBar(const SnackBar(content: Text('Icona cambiata! Guarda la schermata home')));
}

// ---------------------------------------------------------------------------
// Notifiche

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    Future<void> turnOn(String key, bool v) async {
      if (v) await NativeBridge.requestNotificationPermission();
      await store.setOpt(key, v ? true : null);
    }

    Widget sw(String key, IconData icon, String title, String subtitle, {bool def = false}) => SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: Icon(icon, color: scheme.primary),
          title: Text(title),
          subtitle: Text(subtitle),
          value: store.opt(key, def),
          onChanged: def
              ? (v) => store.setOpt(key, v ? null : false)
              : (v) => turnOn(key, v),
        );

    final eveningAt = store.opt('n.eveningAt', 20 * 60);
    final lead = store.opt('n.morningLead', 30);
    return _Page(
      title: 'Notifiche',
      children: [
        if (store.myRef == null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Imposta prima "il mio orario": le notifiche si basano su quello.',
              style: TextStyle(color: scheme.error),
            ),
          ),
        const SectionLabel('Lezioni'),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: Icon(Icons.notifications_active_outlined, color: scheme.primary),
          title: const Text('Prima di ogni lezione'),
          subtitle: Text(store.notifyMinutes == null
              ? 'Materia, aula e verifiche del giorno'
              : (store.notifyMinutes == 0 ? 'All\'inizio della lezione' : '${store.notifyMinutes} minuti prima')),
          value: store.notifyMinutes != null,
          onChanged: (v) async {
            if (v) await NativeBridge.requestNotificationPermission();
            await store.setNotifyMinutes(v ? 5 : null);
          },
        ),
        if (store.notifyMinutes != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('All\'inizio')),
                ButtonSegment(value: 5, label: Text('5 min')),
                ButtonSegment(value: 10, label: Text('10 min')),
                ButtonSegment(value: 15, label: Text('15 min')),
              ],
              selected: {store.notifyMinutes!},
              onSelectionChanged: (sel) => store.setNotifyMinutes(sel.first),
            ),
          ),
        sw('n.last', Icons.hourglass_bottom_rounded, 'Ultima ora', '"Ultima ora! 💪" quando inizia'),
        sw('n.break', Icons.coffee_rounded, 'Ricreazione', 'Quando suona, con la lezione dopo'),
        sw('n.end', Icons.celebration_outlined, 'Fine della scuola', '"Scuola finita! 🎉" e a che ora entri domani'),
        const SectionLabel('La tua giornata'),
        sw('n.evening', Icons.nights_stay_outlined, 'Riepilogo della sera',
            'Il giorno dopo: ore, verifiche, compiti e cosa mettere nello zaino'),
        if (store.opt('n.evening', false) || store.opt('n.holiday', false))
          ListTile(
            contentPadding: const EdgeInsets.only(left: 56),
            title: const Text('Ora del riepilogo'),
            trailing: TextButton(
              onPressed: () async {
                final v = await _pickTime(context, eveningAt, help: 'Riepilogo della sera');
                if (v != null) await store.setOpt('n.eveningAt', v == 20 * 60 ? null : v);
              },
              child: Text(_hhmm(eveningAt)),
            ),
          ),
        sw('n.morning', Icons.wb_sunny_outlined, 'Buongiorno', 'Prima di entrare: prima ora, uscita e verifiche'),
        if (store.opt('n.morning', false))
          Padding(
            padding: const EdgeInsets.only(left: 56, bottom: 8),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 15, label: Text('15 min')),
                ButtonSegment(value: 30, label: Text('30 min')),
                ButtonSegment(value: 60, label: Text('1 ora')),
                ButtonSegment(value: 90, label: Text('1 h 30')),
              ],
              selected: {lead},
              onSelectionChanged: (s) => store.setOpt('n.morningLead', s.first == 30 ? null : s.first),
            ),
          ),
        sw('n.holiday', Icons.beach_access_outlined, 'Giorni senza scuola',
            'La sera prima di vacanze, feste e ponti'),
        sw('n.homework', Icons.assignment_late_outlined, 'Compiti non fatti',
            'Il pomeriggio prima, se in agenda ci sono compiti per domani non ancora spuntati'),
        if (store.opt('n.homework', false))
          ListTile(
            contentPadding: const EdgeInsets.only(left: 56),
            title: const Text('Ora dell\'avviso'),
            trailing: TextButton(
              onPressed: () async {
                final v = await _pickTime(context, store.opt('n.homeworkAt', 18 * 60), help: 'Compiti non fatti');
                if (v != null) await store.setOpt('n.homeworkAt', v == 18 * 60 ? null : v);
              },
              child: Text(_hhmm(store.opt('n.homeworkAt', 18 * 60))),
            ),
          ),
        sw('n.plan', Icons.menu_book_outlined, 'Piano di studio',
            'Ogni pomeriggio cosa ripassare per le verifiche in arrivo'),
        if (store.opt('n.plan', false))
          ListTile(
            contentPadding: const EdgeInsets.only(left: 56),
            title: const Text('Ora del ripasso'),
            trailing: TextButton(
              onPressed: () async {
                final v = await _pickTime(context, store.opt('n.planAt', 16 * 60), help: 'Piano di studio');
                if (v != null) await store.setOpt('n.planAt', v == 16 * 60 ? null : v);
              },
              child: Text(_hhmm(store.opt('n.planAt', 16 * 60))),
            ),
          ),
        const SectionLabel('A scuola'),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: Icon(Icons.do_not_disturb_on_outlined, color: scheme.primary),
          title: const Text('Silenzioso a scuola'),
          subtitle: const Text('Non disturbare dalla prima all\'ultima ora (con entrate e uscite), poi torna normale'),
          value: store.opt('silence', false),
          onChanged: (v) async {
            if (v && !await NativeBridge.silenceAllowed()) {
              if (!context.mounted) return;
              final go = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('Serve un permesso'),
                  content: const Text(
                    'Android chiede di dare a Easy Lesson l\'"Accesso a Non disturbare". '
                    'Si apre la pagina giusta: attiva Easy Lesson e torna qui.',
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annulla')),
                    FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Apri')),
                  ],
                ),
              );
              if (go == true) await NativeBridge.openSilenceSettings();
            }
            await store.setOpt('silence', v ? true : null);
          },
        ),
        const SectionLabel('App'),
        sw('n.updates', Icons.system_update_outlined, 'Nuove versioni',
            'Controlla GitHub ogni qualche ora, anche ad app chiusa',
            def: true),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () async {
            await NativeBridge.requestNotificationPermission();
            await NativeBridge.testNotification('Funziona! 🔔', 'Così arriveranno le notifiche di Easy Lesson');
          },
          icon: const Icon(Icons.notifications_rounded),
          label: const Text('Mandami una notifica di prova'),
        ),
        const SizedBox(height: 12),
        Text(
          'Ogni tipo di notifica si può spegnere anche dalle impostazioni di Android. '
          'Le notifiche delle lezioni saltano vacanze e giorni aggiunti nel calendario scolastico.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

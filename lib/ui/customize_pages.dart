import 'school_shortcuts.dart';
import 'package:flutter/material.dart';

import '../models.dart';
import '../live.dart';
import '../native.dart';
import '../store.dart';
import '../tts.dart';
import 'widgets.dart';
import '../i18n.dart';

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
                decoration: InputDecoration(labelText: tr('Soprannome', 'Nickname'), hintText: original, helperText: tr('Vuoto = nome originale', 'Empty = original name')),
              ),
              if (withEmoji) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: emoji,
                  decoration: InputDecoration(labelText: 'Emoji', helperText: tr('Compare davanti al nome', 'Shown before the name')),
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
            child: Text(tr('Ripristina', 'Restore')),
          ),
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('Annulla', 'Cancel'))),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(tr('Salva', 'Save'))),
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
        title: Text(tr('Rinomina un nome', 'Rename a name')),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: tr('Nome esatto come nell\'orario', 'Exact name as in the timetable'),
            hintText: tr('Es. Matematica, Rossi, 3B', 'E.g. Maths, Rossi, 3B'),
          ),
          onSubmitted: (v) => Navigator.pop(c, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(tr('Annulla', 'Cancel'))),
          FilledButton(onPressed: () => Navigator.pop(c, ctrl.text), child: Text(tr('Avanti', 'Next'))),
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
        subtitle: changed ? Text(tr('Originale: $original', 'Original: $original')) : null,
        trailing: const Icon(Icons.edit_outlined, size: 20),
        onTap: () => editNickname(context, original),
      );
    }

    return _Page(
      title: tr('Soprannomi ed emoji', 'Nicknames and emoji'),
      actions: [
        if (nicknames.isNotEmpty || subjectEmojis.isNotEmpty)
          IconButton(
            tooltip: tr('Togli tutti i soprannomi', 'Remove all nicknames'),
            icon: const Icon(Icons.restart_alt_rounded),
            onPressed: () => store.resetNicknames(),
          ),
      ],
      fab: FloatingActionButton.extended(
        onPressed: () => _addManual(context),
        icon: const Icon(Icons.add_rounded),
        label: Text(tr('Altro nome', 'Another name')),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            tr('Dai un soprannome e un\'emoji a materie, prof e classi: li vedrai nell\'orario, '
            'nella home, nel widget e nelle notifiche. Solo su questo dispositivo.', 'Give a nickname and an emoji to subjects, teachers and classes: you\'ll see them in the timetable, on the home screen, in the widget and in notifications. Only on this device.'),
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ),
        if (c.subjects.isEmpty && c.people.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 32),
            child: Text(tr('Salva prima il tuo orario: qui compariranno le materie e i prof.', 'Save your timetable first: subjects and teachers will show up here.')),
          ),
        if (c.subjects.isNotEmpty) SectionLabel(tr('Materie', 'Subjects')),
        for (final s in c.subjects) row(s, subject: true),
        if (c.people.isNotEmpty) SectionLabel(tr('Prof e classi', 'Teachers and classes')),
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
      if (_bells[i].$2 <= _bells[i].$1) return tr('La ${i + 1}ª ora finisce prima di iniziare', 'Period ${i + 1} ends before it starts');
      if (i > 0 && _bells[i].$1 < _bells[i - 1].$2) return tr('La ${i + 1}ª ora inizia prima della fine della $iª', 'Period ${i + 1} starts before period $i ends');
    }
    return null;
  }

  void _set(void Function() f) => setState(() {
        f();
        _dirty = true;
      });

  Future<void> _edit(int i, bool start) async {
    final b = _bells[i];
    final v = await _pickTime(context, start ? b.$1 : b.$2, help: '${tr('${i + 1}ª ora', 'Period ${i + 1}')} · ${start ? tr('inizio', 'start') : tr('fine', 'end')}');
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
      SnackBar(content: Text(same ? tr('Si usano gli orari della scuola', 'The school times are used') : 'Orari salvati: valgono in tutta l\'app')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final error = _error;
    final pauses = breaksOf(TimeSlot.parseAll(bellLabels(_bells)));
    return _Page(
      title: tr('Orari delle campanelle', 'Bell times'),
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
          itemBuilder: (_) => [
            PopupMenuItem(value: 'school', child: Text(tr('Orari della scuola', 'School times'))),
            PopupMenuItem(value: 'default', child: Text(tr('Orari predefiniti dell\'app', 'App default times'))),
            PopupMenuItem(value: 'plus5', child: Text(tr('Sposta tutto di +5 min', 'Move everything +5 min'))),
            PopupMenuItem(value: 'minus5', child: Text(tr('Sposta tutto di −5 min', 'Move everything −5 min'))),
          ],
        ),
      ],
      fab: _dirty
          ? FloatingActionButton.extended(
              onPressed: error == null ? _save : null,
              icon: const Icon(Icons.save_rounded),
              label: Text(tr('Salva', 'Save')),
            )
          : null,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: Text(
            store.customBells == null
                ? tr('Ora si usano gli orari della scuola. Se cambiano (es. la ricreazione passa alle 10:10) '
                    'correggili qui: valgono per orario, home, widget e notifiche.', 'The school times are used now. If they change (e.g. the break moves to 10:10) fix them here: they apply to the timetable, home, widget and notifications.')
                : tr('Stai usando orari scelti da te. Dal menù ⋮ puoi tornare a quelli della scuola.', 'You\'re using times you chose. From the ⋮ menu you can go back to the school\'s.'),
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
                  Text(tr('${_bells[i].$2 - _bells[i].$1} min', '${_bells[i].$2 - _bells[i].$1} min'), style: TextStyle(color: scheme.onSurfaceVariant)),
                  if (i == _bells.length - 1 && _bells.length > 1)
                    IconButton(
                      tooltip: tr('Togli l\'ultima ora', 'Remove the last period'),
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
                child: Text(tr('☕ ${p.label} (${p.end - p.start} min)', '☕ ${p.label} (${p.end - p.start} min)'), style: TextStyle(color: scheme.tertiary)),
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
            label: Text(tr('Aggiungi un\'ora', 'Add a period')),
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text('⚠️ $error', style: TextStyle(color: scheme.error)),
          ),
        const SizedBox(height: 12),
        Text(
          tr('Per la ricreazione lascia un buco tra la fine di un\'ora e l\'inizio della successiva.', 'For the break, leave a gap between the end of a period and the start of the next.'),
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
      title: tr('Home e app', 'Home and app'),
      children: [
        const SectionLabel('All\'apertura'),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SegmentedButton<int>(
            segments: [
              ButtonSegment(value: 0, icon: const Icon(Icons.home_rounded), label: Text(tr('Home', 'Home'))),
              ButtonSegment(value: 1, icon: const Icon(Icons.today_rounded), label: Text(tr('Il mio orario', 'My timetable'))),
              ButtonSegment(value: 2, icon: const Icon(Icons.search_rounded), label: Text(tr('Cerca', 'Search'))),
            ],
            selected: {store.opt('start.tab', 0)},
            onSelectionChanged: (s) => store.setOpt('start.tab', s.first == 0 ? null : s.first),
          ),
        ),
        SectionLabel(tr('Cosa mostrare nella home', 'What to show on the home screen')),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.apps_rounded),
          title: Text(tr('Pulsanti della scuola', 'School buttons')),
          subtitle: Text('${chosenSchoolTools(store).map((t) => t.label).join(', ')} · ${tr('Altro', 'More')}'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => editSchoolShortcuts(context),
        ),
        // 3.8 "minimal": di base solo la card della lezione (con ricreazione e campanella) e le lezioni del giorno.
        sw('home.next', Icons.view_agenda_outlined, tr('Lezioni del giorno', 'Today\'s lessons'), null),
        sw('home.countdown', Icons.timer_outlined, tr('Conti alla rovescia delle feste', 'Holiday countdowns'), tr('Weekend, vacanze e i tuoi', 'Weekends, holidays and yours'), def: false),
        sw('home.exam', Icons.school_outlined, tr('Maturità', 'Final exam'), tr('Giorni che mancano e quanto hai ripassato', 'Days left and how much you\'ve reviewed'), def: true),
        sw('home.agenda', Icons.event_note_outlined, tr('Compiti e verifiche in arrivo', 'Upcoming homework and tests'), null, def: false),
        sw('home.bag', Icons.backpack_outlined, tr('Zaino per domani', 'Backpack for tomorrow'), null, def: false),
        SectionLabel(tr('Lingua', 'Language')),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'it', label: Text('🇮🇹 Italiano')),
            ButtonSegment(value: 'en', label: Text('🇬🇧 English')),
          ],
          selected: {store.opt('lang', 'it')},
          onSelectionChanged: (s) => store.setLanguage(s.first),
        ),
        if (store.opt('lang', 'it') == 'en')
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'The whole app is in English. Subjects, teachers and classes stay as in the school timetable.',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
            ),
          ),
        SectionLabel(tr('Accessibilità', 'Accessibility')),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.format_size_rounded, color: scheme.primary),
          title: Text(tr('Dimensione del testo', 'Text size')),
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
        sw('a11y.contrast', Icons.contrast_rounded, tr('Alto contrasto', 'High contrast'), tr('Testi grigi più scuri e bordi più marcati', 'Darker grey text and stronger borders'), def: false),
        sw('a11y.motion', Icons.animation_rounded, tr('Riduci le animazioni', 'Reduce animations'), tr('Meno movimento negli sfondi e nei passaggi', 'Less motion in backgrounds and transitions'),
            def: false),
        sw('a11y.font', Icons.font_download_outlined, tr('Font ad alta leggibilità', 'High-readability font'),
            tr('Lexend, con più spazio tra lettere e righe: aiuta con la dislessia (la prima volta serve internet)', 'Lexend, with more space between letters and lines: helps with dyslexia (needs internet the first time)'),
            def: false),
        ListTile(
          leading: const Icon(Icons.format_line_spacing_rounded),
          title: Text(tr('Spaziatura del testo', 'Text spacing')),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: SegmentedButton<int>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: 0, label: Text(tr('Normale', 'Normal'))),
                ButtonSegment(value: 1, label: Text(tr('Ampia', 'Wide'))),
                ButtonSegment(value: 2, label: Text(tr('Più ampia', 'Wider'))),
                ButtonSegment(value: 3, label: Text(tr('Massima', 'Max'))),
              ],
              selected: {store.opt('a11y.spacing', 0)},
              onSelectionChanged: (v) => store.setOpt('a11y.spacing', v.first == 0 ? null : v.first),
            ),
          ),
        ),
        if (Tts.supported) ...[
          sw('a11y.tts', Icons.record_voice_over_outlined, tr('Lettura ad alta voce', 'Read aloud'),
              tr('Pulsante 🔊 su flashcard, giornata e agenda: legge il testo con la voce del telefono',
                  'A 🔊 button on flashcards, your day and planner: reads text with the phone\'s voice'),
              def: false),
          if (store.opt('a11y.tts', false))
            ListTile(
              contentPadding: const EdgeInsets.only(left: 56, right: 16),
              title: Text(tr('Velocità della voce', 'Voice speed')),
              subtitle: Slider(
                value: Tts.rate(store),
                min: 0.5,
                max: 1.5,
                divisions: 10,
                label: '${Tts.rate(store).toStringAsFixed(1)}×',
                onChanged: (v) => store.setOpt('a11y.ttsRate', (v * 10).round() == 10 ? null : v),
                onChangeEnd: (_) => Tts.speak(store, tr('Ciao! Così leggo ad alta voce.', 'Hi! This is how I read aloud.')),
              ),
            ),
        ],
        SectionLabel(tr('Orario', 'Timetable')),
        sw('ui.emoji', Icons.emoji_emotions_outlined, tr('Emoji dei laboratori', 'Lab emoji'), tr('🧪 Chimica, 💻 Informatica…', '🧪 Chemistry, 💻 Computer science…')),
        sw('ui.haptic', Icons.vibration_rounded, tr('Vibrazione', 'Vibration'), tr('Un piccolo tocco quando cambi pagina', 'A small tap when you change page'), def: false),
      ],
    );
  }
}

/// Icone dell'app (Android): nome, colore mostrato nella scelta.
List<(String, String, Color)> get appIconChoices => [
  ('default', tr('Verde', 'Green'), const Color(0xFF16A34A)),
  ('blue', tr('Blu', 'Blue'), const Color(0xFF2563EB)),
  ('purple', tr('Viola', 'Purple'), const Color(0xFF7C3AED)),
  ('red', tr('Rosso', 'Red'), const Color(0xFFDC2626)),
  ('orange', tr('Arancione', 'Orange'), const Color(0xFFEA580C)),
  ('pink', tr('Rosa', 'Pink'), const Color(0xFFDB2777)),
  ('black', tr('Nero', 'Black'), const Color(0xFF111827)),
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
            Text(tr('Icona dell\'app', 'App icon'), style: Theme.of(c).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(tr('Il telefono può metterci qualche secondo a cambiarla.', 'The phone may take a few seconds to change it.')),
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
  messenger.showSnackBar(SnackBar(content: Text(tr('Icona cambiata! Guarda la schermata home', 'Icon changed! Check the home screen'))));
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
      title: tr('Notifiche', 'Notifications'),
      children: [
        if (store.myRef == null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              tr('Imposta prima "il mio orario": le notifiche si basano su quello.', 'Set "my timetable" first: notifications are based on it.'),
              style: TextStyle(color: scheme.error),
            ),
          ),
        SectionLabel(tr('Lezioni', 'Lessons')),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: Icon(Icons.notifications_active_outlined, color: scheme.primary),
          title: Text(tr('Prima di ogni lezione', 'Before each lesson')),
          subtitle: Text(store.notifyMinutes == null
              ? tr('Materia, aula e verifiche del giorno', 'Subject, room and tests of the day')
              : (store.notifyMinutes == 0 ? tr('All\'inizio della lezione', 'At the start of the lesson') : tr('${store.notifyMinutes} minuti prima', '${store.notifyMinutes} minutes before'))),
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
              segments: [
                ButtonSegment(value: 0, label: Text(tr('All\'inizio', 'At the start'))),
                const ButtonSegment(value: 5, label: Text('5 min')),
                const ButtonSegment(value: 10, label: Text('10 min')),
                const ButtonSegment(value: 15, label: Text('15 min')),
              ],
              selected: {store.notifyMinutes!},
              onSelectionChanged: (sel) => store.setNotifyMinutes(sel.first),
            ),
          ),
        // 3.8: messaggi in diretta (classe, grandi, moderazione). Accese di base.
        SwitchListTile(
          secondary: const Icon(Icons.chat_bubble_outline_rounded),
          title: Text(tr('Messaggi', 'Messages')),
          subtitle: Text(tr('Nuovi messaggi nelle chat, anche con l\'app chiusa', 'New chat messages, even with the app closed')),
          value: store.opt('n.chat', true),
          onChanged: (v) async {
            if (v) await NativeBridge.requestNotificationPermission();
            await store.setOpt('n.chat', v ? null : false);
            // Con l'app chiusa avvisa il server (Firebase): si registra o si toglie il telefono.
            Live.instance.syncPush();
          },
        ),
        if (store.opt('n.chat', true))
          SwitchListTile(
            secondary: const Icon(Icons.do_not_disturb_on_outlined),
            title: Text(tr('Messaggi in pausa durante le lezioni', 'Hold messages during lessons')),
            subtitle: Text(tr('Le notifiche delle chat aspettano la ricreazione o la fine delle lezioni: poi un solo riassunto',
                'Chat notifications wait for the break or the end of lessons, then one summary')),
            value: store.opt('n.hold', false),
            onChanged: (v) async {
              await store.setOpt('n.hold', v ? true : null);
              Live.instance.syncQuiet();
            },
          ),
        sw('n.last', Icons.hourglass_bottom_rounded, tr('Ultima ora', 'Last period'), tr('"Ultima ora! 💪" quando inizia', '"Last period! 💪" when it starts')),
        sw('n.break', Icons.coffee_rounded, tr('Ricreazione', 'Break'), tr('Quando suona, con la lezione dopo', 'When the bell rings, with the next lesson')),
        sw('n.end', Icons.celebration_outlined, tr('Fine della scuola', 'End of school'), tr('"Scuola finita! 🎉" e a che ora entri domani', '"School\'s over! 🎉" and what time you start tomorrow')),
        SectionLabel(tr('La tua giornata', 'Your day')),
        sw('n.evening', Icons.nights_stay_outlined, tr('Riepilogo della sera', 'Evening summary'),
            tr('Il giorno dopo: ore, verifiche, compiti e cosa mettere nello zaino', 'The next day: periods, tests, homework and what to put in the backpack')),
        if (store.opt('n.evening', false) || store.opt('n.holiday', false))
          ListTile(
            contentPadding: const EdgeInsets.only(left: 56),
            title: Text(tr('Ora del riepilogo', 'Summary time')),
            trailing: TextButton(
              onPressed: () async {
                final v = await _pickTime(context, eveningAt, help: tr('Riepilogo della sera', 'Evening summary'));
                if (v != null) await store.setOpt('n.eveningAt', v == 20 * 60 ? null : v);
              },
              child: Text(_hhmm(eveningAt)),
            ),
          ),
        sw('n.morning', Icons.wb_sunny_outlined, tr('Buongiorno', 'Good morning'), tr('Prima di entrare: prima ora, uscita e verifiche', 'Before going in: first period, exit and tests')),
        if (store.opt('n.morning', false))
          Padding(
            padding: const EdgeInsets.only(left: 56, bottom: 8),
            child: SegmentedButton<int>(
              segments: [
                const ButtonSegment(value: 15, label: Text('15 min')),
                const ButtonSegment(value: 30, label: Text('30 min')),
                ButtonSegment(value: 60, label: Text(tr('1 ora', '1 hour'))),
                const ButtonSegment(value: 90, label: Text('1 h 30')),
              ],
              selected: {lead},
              onSelectionChanged: (s) => store.setOpt('n.morningLead', s.first == 30 ? null : s.first),
            ),
          ),
        sw('n.holiday', Icons.beach_access_outlined, tr('Giorni senza scuola', 'Days without school'),
            tr('La sera prima di vacanze, feste e ponti', 'The evening before holidays and long weekends')),
        sw('n.homework', Icons.assignment_late_outlined, tr('Compiti non fatti', 'Homework not done'),
            tr('Il pomeriggio prima, se in agenda ci sono compiti per domani non ancora spuntati', 'The afternoon before, if the planner has homework for tomorrow not yet ticked off')),
        if (store.opt('n.homework', false))
          ListTile(
            contentPadding: const EdgeInsets.only(left: 56),
            title: Text(tr('Ora dell\'avviso', 'Reminder time')),
            trailing: TextButton(
              onPressed: () async {
                final v = await _pickTime(context, store.opt('n.homeworkAt', 18 * 60), help: tr('Compiti non fatti', 'Homework not done'));
                if (v != null) await store.setOpt('n.homeworkAt', v == 18 * 60 ? null : v);
              },
              child: Text(_hhmm(store.opt('n.homeworkAt', 18 * 60))),
            ),
          ),
        sw('n.plan', Icons.menu_book_outlined, tr('Piano di studio', 'Study plan'),
            tr('Ogni pomeriggio cosa ripassare per le verifiche in arrivo', 'Every afternoon, what to review for upcoming tests')),
        if (store.opt('n.plan', false))
          ListTile(
            contentPadding: const EdgeInsets.only(left: 56),
            title: Text(tr('Ora del ripasso', 'Review time')),
            trailing: TextButton(
              onPressed: () async {
                final v = await _pickTime(context, store.opt('n.planAt', 16 * 60), help: tr('Piano di studio', 'Study plan'));
                if (v != null) await store.setOpt('n.planAt', v == 16 * 60 ? null : v);
              },
              child: Text(_hhmm(store.opt('n.planAt', 16 * 60))),
            ),
          ),
        SectionLabel(tr('A scuola', 'At school')),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: Icon(Icons.do_not_disturb_on_outlined, color: scheme.primary),
          title: Text(tr('Silenzioso a scuola', 'Silent at school')),
          subtitle: Text(tr('Non disturbare dalla prima all\'ultima ora (con entrate e uscite), poi torna normale', 'Do not disturb from the first to the last period (with late entries and early exits), then back to normal')),
          value: store.opt('silence', false),
          onChanged: (v) async {
            if (v && !await NativeBridge.silenceAllowed()) {
              if (!context.mounted) return;
              final go = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: Text(tr('Serve un permesso', 'Permission needed')),
                  content: Text(
                    tr('Android chiede di dare a Easy Lesson l\'"Accesso a Non disturbare". '
                    'Si apre la pagina giusta: attiva Easy Lesson e torna qui.', 'Android asks you to give Easy Lesson "Do Not Disturb access". The right page opens: turn on Easy Lesson and come back here.'),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('Annulla', 'Cancel'))),
                    FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(tr('Apri', 'Open'))),
                  ],
                ),
              );
              if (go == true) await NativeBridge.openSilenceSettings();
            }
            await store.setOpt('silence', v ? true : null);
          },
        ),
        const SectionLabel('App'),
        sw('n.updates', Icons.system_update_outlined, tr('Nuove versioni', 'New versions'),
            tr('Controlla GitHub ogni qualche ora, anche ad app chiusa', 'Check GitHub every few hours, even with the app closed'),
            def: true),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () async {
            await NativeBridge.requestNotificationPermission();
            await NativeBridge.testNotification(tr('Funziona! 🔔', 'It works! 🔔'), tr('Così arriveranno le notifiche di Easy Lesson', 'So Easy Lesson notifications will arrive'));
          },
          icon: const Icon(Icons.notifications_rounded),
          label: Text(tr('Mandami una notifica di prova', 'Send me a test notification')),
        ),
        const SizedBox(height: 12),
        Text(
          tr('Ogni tipo di notifica si può spegnere anche dalle impostazioni di Android. '
          'Le notifiche delle lezioni saltano vacanze e giorni aggiunti nel calendario scolastico.', 'Each type of notification can also be turned off from the Android settings. Lesson notifications skip holidays and days added to the school calendar.'),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

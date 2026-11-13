import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../activity_xp.dart';
import '../flashcards.dart';
import '../i18n.dart';
import '../store.dart';
import 'agenda_page.dart' show mySubjects;
import 'speak_button.dart';
import 'widgets.dart';

// Flashcard (3.9): mazzi per materia, carte domanda/risposta, ripasso a intervalli (vedi flashcards.dart).

void openFlashcards(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const FlashcardsPage()));

/// XP per ogni carta ripassata (sempre dentro il tetto giornaliero di activity_xp.dart).
const _xpPerCard = 2;

const _deckEmojis = ['🃏', '📘', '🧪', '📐', '🌍', '🏛️', '🇬🇧', '🎨', '💻', '🧬', '⚡', '🎵'];

Widget _page(List<Widget> children) => Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 96), children: children),
      ),
    );

class FlashcardsPage extends StatelessWidget {
  const FlashcardsPage({super.key});

  Future<void> _newDeck(BuildContext context) async {
    final store = StoreScope.read(context);
    final r = await _deckDialog(context, title: tr('Nuovo mazzo', 'New deck'), subjects: mySubjects(store));
    if (r == null) return;
    final decks = Flashcards.decks(store);
    if (decks.length >= maxDecks) return;
    decks.add(Deck(id: Flashcards.newId(), name: r.$1, subject: r.$2, emoji: r.$3));
    await Flashcards.save(store, decks);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final decks = Flashcards.decks(store);
    final today = DateTime.now();
    final due = decks.fold<int>(0, (n, d) => n + d.dueCards(today).length);
    return Scaffold(
      appBar: AppBar(title: Text(tr('Flashcard', 'Flashcards'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _newDeck(context),
        icon: const Icon(Icons.add_rounded),
        label: Text(tr('Mazzo', 'Deck')),
      ),
      body: decks.isEmpty
          ? EmptyState(
              icon: Icons.style_rounded,
              title: tr('Nessun mazzo', 'No decks'),
              message: tr(
                  'Crea un mazzo per materia e aggiungi domande e risposte. Le carte che sbagli tornano prima, quelle che sai sempre si fanno vedere sempre più di rado.',
                  'Create a deck per subject and add questions and answers. Cards you get wrong come back sooner, the ones you always know show up less and less.'),
              action: FilledButton.icon(onPressed: () => _newDeck(context), icon: const Icon(Icons.add_rounded), label: Text(tr('Crea un mazzo', 'Create a deck'))),
            )
          : _page([
              if (due > 0)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.local_fire_department_rounded, color: Colors.deepOrange),
                    title: Text(tr('$due carte da ripassare oggi', '$due cards to review today')),
                    subtitle: Text(tr('Ripassa tutti i mazzi insieme', 'Review all decks together')),
                    trailing: const Icon(Icons.play_arrow_rounded),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ReviewPage())),
                  ),
                ),
              SectionLabel(tr('Mazzi', 'Decks')),
              for (final d in decks)
                Card(
                  child: ListTile(
                    leading: Text(d.emoji, style: const TextStyle(fontSize: 28)),
                    title: Text(d.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text([
                      if (d.subject.isNotEmpty) d.subject,
                      tr('${d.cards.length} carte', '${d.cards.length} cards'),
                      if (d.cards.isNotEmpty) tr('${d.masteredCount} imparate', '${d.masteredCount} learned'),
                    ].join(' · ')),
                    trailing: d.dueCards(today).isEmpty
                        ? const Icon(Icons.chevron_right_rounded)
                        : Badge(label: Text('${d.dueCards(today).length}'), child: const Icon(Icons.chevron_right_rounded)),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => DeckPage(deckId: d.id))),
                  ),
                ),
            ]),
    );
  }
}

Future<(String, String, String)?> _deckDialog(BuildContext context,
    {required String title, required List<String> subjects, Deck? deck}) async {
  final name = TextEditingController(text: deck?.name ?? '');
  var subject = deck?.subject ?? '';
  var emoji = deck?.emoji ?? _deckEmojis.first;
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setState) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextField(
              controller: name,
              autofocus: deck == null,
              maxLength: 60,
              decoration: InputDecoration(labelText: tr('Nome', 'Name'), hintText: tr('Verbi irregolari, Rivoluzione francese…', 'Irregular verbs, French Revolution…')),
            ),
            if (subjects.isNotEmpty)
              DropdownButtonFormField<String>(
                initialValue: subjects.contains(subject) ? subject : '',
                decoration: InputDecoration(labelText: tr('Materia', 'Subject')),
                items: [
                  DropdownMenuItem(value: '', child: Text(tr('Nessuna', 'None'))),
                  for (final s in subjects) DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => subject = v ?? '',
              ),
            const SizedBox(height: 12),
            Wrap(spacing: 4, children: [
              for (final e in _deckEmojis)
                ChoiceChip(label: Text(e, style: const TextStyle(fontSize: 18)), selected: e == emoji, onSelected: (_) => setState(() => emoji = e)),
            ]),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('Annulla', 'Cancel'))),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(tr('Salva', 'Save'))),
        ],
      ),
    ),
  );
  final n = name.text.trim();
  if (ok != true || n.isEmpty) return null;
  return (n, subject, emoji);
}

class DeckPage extends StatelessWidget {
  const DeckPage({super.key, required this.deckId});
  final String deckId;

  Future<void> _update(BuildContext context, void Function(Deck d) change) async {
    final store = StoreScope.read(context);
    final decks = Flashcards.decks(store);
    final i = decks.indexWhere((d) => d.id == deckId);
    if (i < 0) return;
    change(decks[i]);
    await Flashcards.save(store, decks);
  }

  Future<void> _card(BuildContext context, {FlashCard? card}) async {
    final f = TextEditingController(text: card?.front ?? '');
    final b = TextEditingController(text: card?.back ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(card == null ? tr('Nuova carta', 'New card') : tr('Modifica carta', 'Edit card')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: f, autofocus: true, maxLength: maxSideLength, minLines: 1, maxLines: 4, decoration: InputDecoration(labelText: tr('Domanda', 'Question'))),
          TextField(controller: b, maxLength: maxSideLength, minLines: 1, maxLines: 4, decoration: InputDecoration(labelText: tr('Risposta', 'Answer'))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('Annulla', 'Cancel'))),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(tr('Salva', 'Save'))),
        ],
      ),
    );
    if (ok != true || f.text.trim().isEmpty || b.text.trim().isEmpty || !context.mounted) return;
    await _update(context, (d) {
      if (card == null) {
        if (d.cards.length < maxCardsPerDeck) d.cards.add(FlashCard(id: Flashcards.newId(), front: f.text.trim(), back: b.text.trim()));
      } else {
        final c = d.cards.where((x) => x.id == card.id).firstOrNull;
        c?.front = f.text.trim();
        c?.back = b.text.trim();
      }
    });
  }

  Future<void> _paste(BuildContext context) async {
    final t = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('Incolla tante carte', 'Paste many cards')),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: t,
            minLines: 6,
            maxLines: 12,
            decoration: InputDecoration(
              helperMaxLines: 3,
              helperText: tr('Una carta per riga: domanda ; risposta (vanno bene anche " - " e " = ")',
                  'One card per line: question ; answer (" - " and " = " work too)'),
              hintText: tr('go ; went\nbe ; was/were', 'go ; went\nbe ; was/were'),
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('Annulla', 'Cancel'))),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(tr('Aggiungi', 'Add'))),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final cards = parseCards(t.text);
    var added = 0;
    await _update(context, (d) {
      for (final (f, b) in cards) {
        if (d.cards.length >= maxCardsPerDeck) break;
        d.cards.add(FlashCard(id: '${Flashcards.newId()}$added', front: f, back: b));
        added++;
      }
    });
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Aggiunte $added carte', 'Added $added cards'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final deck = Flashcards.decks(store).where((d) => d.id == deckId).firstOrNull;
    if (deck == null) return Scaffold(appBar: AppBar());
    final due = deck.dueCards(DateTime.now());
    return Scaffold(
      appBar: AppBar(
        title: Text('${deck.emoji} ${deck.name}'),
        actions: [
          IconButton(tooltip: tr('Incolla tante carte', 'Paste many cards'), onPressed: () => _paste(context), icon: const Icon(Icons.playlist_add_rounded)),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'edit') {
                final r = await _deckDialog(context, title: tr('Modifica mazzo', 'Edit deck'), subjects: mySubjects(store), deck: deck);
                if (r != null && context.mounted) {
                  await _update(context, (d) {
                    d.name = r.$1;
                    d.subject = r.$2;
                    d.emoji = r.$3;
                  });
                }
              } else if (v == 'reset') {
                await _update(context, (d) {
                  for (final c in d.cards) {
                    c.box = 0;
                    c.due = DateTime.now();
                  }
                });
              } else if (v == 'delete') {
                final yes = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: Text(tr('Eliminare "${deck.name}"?', 'Delete "${deck.name}"?')),
                    content: Text(tr('Si perdono tutte le ${deck.cards.length} carte.', 'All ${deck.cards.length} cards will be lost.')),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('Annulla', 'Cancel'))),
                      FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(tr('Elimina', 'Delete'))),
                    ],
                  ),
                );
                if (yes == true && context.mounted) {
                  final decks = Flashcards.decks(store)..removeWhere((d) => d.id == deckId);
                  await Flashcards.save(store, decks);
                  if (context.mounted) Navigator.of(context).pop();
                }
              }
            },
            itemBuilder: (c) => [
              PopupMenuItem(value: 'edit', child: Text(tr('Modifica', 'Edit'))),
              PopupMenuItem(value: 'reset', child: Text(tr('Ricomincia da capo', 'Start over'))),
              PopupMenuItem(value: 'delete', child: Text(tr('Elimina mazzo', 'Delete deck'))),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: tr('Nuova carta', 'New card'),
        onPressed: () => _card(context),
        child: const Icon(Icons.add_rounded),
      ),
      body: _page([
        FilledButton.icon(
          onPressed: deck.cards.isEmpty
              ? null
              : () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ReviewPage(deckId: deckId, all: due.isEmpty))),
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text(due.isEmpty
              ? tr('Ripassa comunque tutte', 'Review all anyway')
              : tr('Ripassa ${due.length} carte', 'Review ${due.length} cards')),
        ),
        if (deck.cards.isNotEmpty) ...[
          const SizedBox(height: 12),
          _BoxesBar(deck: deck),
        ],
        SectionLabel(tr('Carte', 'Cards')),
        if (deck.cards.isEmpty)
          Text(tr('Ancora nessuna carta: aggiungile con + oppure incollale tutte insieme.', 'No cards yet: add them with + or paste them all at once.')),
        for (final c in deck.cards)
          Dismissible(
            key: ValueKey(c.id),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              color: Theme.of(context).colorScheme.errorContainer,
              child: const Icon(Icons.delete_outline_rounded),
            ),
            onDismissed: (_) => _update(context, (d) => d.cards.removeWhere((x) => x.id == c.id)),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(c.front, maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text(c.back, maxLines: 2, overflow: TextOverflow.ellipsis),
              trailing: Text(c.mastered ? '⭐' : '${c.box}/$maxBox'),
              onTap: () => _card(context, card: c),
            ),
          ),
      ]),
    );
  }
}

/// Quante carte per scatola (0 = da imparare … 5 = imparate bene).
class _BoxesBar extends StatelessWidget {
  const _BoxesBar({required this.deck});
  final Deck deck;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final counts = List.filled(maxBox + 1, 0);
    for (final c in deck.cards) {
      counts[c.box]++;
    }
    return Row(children: [
      for (var i = 0; i <= maxBox; i++)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Column(children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: counts[i] == 0 ? scheme.surfaceContainerHighest : Color.lerp(scheme.error, Colors.green, i / maxBox),
                ),
              ),
              const SizedBox(height: 4),
              Text('${counts[i]}', style: Theme.of(context).textTheme.labelSmall),
            ]),
          ),
        ),
    ]);
  }
}

/// Ripasso: le carte da ripassare di un mazzo (o di tutti). Le sbagliate tornano in fondo alla fila.
class ReviewPage extends StatefulWidget {
  const ReviewPage({super.key, this.deckId, this.all = false});
  final String? deckId;

  /// true = tutte le carte del mazzo, anche quelle non ancora "in scadenza".
  final bool all;

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  late List<Deck> _decks;
  final List<(String, String)> _queue = []; // (deckId, cardId)
  bool _flipped = false;
  int _done = 0;
  int _knew = 0;
  int _xp = 0;
  bool _ready = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    _ready = true;
    final store = StoreScope.read(context);
    _decks = Flashcards.decks(store);
    final today = DateTime.now();
    for (final d in _decks) {
      if (widget.deckId != null && d.id != widget.deckId) continue;
      for (final c in (widget.all ? d.cards : d.dueCards(today))) {
        _queue.add((d.id, c.id));
      }
    }
    _queue.shuffle(math.Random());
  }

  FlashCard? _card((String, String) k) =>
      _decks.where((d) => d.id == k.$1).firstOrNull?.cards.where((c) => c.id == k.$2).firstOrNull;

  Future<void> _answer(bool knew) async {
    final store = StoreScope.read(context);
    final k = _queue.removeAt(0);
    final c = _card(k);
    if (c != null) {
      reviewCard(c, knew: knew);
      if (!knew) _queue.add(k); // la rivedi prima di finire
    }
    _done++;
    if (knew) _knew++;
    setState(() => _flipped = false);
    await Flashcards.save(store, _decks);
    await store.bump('flashReviewed');
    _xp += await awardActivityXp(store, _xpPerCard);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (_queue.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(tr('Ripasso', 'Review'))),
        body: EmptyState(
          icon: Icons.emoji_events_rounded,
          title: _done == 0 ? tr('Niente da ripassare', 'Nothing to review') : tr('Ripasso finito!', 'Review done!'),
          message: _done == 0
              ? tr('Per oggi le carte sono tutte a posto.', 'All cards are fine for today.')
              : tr('$_done risposte, $_knew giuste al primo colpo o dopo.${_xp > 0 ? ' +$_xp XP' : ''}',
                  '$_done answers, $_knew right.${_xp > 0 ? ' +$_xp XP' : ''}'),
          action: FilledButton(onPressed: () => Navigator.of(context).pop(), child: Text(tr('Fine', 'Done'))),
        ),
      );
    }
    final card = _card(_queue.first);
    return Scaffold(
      appBar: AppBar(title: Text(tr('Ripasso · ${_queue.length} rimaste', 'Review · ${_queue.length} left'))),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _flipped = !_flipped),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      transitionBuilder: (child, a) => ScaleTransition(scale: Tween(begin: 0.92, end: 1.0).animate(a), child: FadeTransition(opacity: a, child: child)),
                      child: Card(
                        key: ValueKey('${_queue.first}$_flipped'),
                        color: _flipped ? scheme.secondaryContainer : scheme.surfaceContainerHigh,
                        child: SizedBox.expand(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Text(_flipped ? tr('RISPOSTA', 'ANSWER') : tr('DOMANDA', 'QUESTION'),
                                  style: theme.textTheme.labelMedium?.copyWith(letterSpacing: 1.2, color: scheme.onSurfaceVariant)),
                              const SizedBox(height: 16),
                              Flexible(
                                child: SingleChildScrollView(
                                  child: Text(
                                    (_flipped ? card?.back : card?.front) ?? '',
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                              if (!_flipped) ...[
                                const SizedBox(height: 16),
                                Text(tr('Tocca per girarla', 'Tap to flip'), style: theme.textTheme.bodySmall),
                              ],
                              SpeakButton(text: () => (_flipped ? card?.back : card?.front) ?? ''),
                            ]),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_flipped)
                  Row(children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                        onPressed: () => _answer(false),
                        icon: const Icon(Icons.close_rounded),
                        label: Text(tr('Non la sapevo', 'Didn\'t know')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                        onPressed: () => _answer(true),
                        icon: const Icon(Icons.check_rounded),
                        label: Text(tr('La sapevo', 'Knew it')),
                      ),
                    ),
                  ])
                else
                  FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    onPressed: () => setState(() => _flipped = true),
                    child: Text(tr('Mostra la risposta', 'Show the answer')),
                  ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

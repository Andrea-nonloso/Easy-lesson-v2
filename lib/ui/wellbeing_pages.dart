import 'package:flutter/material.dart';

import '../activity_xp.dart';
import '../agenda.dart' show dateOnly;
import '../i18n.dart';
import '../progress.dart' show isoDay;
import '../store.dart';
import '../wellbeing.dart';
import 'widgets.dart';

// Abitudini e umore (3.9): solo sul telefono.

void openHabits(BuildContext context) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const HabitsPage()));
void openMood(BuildContext context) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const MoodPage()));

const _habitXp = 3;
const _moodXp = 5;

Widget _page(List<Widget> children) => Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 96), children: children),
      ),
    );

String _dayLetter(DateTime d) => [
      tr('L', 'M'),
      tr('M', 'T'),
      tr('M', 'W'),
      tr('G', 'T'),
      tr('V', 'F'),
      tr('S', 'S'),
      tr('D', 'S'),
    ][d.weekday - 1];

// ---------------------------------------------------------------------------- abitudini

class HabitsPage extends StatelessWidget {
  const HabitsPage({super.key});

  Future<void> _add(BuildContext context, {Habit? edit}) async {
    final store = StoreScope.read(context);
    final name = TextEditingController(text: edit?.name ?? '');
    var emoji = edit?.emoji ?? '✅';
    const emojis = ['✅', '😴', '💧', '📖', '🏃', '📵', '🎒', '🍎', '🧘', '🇬🇧', '🛏️', '🎸', '🧹', '🙏'];
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setState) => AlertDialog(
          title: Text(edit == null ? tr('Nuova abitudine', 'New habit') : tr('Modifica abitudine', 'Edit habit')),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (edit == null) ...[
                Text(tr('Già pronte', 'Ready-made'), style: Theme.of(c).textTheme.labelLarge),
                const SizedBox(height: 4),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final (e, n) in habitPresets)
                    ActionChip(
                      label: Text('$e $n'),
                      onPressed: () => setState(() {
                        emoji = e;
                        name.text = n;
                      }),
                    ),
                ]),
                const SizedBox(height: 12),
              ],
              TextField(controller: name, maxLength: 40, decoration: InputDecoration(labelText: tr('Nome', 'Name'))),
              Wrap(spacing: 2, children: [
                for (final e in emojis)
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
    if (ok != true || n.isEmpty) return;
    final list = Habits.all(store);
    if (edit == null) {
      if (list.length >= maxHabits) return;
      list.add(Habit(id: '${DateTime.now().microsecondsSinceEpoch}', name: n, emoji: emoji));
    } else {
      final h = list.where((x) => x.id == edit.id).firstOrNull;
      h?.name = n;
      h?.emoji = emoji;
    }
    await Habits.save(store, list);
  }

  Future<void> _toggle(BuildContext context, String id, DateTime day) async {
    final store = StoreScope.read(context);
    final list = Habits.all(store);
    final h = list.where((x) => x.id == id).firstOrNull;
    if (h == null) return;
    final k = isoDay(day);
    final nowDone = !h.days.contains(k);
    nowDone ? h.days.add(k) : h.days.remove(k);
    await Habits.save(store, list);
    // XP e contatore solo per la spunta di oggi, una volta al giorno per abitudine.
    if (nowDone && k == isoDay(DateTime.now())) {
      final xp = await awardActivityXpOnce(store, 'hab:$id', _habitXp);
      if (xp > 0) await store.bump('habitsDone');
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final list = Habits.all(store);
    final today = dateOnly(DateTime.now());
    final week = [for (var i = 6; i >= 0; i--) today.subtract(Duration(days: i))];
    final scheme = Theme.of(context).colorScheme;
    final (done, total) = Habits.today(store);
    return Scaffold(
      appBar: AppBar(title: Text(tr('Abitudini', 'Habits'))),
      floatingActionButton: list.length >= maxHabits
          ? null
          : FloatingActionButton.extended(onPressed: () => _add(context), icon: const Icon(Icons.add_rounded), label: Text(tr('Abitudine', 'Habit'))),
      body: list.isEmpty
          ? EmptyState(
              icon: Icons.check_circle_outline_rounded,
              title: tr('Nessuna abitudine', 'No habits'),
              message: tr('Scegli qualche piccola cosa da fare ogni giorno (dormire, bere, leggere…) e spuntala: la serie di giorni cresce.',
                  'Pick a few small things to do every day (sleep, water, reading…) and tick them: your streak grows.'),
              action: FilledButton.icon(onPressed: () => _add(context), icon: const Icon(Icons.add_rounded), label: Text(tr('Aggiungi', 'Add'))),
            )
          : _page([
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    SizedBox(
                      width: 52,
                      height: 52,
                      child: CircularProgressIndicator(value: total == 0 ? 0 : done / total, strokeWidth: 6, backgroundColor: scheme.surfaceContainerHighest),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                          done == total
                              ? tr('Oggi le hai fatte tutte! 🎉', 'All done today! 🎉')
                              : tr('Oggi: $done su $total', 'Today: $done of $total'),
                          style: Theme.of(context).textTheme.titleMedium),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 8),
              for (final h in list)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Row(children: [
                        Text(h.emoji, style: const TextStyle(fontSize: 24)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(h.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                            Text(
                              tr('🔥 ${h.streak(today)} di fila · record ${h.bestStreak}', '🔥 ${h.streak(today)} in a row · best ${h.bestStreak}'),
                              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                            ),
                          ]),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (v) async {
                            if (v == 'edit') {
                              await _add(context, edit: h);
                            } else {
                              final l = Habits.all(store)..removeWhere((x) => x.id == h.id);
                              await Habits.save(store, l);
                            }
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(value: 'edit', child: Text(tr('Modifica', 'Edit'))),
                            PopupMenuItem(value: 'del', child: Text(tr('Elimina', 'Delete'))),
                          ],
                        ),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        for (final d in week)
                          Expanded(
                            child: Column(children: [
                              Text(_dayLetter(d), style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                              const SizedBox(height: 2),
                              IconButton.filledTonal(
                                visualDensity: VisualDensity.compact,
                                isSelected: h.doneOn(d),
                                selectedIcon: const Icon(Icons.check_rounded),
                                style: IconButton.styleFrom(
                                  backgroundColor: d == today ? scheme.secondaryContainer : scheme.surfaceContainerHighest,
                                ),
                                onPressed: () => _toggle(context, h.id, d),
                                icon: Text('${d.day}', style: const TextStyle(fontSize: 12)),
                              ),
                            ]),
                          ),
                      ]),
                    ]),
                  ),
                ),
            ]),
    );
  }
}

// ---------------------------------------------------------------------------- umore

class MoodPage extends StatelessWidget {
  const MoodPage({super.key});

  Future<void> _set(BuildContext context, {int? mood, int? stress}) async {
    final store = StoreScope.read(context);
    final today = DateTime.now();
    final cur = Mood.all(store)[isoDay(today)];
    await Mood.set(store, today, MoodEntry(mood ?? cur?.mood ?? 3, stress ?? cur?.stress ?? 2));
    if (await awardActivityXpOnce(store, 'mood', _moodXp) > 0) await store.bump('moodDays');
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final moods = Mood.all(store);
    final today = dateOnly(DateTime.now());
    final cur = moods[isoDay(today)];
    final last30 = [for (var i = 29; i >= 0; i--) today.subtract(Duration(days: i))];
    final tests = [for (final a in store.agenda) if (a.kind == 'verifica' || a.kind == 'interrogazione') a.date];
    final testDays = {for (final d in tests) isoDay(d)};
    final cmp = stressNearTests(moods, tests);

    Widget picker(String label, List<String> emojis, int? value, void Function(int v) onPick) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(label, style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              for (var i = 0; i < 5; i++)
                InkWell(
                  borderRadius: BorderRadius.circular(32),
                  onTap: () => onPick(i + 1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: value == i + 1 ? scheme.primaryContainer : Colors.transparent,
                    ),
                    child: Text(emojis[i], style: TextStyle(fontSize: value == i + 1 ? 36 : 30)),
                  ),
                ),
            ]),
          ],
        );

    return Scaffold(
      appBar: AppBar(title: Text(tr('Umore', 'Mood'))),
      body: _page([
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              picker(tr('Come stai oggi?', 'How are you today?'), moodEmojis, cur?.mood, (v) => _set(context, mood: v)),
              const SizedBox(height: 16),
              picker(tr('Quanto sei stressato/a?', 'How stressed are you?'), stressEmojis, cur?.stress, (v) => _set(context, stress: v)),
            ]),
          ),
        ),
        SectionLabel(tr('Ultimi 30 giorni', 'Last 30 days')),
        _MoodChart(days: last30, moods: moods, testDays: testDays),
        const SizedBox(height: 8),
        Wrap(spacing: 12, children: [
          _legend(context, scheme.primary, tr('umore', 'mood')),
          _legend(context, scheme.error, tr('stress', 'stress')),
          Text(tr('📝 = verifica o interrogazione', '📝 = test or oral exam'), style: theme.textTheme.bodySmall),
        ]),
        if (cmp != null) ...[
          SectionLabel(tr('Verifiche e stress', 'Tests and stress')),
          Text(
            cmp.nearTests > cmp.other + 0.4
                ? tr('Nei giorni di verifica (e quello prima) sei più stressato/a: ${cmp.nearTests.toStringAsFixed(1)} contro ${cmp.other.toStringAsFixed(1)}. Prova a ripassare un po\' ogni giorno invece che tutto la sera prima.',
                    'On test days (and the day before) you\'re more stressed: ${cmp.nearTests.toStringAsFixed(1)} vs ${cmp.other.toStringAsFixed(1)}. Try reviewing a bit every day instead of all the night before.')
                : tr('Le verifiche non sembrano stressarti più del solito (${cmp.nearTests.toStringAsFixed(1)} contro ${cmp.other.toStringAsFixed(1)}). Ottimo!',
                    'Tests don\'t seem to stress you more than usual (${cmp.nearTests.toStringAsFixed(1)} vs ${cmp.other.toStringAsFixed(1)}). Great!'),
          ),
        ],
        const SizedBox(height: 16),
        Card(
          color: scheme.surfaceContainerHigh,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Text(
              tr('🔒 Resta solo su questo telefono (e nel backup cifrato). Se ti senti giù per tanti giorni di fila, parlane con qualcuno di cui ti fidi: un amico, un genitore, un prof o lo sportello d\'ascolto della scuola. Telefono Azzurro: 19696.',
                  '🔒 It stays only on this phone (and in the encrypted backup). If you feel down for many days in a row, talk to someone you trust: a friend, a parent, a teacher or the school counsellor. Telefono Azzurro: 19696.'),
              style: theme.textTheme.bodySmall,
            ),
          ),
        ),
      ]),
    );
  }

  Widget _legend(BuildContext context, Color c, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ]);
}

class _MoodChart extends StatelessWidget {
  const _MoodChart({required this.days, required this.moods, required this.testDays});
  final List<DateTime> days;
  final Map<String, MoodEntry> moods;
  final Set<String> testDays;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const h = 90.0;
    return SizedBox(
      height: h + 34,
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (final d in days)
          Expanded(
            child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
              Text(testDays.contains(isoDay(d)) ? '📝' : '', style: const TextStyle(fontSize: 9)),
              SizedBox(
                height: h,
                child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  for (final (v, c) in [(moods[isoDay(d)]?.mood, scheme.primary), (moods[isoDay(d)]?.stress, scheme.error)])
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 0.5),
                        height: v == null ? 2 : h * v / 5,
                        decoration: BoxDecoration(
                          color: v == null ? scheme.surfaceContainerHighest : c.withAlpha(200),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                        ),
                      ),
                    ),
                ]),
              ),
              const SizedBox(height: 2),
              Text(d.day == 1 || d == days.first || d == days.last ? '${d.day}' : '', style: const TextStyle(fontSize: 9)),
            ]),
          ),
      ]),
    );
  }
}

import 'package:flutter/material.dart';

import '../activity_xp.dart';
import '../cloud.dart';
import '../i18n.dart';
import '../live.dart';
import '../social.dart';
import '../store.dart';
import 'class_page.dart' show socialToast;
import 'live_poll.dart';

/// Sfide a quiz 1 contro 1 (3.9): solo tra amici, 5 domande scritte dalla moderazione, uguali per tutti e due.
/// Vince chi ne indovina di più; a pari punti chi è stato più veloce. Una sfida resta aperta 3 giorni.
class QuizPage extends StatefulWidget {
  const QuizPage({super.key});
  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> with LivePoll {
  QuizList? _data;
  List<Friend> _friends = const [];
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
    startLivePoll(const Duration(seconds: 30), chat: 'quiz', relevant: (e) => e.type == 'quiz');
  }

  @override
  Future<void> livePollRefresh() => _load();

  Future<void> _load() async {
    final store = StoreScope.read(context);
    try {
      final d = await Social.quizzes(store);
      final f = await Social.friends(store);
      if (mounted) {
        setState(() {
          _data = d;
          _friends = f.friends;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _challenge() async {
    final d = _data;
    if (d == null) return;
    if (_friends.isEmpty) {
      socialToast(context, tr('Prima aggiungi un amico (Amici e classifica)', 'Add a friend first (Friends and leaderboard)'));
      return;
    }
    final friend = await showModalBottomSheet<Friend>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(c).height * 0.7),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(tr('Chi sfidi?', 'Who do you challenge?'), style: Theme.of(c).textTheme.titleMedium),
            Flexible(
              child: ListView(shrinkWrap: true, children: [
                for (final f in _friends)
                  ListTile(
                    leading: Text(f.avatar, style: const TextStyle(fontSize: 26)),
                    title: Text(f.nickname),
                    subtitle: Text(tr('Livello ${f.level}', 'Level ${f.level}')),
                    onTap: () => Navigator.pop(c, f),
                  ),
              ]),
            ),
          ]),
        ),
      ),
    );
    if (friend == null || !mounted) return;
    final subject = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(c).height * 0.7),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(tr('Su cosa?', 'On what?'), style: Theme.of(c).textTheme.titleMedium),
            Flexible(
              child: ListView(shrinkWrap: true, children: [
                ListTile(leading: const Text('🎲', style: TextStyle(fontSize: 22)), title: Text(tr('Un po\' di tutto', 'A bit of everything')), onTap: () => Navigator.pop(c, '')),
                for (var i = 0; i < d.subjects.length; i++)
                  ListTile(
                    title: Text(d.subjectLabels.length == d.subjects.length ? d.subjectLabels[i] : d.subjects[i]),
                    onTap: () => Navigator.pop(c, d.subjects[i]),
                  ),
              ]),
            ),
          ]),
        ),
      ),
    );
    if (subject == null || !mounted) return;
    final store = StoreScope.read(context);
    try {
      final id = await Social.newQuiz(store, friend.code, subject: subject);
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => QuizPlayPage(id: id, opponent: friend.nickname)));
      await _load();
    } catch (e) {
      if (mounted) socialToast(context, e);
    }
  }

  Future<void> _open(QuizMatch m) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => QuizPlayPage(id: m.id, opponent: m.opponent.nickname)));
    await _load();
  }

  Future<void> _decline(QuizMatch m) async {
    try {
      await Social.declineQuiz(StoreScope.read(context), m.id);
      await _load();
    } catch (e) {
      if (mounted) socialToast(context, e);
    }
  }

  Widget _tile(QuizMatch m) {
    final scheme = Theme.of(context).colorScheme;
    final o = m.opponent;
    final what = m.subject.isEmpty ? tr('un po\' di tutto', 'a bit of everything') : m.subject;
    String sub;
    Widget? trailing;
    switch (m.status) {
      case 'done':
        final out = m.outcome;
        sub = tr('${m.myScore ?? 0} a ${m.theirScore ?? 0} · $what', '${m.myScore ?? 0} to ${m.theirScore ?? 0} · $what');
        trailing = Text(out == 1 ? '🏆' : out == -1 ? '😅' : '🤝', style: const TextStyle(fontSize: 24));
      case 'declined':
        sub = m.challenger ? tr('Ha detto di no · $what', 'Said no · $what') : tr('Hai detto di no · $what', 'You said no · $what');
      case 'expired':
        sub = tr('Scaduta · $what', 'Expired · $what');
      default:
        if (m.myTurn) {
          sub = m.challenger ? tr('Gioca la tua parte · $what', 'Play your part · $what') : tr('Ti ha sfidato! · $what', 'Challenged you! · $what');
          trailing = Row(mainAxisSize: MainAxisSize.min, children: [
            if (!m.challenger)
              IconButton(tooltip: tr('No grazie', 'No thanks'), icon: const Icon(Icons.close_rounded), onPressed: () => _decline(m)),
            FilledButton(onPressed: () => _open(m), child: Text(tr('Gioca', 'Play'))),
          ]);
        } else {
          sub = tr('Hai fatto ${m.myScore ?? 0}/${m.total} · tocca a ${o.nickname}', 'You got ${m.myScore ?? 0}/${m.total} · ${o.nickname}\'s turn');
          trailing = Icon(Icons.hourglass_top_rounded, color: scheme.onSurfaceVariant);
        }
    }
    return Card(
      child: ListTile(
        leading: Text(o.avatar, style: const TextStyle(fontSize: 28)),
        title: Text(o.nickname),
        subtitle: Text(sub),
        trailing: trailing,
        onTap: m.status == 'declined' || m.status == 'expired' ? null : () => _open(m),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    Widget body;
    if (d == null) {
      body = Center(
        child: _error == null
            ? const CircularProgressIndicator()
            : Padding(padding: const EdgeInsets.all(24), child: Text(_error is CloudException ? (_error as CloudException).message : '$_error')),
      );
    } else {
      final mine = d.matches.where((m) => m.myTurn).toList();
      final waiting = d.matches.where((m) => m.open && m.played).toList();
      final over = d.matches.where((m) => !m.open).toList();
      final wins = over.where((m) => m.outcome == 1).length;
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            Text(
              tr('5 domande, le stesse per tutti e due. Vince chi ne indovina di più; a pari punti chi è più veloce.',
                  '5 questions, the same for both of you. Most right answers wins; on a tie, the faster one.'),
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            if (over.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(tr('Vittorie: $wins su ${over.where((m) => m.status == 'done').length}', 'Wins: $wins of ${over.where((m) => m.status == 'done').length}'),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
            if (d.matches.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Text(tr('Nessuna sfida ancora. Sfida un amico! ⚔️', 'No challenges yet. Challenge a friend! ⚔️'), textAlign: TextAlign.center),
              ),
            if (mine.isNotEmpty) ...[const SizedBox(height: 12), Text(tr('Tocca a te', 'Your turn'), style: Theme.of(context).textTheme.titleSmall), for (final m in mine) _tile(m)],
            if (waiting.isNotEmpty) ...[const SizedBox(height: 12), Text(tr('In attesa', 'Waiting'), style: Theme.of(context).textTheme.titleSmall), for (final m in waiting) _tile(m)],
            if (over.isNotEmpty) ...[const SizedBox(height: 12), Text(tr('Finite', 'Finished'), style: Theme.of(context).textTheme.titleSmall), for (final m in over) _tile(m)],
          ],
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(tr('Sfide a quiz', 'Quiz challenges'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: d == null || Live.instance.paused ? null : _challenge,
        icon: const Icon(Icons.bolt_rounded),
        label: Text(tr('Sfida un amico', 'Challenge a friend')),
      ),
      body: body,
    );
  }
}

/// XP per una partita: 5 per aver giocato + 2 per ogni risposta giusta.
int quizXp(int score) => 5 + 2 * score;

/// Una partita: si gioca (se tocca a me) oppure si vedono le risposte.
class QuizPlayPage extends StatefulWidget {
  const QuizPlayPage({super.key, required this.id, required this.opponent});
  final String id;
  final String opponent;
  @override
  State<QuizPlayPage> createState() => _QuizPlayPageState();
}

class _QuizPlayPageState extends State<QuizPlayPage> {
  QuizGame? _game;
  Object? _error;
  final List<int> _answers = [];
  final Stopwatch _clock = Stopwatch();
  bool _sending = false;
  bool _started = false;
  List<int>? _correct;
  int? _score;

  bool get _playing => _game != null && !_game!.played && _game!.status == 'open' && _correct == null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final g = await Social.quiz(StoreScope.read(context), widget.id);
      if (!mounted) return;
      setState(() {
        _game = g;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  /// Le domande arrivano adesso: il server conta il tempo da qui.
  Future<void> _start() async {
    setState(() => _sending = true);
    try {
      final g = await Social.startQuiz(StoreScope.read(context), widget.id);
      if (!mounted) return;
      setState(() {
        _game = g;
        _started = true;
        _clock.start();
      });
    } catch (e) {
      if (mounted) socialToast(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pick(int i) async {
    final g = _game;
    if (g == null || _sending) return;
    setState(() => _answers.add(i));
    if (_answers.length >= g.questions.length) await _submit();
  }

  Future<void> _submit() async {
    final g = _game;
    if (g == null || _sending) return;
    _clock.stop();
    setState(() => _sending = true);
    final store = StoreScope.read(context);
    final answers = [for (var i = 0; i < g.questions.length; i++) i < _answers.length ? _answers[i] : -1];
    try {
      final (score, correct, _) = await Social.answerQuiz(store, g.id, answers, _clock.elapsedMilliseconds);
      await awardActivityXpOnce(store, 'quiz:${g.id}', quizXp(score));
      await store.bump('quizPlayed');
      if (!mounted) return;
      setState(() {
        _score = score;
        _correct = correct;
        _answers
          ..clear()
          ..addAll(answers);
      });
      await _load();
    } catch (e) {
      if (mounted) socialToast(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Uscire a metà: le domande senza risposta valgono 0 (sennò si potrebbero cercare le risposte e rigiocare).
  Future<void> _leave() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('Esci dalla sfida?', 'Leave the challenge?')),
        content: Text(tr('Le domande a cui non hai risposto valgono 0 punti.', 'Questions you haven\'t answered count as 0 points.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('Continua', 'Keep playing'))),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(tr('Esci', 'Leave'))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _submit();
    if (mounted) Navigator.of(context).pop();
  }

  Widget _play(QuizGame g) {
    final theme = Theme.of(context);
    final n = _answers.length.clamp(0, g.questions.length - 1);
    final q = g.questions[n];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        LinearProgressIndicator(value: (n + 1) / g.questions.length),
        const SizedBox(height: 8),
        Text(tr('Domanda ${n + 1} di ${g.questions.length}', 'Question ${n + 1} of ${g.questions.length}'),
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
        if (q.subject.isNotEmpty) Text(q.subject, style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Text(q.question, style: theme.textTheme.titleLarge),
        const SizedBox(height: 16),
        for (var i = 0; i < q.options.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(16), alignment: Alignment.centerLeft),
              onPressed: _sending ? null : () => _pick(i),
              child: Text('${'ABCD'[i]}.  ${q.options[i]}', style: const TextStyle(fontSize: 16)),
            ),
          ),
      ],
    );
  }

  Widget _results(QuizGame g) {
    final scheme = Theme.of(context).colorScheme;
    final mine = g.mine ?? _answers;
    final theirs = g.theirs;
    final score = _score ?? [for (var i = 0; i < g.questions.length; i++) if (i < mine.length && mine[i] == g.questions[i].correct) 1].length;
    final their = theirs == null ? null : [for (var i = 0; i < g.questions.length; i++) if (i < theirs.length && theirs[i] == g.questions[i].correct) 1].length;
    String head;
    if (their == null) {
      head = g.status == 'open'
          ? tr('Hai fatto $score su ${g.questions.length}. Ora tocca a ${widget.opponent}!', 'You got $score of ${g.questions.length}. Now it\'s ${widget.opponent}\'s turn!')
          : tr('Hai fatto $score su ${g.questions.length}', 'You got $score of ${g.questions.length}');
    } else {
      head = score > their
          ? tr('Hai vinto $score a $their! 🏆', 'You won $score to $their! 🏆')
          : score < their
              ? tr('Ha vinto ${widget.opponent}, $their a $score', '${widget.opponent} won, $their to $score')
              : tr('Pari, $score a $score: conta chi è stato più veloce', 'Tie, $score to $score: the faster one wins');
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text(head, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        for (var i = 0; i < g.questions.length; i++)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${i + 1}. ${g.questions[i].question}', style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                for (var o = 0; o < g.questions[i].options.length; o++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(children: [
                      Icon(
                        o == g.questions[i].correct
                            ? Icons.check_circle_rounded
                            : (i < mine.length && mine[i] == o)
                                ? Icons.cancel_rounded
                                : Icons.circle_outlined,
                        size: 18,
                        color: o == g.questions[i].correct
                            ? Colors.green
                            : (i < mine.length && mine[i] == o)
                                ? scheme.error
                                : scheme.outlineVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(g.questions[i].options[o])),
                      if (i < mine.length && mine[i] == o) Text(tr(' tu', ' you'), style: TextStyle(fontSize: 12, color: scheme.primary)),
                      if (theirs != null && i < theirs.length && theirs[i] == o)
                        Text(' ${widget.opponent}', style: TextStyle(fontSize: 12, color: scheme.tertiary)),
                    ]),
                  ),
              ]),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final g = _game;
    Widget body;
    if (g == null) {
      body = Center(
        child: _error == null
            ? const CircularProgressIndicator()
            : Padding(padding: const EdgeInsets.all(24), child: Text(_error is CloudException ? (_error as CloudException).message : '$_error')),
      );
    } else if (g.questions.isEmpty) {
      body = Center(child: Text(tr('Questa sfida non ha più domande', 'This challenge has no questions anymore')));
    } else if (_playing && !_started) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('⚔️', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 12),
            Text(tr('${g.questions.length} domande contro ${widget.opponent}', '${g.questions.length} questions against ${widget.opponent}'),
                style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(tr('Il tempo parte appena inizi. Se esci a metà, le domande senza risposta valgono 0.', 'The clock starts as soon as you begin. If you leave halfway, unanswered questions count as 0.'),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            if (g.started) ...[
              Text(tr('Avevi già iniziato questa sfida: il tempo sta correndo.', 'You had already started this challenge: the clock is running.'),
                  textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              const SizedBox(height: 12),
            ],
            FilledButton.icon(
              onPressed: _sending ? null : _start,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(g.started ? tr('Continua', 'Continue') : tr('Inizia', 'Start')),
            ),
          ]),
        ),
      );
    } else if (_playing) {
      body = _play(g);
    } else if (g.status == 'open' && !g.played) {
      body = Center(child: Text(tr('Questa sfida è chiusa', 'This challenge is closed')));
    } else {
      body = _results(g);
    }
    return PopScope(
      canPop: !_playing || !_started,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(tr('Sfida con ${widget.opponent}', 'Challenge with ${widget.opponent}'))),
        body: body,
      ),
    );
  }
}

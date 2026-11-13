import 'dart:async';

import 'package:flutter/material.dart';

import '../cloud.dart';
import '../live.dart';
import '../social.dart';
import '../store.dart';
import 'achievements.dart' show levelOf;
import 'class_page.dart';
import 'quiz_page.dart';
import 'school_life_pages.dart' show StudyTimerPage;
import '../i18n.dart';

/// Amici (con codice amico, niente ricerca per nome) e classifica XP della settimana.
class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});
  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  FriendsData? _data;
  SocialProfile? _me;
  Object? _error;

  StreamSubscription<LiveEvent>? _live;

  @override
  void initState() {
    super.initState();
    _load();
    // Richieste e amicizie nuove arrivano da sole (canale in diretta).
    _live = Live.instance.events.where((e) => e.type == 'friends').listen((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _live?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final store = StoreScope.read(context);
    try {
      final lv = levelOf(store);
      await Social.sync(store, xp: lv.xp, level: lv.level, force: true);
      final me = await Social.me(store);
      final d = await Social.friends(store);
      if (d.leaderboard.length > 1 && d.leaderboard.first.me && d.leaderboard.first.weekXp > 0) {
        await store.setOpt('egg.weekTop', true);
      }
      if (mounted) {
        setState(() {
          _me = me;
          _data = d;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _do(Future<void> Function() f, [String? done]) async {
    try {
      await f();
      if (done != null && mounted) socialToast(context, done);
      await _load();
    } catch (e) {
      if (mounted) socialToast(context, e);
    }
  }

  Future<void> _add() async {
    final store = StoreScope.read(context);
    final code = await askSocialCode(context, title: tr('Aggiungi un amico', 'Add a friend'), kind: 'friend');
    if (code == null || code.isEmpty) return;
    String? status;
    await _do(() async => status = await Social.addFriend(store, code));
    if (status != null && mounted) {
      socialToast(context, status == 'friends' ? tr('Siete amici!', 'You\'re friends!') : tr('Richiesta mandata: deve accettarla', 'Request sent: they need to accept it'));
      if (status == 'friends') await store.bump('friendsAdded');
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.read(context);
    final scheme = Theme.of(context).colorScheme;
    final d = _data;
    final me = _me;
    Widget body;
    if (d == null) {
      body = Center(
        child: _error == null
            ? const CircularProgressIndicator()
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error is CloudException ? (_error as CloudException).message : '$_error'),
              ),
      );
    } else {
      const medals = ['🥇', '🥈', '🥉'];
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            if (me != null)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.qr_code_2_rounded),
                  title: Text(tr('Il tuo codice amico: ${me.friendCode}', 'Your friend code: ${me.friendCode}')),
                  subtitle: Text(tr('Dallo solo a chi conosci davvero', 'Only give it to people you really know')),
                  onTap: () => showShareCode(context,
                      title: tr('Il tuo codice amico', 'Your friend code'), code: me.friendCode, link: friendLink(me.friendCode), hint: tr('Inquadra con Easy Lesson', 'Scan with Easy Lesson')),
                ),
              ),
            if (d.friends.isNotEmpty) ...[
              ListenableBuilder(
                listenable: Live.instance,
                builder: (context, _) {
                  final n = Live.instance.unreadOf('quiz');
                  return Card(
                    child: ListTile(
                      leading: const Text('⚔️', style: TextStyle(fontSize: 26)),
                      title: Text(tr('Sfide a quiz', 'Quiz challenges')),
                      subtitle: Text(tr('5 domande contro un amico', '5 questions against a friend')),
                      trailing: n > 0 ? Badge(label: Text('$n')) : const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const QuizPage())),
                    ),
                  );
                },
              ),
              Card(
                child: ListTile(
                  leading: const Text('📚', style: TextStyle(fontSize: 26)),
                  title: Text(tr('Studia con gli amici', 'Study with friends')),
                  subtitle: Text(tr('Timer per studiare: vedi chi sta studiando adesso', 'Study timer: see who\'s studying right now')),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const StudyTimerPage())),
                ),
              ),
            ],
            if (d.incoming.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(tr('Richieste di amicizia', 'Friend requests'), style: Theme.of(context).textTheme.titleSmall),
              for (final f in d.incoming)
                ListTile(
                  leading: Text(f.avatar, style: const TextStyle(fontSize: 28)),
                  title: Text(f.nickname),
                  subtitle: Text(tr('Livello ${f.level}', 'Level ${f.level}')),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      tooltip: tr('Rifiuta', 'Decline'),
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => _do(() => Social.answerFriend(store, f.code, false)),
                    ),
                    IconButton.filled(
                      tooltip: tr('Accetta', 'Accept'),
                      icon: const Icon(Icons.check_rounded),
                      onPressed: () => _do(() async {
                        await Social.answerFriend(store, f.code, true);
                        await store.bump('friendsAdded');
                      }, tr('Siete amici!', 'You\'re friends!')),
                    ),
                  ]),
                ),
            ],
            const SizedBox(height: 12),
            Text(tr('Classifica della settimana', 'This week\'s leaderboard'), style: Theme.of(context).textTheme.titleMedium),
            Text(tr('XP guadagnate da lunedì. Si riparte ogni settimana.', 'XP earned since Monday. Starts over every week.'), style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            for (final f in d.leaderboard)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 2),
                decoration: BoxDecoration(
                  color: f.me ? scheme.primaryContainer : null,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ListTile(
                  leading: SizedBox(
                    width: 64,
                    child: Row(children: [
                      SizedBox(
                        width: 28,
                        child: Text(f.rank <= 3 ? medals[f.rank - 1] : '${f.rank}',
                            textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 4),
                      Text(f.avatar, style: const TextStyle(fontSize: 26)),
                    ]),
                  ),
                  title: Text(f.me ? '${f.nickname} (tu)' : f.nickname),
                  subtitle: Text(tr('Livello ${f.level}', 'Level ${f.level}')),
                  trailing: Text('${f.weekXp} XP', style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            if (d.friends.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(tr('Ancora nessun amico: fatti dare il codice amico (o il QR) da un compagno.', 'No friends yet: ask a classmate for their friend code (or QR).')),
              ),
            if (d.friends.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(tr('Amici (${d.friends.length})', 'Friends (${d.friends.length})'), style: Theme.of(context).textTheme.titleSmall),
              for (final f in d.friends)
                ListTile(
                  leading: Text(f.avatar, style: const TextStyle(fontSize: 26)),
                  title: Text(f.nickname),
                  subtitle: Text(tr('Livello ${f.level}', 'Level ${f.level}')),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'remove') _do(() => Social.removeFriend(store, f.code), tr('Tolto dagli amici', 'Removed from friends'));
                      if (v == 'report') _do(() => Social.report(store, kind: 'nickname', target: f.code), tr('Segnalato, grazie', 'Reported, thanks'));
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'remove', child: Text(tr('Togli dagli amici', 'Remove from friends'))),
                      PopupMenuItem(value: 'report', child: Text(tr('Segnala il soprannome', 'Report the nickname'))),
                    ],
                  ),
                ),
            ],
            if (d.outgoing.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(tr('In attesa', 'Pending'), style: Theme.of(context).textTheme.titleSmall),
              for (final f in d.outgoing)
                ListTile(
                  leading: Text(f.avatar, style: const TextStyle(fontSize: 26)),
                  title: Text(f.nickname),
                  subtitle: Text(tr('Deve ancora accettare', 'Hasn\'t accepted yet')),
                  trailing: IconButton(
                    tooltip: tr('Annulla', 'Cancel'),
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => _do(() => Social.removeFriend(store, f.code)),
                  ),
                ),
            ],
          ],
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(tr('Amici e classifica', 'Friends and leaderboard'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.person_add_alt_rounded),
        label: Text(tr('Aggiungi', 'Add')),
      ),
      body: body,
    );
  }
}

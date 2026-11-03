import 'package:flutter/material.dart';

import '../cloud.dart';
import '../social.dart';
import '../store.dart';
import 'achievements.dart' show levelOf;
import 'class_page.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
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
    final code = await askSocialCode(context, title: 'Aggiungi un amico', kind: 'friend');
    if (code == null || code.isEmpty) return;
    String? status;
    await _do(() async => status = await Social.addFriend(store, code));
    if (status != null && mounted) {
      socialToast(context, status == 'friends' ? 'Siete amici!' : 'Richiesta mandata: deve accettarla');
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
                  title: Text('Il tuo codice amico: ${me.friendCode}'),
                  subtitle: const Text('Dallo solo a chi conosci davvero'),
                  onTap: () => showShareCode(context,
                      title: 'Il tuo codice amico', code: me.friendCode, link: friendLink(me.friendCode), hint: 'Inquadra con Easy Lesson'),
                ),
              ),
            if (d.incoming.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Richieste di amicizia', style: Theme.of(context).textTheme.titleSmall),
              for (final f in d.incoming)
                ListTile(
                  leading: Text(f.avatar, style: const TextStyle(fontSize: 28)),
                  title: Text(f.nickname),
                  subtitle: Text('Livello ${f.level}'),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      tooltip: 'Rifiuta',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => _do(() => Social.answerFriend(store, f.code, false)),
                    ),
                    IconButton.filled(
                      tooltip: 'Accetta',
                      icon: const Icon(Icons.check_rounded),
                      onPressed: () => _do(() async {
                        await Social.answerFriend(store, f.code, true);
                        await store.bump('friendsAdded');
                      }, 'Siete amici!'),
                    ),
                  ]),
                ),
            ],
            const SizedBox(height: 12),
            Text('Classifica della settimana', style: Theme.of(context).textTheme.titleMedium),
            Text('XP guadagnate da lunedì. Si riparte ogni settimana.', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
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
                  subtitle: Text('Livello ${f.level}'),
                  trailing: Text('${f.weekXp} XP', style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            if (d.friends.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('Ancora nessun amico: fatti dare il codice amico (o il QR) da un compagno.'),
              ),
            if (d.friends.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Amici (${d.friends.length})', style: Theme.of(context).textTheme.titleSmall),
              for (final f in d.friends)
                ListTile(
                  leading: Text(f.avatar, style: const TextStyle(fontSize: 26)),
                  title: Text(f.nickname),
                  subtitle: Text('Livello ${f.level}'),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'remove') _do(() => Social.removeFriend(store, f.code), 'Tolto dagli amici');
                      if (v == 'report') _do(() => Social.report(store, kind: 'nickname', target: f.code), 'Segnalato, grazie');
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'remove', child: Text('Togli dagli amici')),
                      PopupMenuItem(value: 'report', child: Text('Segnala il soprannome')),
                    ],
                  ),
                ),
            ],
            if (d.outgoing.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('In attesa', style: Theme.of(context).textTheme.titleSmall),
              for (final f in d.outgoing)
                ListTile(
                  leading: Text(f.avatar, style: const TextStyle(fontSize: 26)),
                  title: Text(f.nickname),
                  subtitle: const Text('Deve ancora accettare'),
                  trailing: IconButton(
                    tooltip: 'Annulla',
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
      appBar: AppBar(title: const Text('Amici e classifica')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.person_add_alt_rounded),
        label: const Text('Aggiungi'),
      ),
      body: body,
    );
  }
}

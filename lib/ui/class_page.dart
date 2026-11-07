import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../cloud.dart';
import '../live.dart';
import '../shop.dart';
import '../social.dart';
import '../store.dart';
import 'achievements.dart' show levelOf;
import 'adult_chat.dart';
import 'adult_dm.dart' show DmEntryTile;
import 'class_chat.dart';
import 'code_scanner.dart';
import 'friends_page.dart';
import 'notices.dart';
import 'profile_page.dart';
import '../i18n.dart';

/// Classe e amici (3.0): profilo con soprannome, le mie classi, amici e classifica.
/// Niente chat: solo compiti e verifiche, conferme e sfide. Si vede solo il soprannome.
Future<void> openClassHub(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ClassHubPage()));

void socialToast(BuildContext context, Object e) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(e is CloudException ? e.message : '$e')));
}

/// Mostra un codice (classe o amico) con QR, copia e condividi.
Future<void> showShareCode(BuildContext context, {required String title, required String code, required String link, String? hint}) =>
    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(10),
              child: QrImageView(data: link, size: 200, backgroundColor: Colors.white),
            ),
            const SizedBox(height: 12),
            SelectableText(code, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: 3)),
            if (hint != null) ...[const SizedBox(height: 8), Text(hint, textAlign: TextAlign.center)],
          ],
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: Text(tr('Copia', 'Copy')),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              Navigator.pop(c);
              socialToast(context, tr('Copiato', 'Copied'));
            },
          ),
          FilledButton(onPressed: () => Navigator.pop(c), child: Text(tr('Fatto', 'Done'))),
        ],
      ),
    );

/// Chiede un codice (classe o amico): scritto, incollato o con la fotocamera.
Future<String?> askSocialCode(BuildContext context, {required String title, required String kind}) async {
  final ctrl = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        textCapitalization: TextCapitalization.characters,
        decoration: InputDecoration(
          hintText: tr('Es. K7PQ2MXA', 'E.g. K7PQ2MXA'),
          suffixIcon: IconButton(
            tooltip: tr('Scansiona il QR', 'Scan the QR'),
            icon: const Icon(Icons.qr_code_scanner_rounded),
            onPressed: () async {
              final v = await scanQr(c, title: title);
              if (v == null) return;
              final (k, value) = parseCodeText(v);
              ctrl.text = k == kind || k == 'raw' ? value : '';
            },
          ),
        ),
        onSubmitted: (v) => Navigator.pop(c, v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: Text(tr('Annulla', 'Cancel'))),
        FilledButton(onPressed: () => Navigator.pop(c, ctrl.text), child: const Text('OK')),
      ],
    ),
  ).then((v) => v?.trim().toUpperCase().replaceAll(RegExp(r'[\s-]'), ''));
}

/// Soprannome + emoji. Restituisce il profilo salvato (null = annullato).
Future<SocialProfile?> editSocialProfile(BuildContext context, {SocialProfile? current}) async {
  final store = StoreScope.read(context);
  final ctrl = TextEditingController(text: current?.nickname ?? '');
  var avatar = current?.avatar ?? socialAvatars[3];
  String? error;
  var busy = false;
  return showDialog<SocialProfile>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setState) => AlertDialog(
        title: Text(current == null ? tr('Il tuo soprannome', 'Your nickname') : tr('Modifica profilo', 'Edit profile')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('Compagni e amici vedranno solo questo, mai il tuo nome vero. '
                'Niente parolacce: i soprannomi offensivi vengono nascosti.', 'Classmates and friends will only see this, never your real name. No swear words: offensive nicknames get hidden.'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                maxLength: 20,
                decoration: InputDecoration(labelText: tr('Soprannome', 'Nickname'), errorText: error),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final a in [...socialAvatars, ...Shop.ownedAvatars(store)])
                    ChoiceChip(
                      label: Text(a, style: const TextStyle(fontSize: 20)),
                      selected: a == avatar,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => avatar = a),
                    ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(tr('Annulla', 'Cancel'))),
          FilledButton(
            onPressed: busy
                ? null
                : () async {
                    setState(() {
                      busy = true;
                      error = null;
                    });
                    try {
                      final p = await Social.saveProfile(store, ctrl.text.trim(), avatar);
                      if (c.mounted) Navigator.pop(c, p);
                    } on CloudException catch (e) {
                      setState(() {
                        busy = false;
                        error = e.message;
                      });
                    }
                  },
            child: Text(tr('Salva', 'Save')),
          ),
        ],
      ),
    ),
  );
}

class ClassHubPage extends StatefulWidget {
  const ClassHubPage({super.key, this.asTab = false});

  /// 3.6: scheda "Amici" della barra in basso (niente freccia indietro).
  final bool asTab;
  @override
  State<ClassHubPage> createState() => _ClassHubPageState();
}

class _ClassHubPageState extends State<ClassHubPage> {
  SocialProfile? _me;
  List<ClassSummary>? _classes;
  Object? _error;
  bool _loading = true;

  /// 3.8: ultimo messaggio di ogni classe, classifica e richieste (si caricano dopo, senza bloccare la pagina).
  final Map<String, String> _lastMessage = {};
  FriendsData? _friends;

  /// Per quale account si è caricato (se si entra o si esce dall'account, si ricarica).
  String? _loadedFor;

  StreamSubscription<LiveEvent>? _live;

  @override
  void initState() {
    super.initState();
    _load();
    // Avvisi, amicizie, 18+ dato o tolto: la pagina si aggiorna da sola (canale in diretta).
    _live = Live.instance.events.where((e) => const {'notice', 'friends', 'me', 'chat'}.contains(e.type)).listen((e) {
      if (!mounted) return;
      if (e.type == 'chat') {
        _loadExtras(onlyClass: e.classId);
      } else {
        _load();
      }
    });
  }

  @override
  void dispose() {
    _live?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final store = StoreScope.read(context);
    _loadedFor = store.accountCode;
    if (store.accountCode == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final me = await Social.me(store);
      final classes = me == null ? <ClassSummary>[] : await Social.classes(store);
      if (!mounted) return;
      setState(() {
        _me = me;
        _classes = classes;
        _loading = false;
      });
      final lv = levelOf(store);
      if (me != null) Social.sync(store, xp: lv.xp, level: lv.level, force: true);
      if (me != null) _loadExtras();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  /// Ultimo messaggio delle classi e classifica degli amici. Gli errori si ignorano (la pagina c'è comunque).
  Future<void> _loadExtras({String? onlyClass}) async {
    final store = StoreScope.read(context);
    final classes = (_classes ?? const <ClassSummary>[]).where((c) => onlyClass == null || c.id == onlyClass).toList();
    await Future.wait([
      for (final c in classes)
        Social.chat(store, c.id).then((d) {
          if (!mounted) return;
          final last = d.messages.isEmpty ? null : d.messages.last;
          setState(() {
            if (last == null) {
              _lastMessage.remove(c.id);
            } else {
              _lastMessage[c.id] = '${last.byMe ? 'Tu' : last.author}: ${last.text}';
            }
          });
        }).catchError((_) {}),
      if (onlyClass == null)
        Social.friends(store).then((f) {
          if (mounted) setState(() => _friends = f);
        }).catchError((_) {}),
    ]);
  }

  Future<void> _create() async {
    final store = StoreScope.read(context);
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('Nuova classe', 'New class')),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 30,
          decoration: InputDecoration(labelText: tr('Nome', 'Name'), hintText: tr('Es. 1A IT', 'E.g. 1A IT')),
          onSubmitted: (v) => Navigator.pop(c, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(tr('Annulla', 'Cancel'))),
          FilledButton(onPressed: () => Navigator.pop(c, ctrl.text), child: Text(tr('Crea', 'Create'))),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty) return;
    try {
      final cl = await Social.createClass(store, name.trim());
      await store.bump('classesJoined');
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      await showShareCode(context,
          title: tr('Invita i compagni', 'Invite classmates'), code: cl.joinCode, link: classLink(cl.joinCode), hint: tr('Fagli inquadrare il QR o dagli il codice.', 'Let them scan the QR or give them the code.'));
    } catch (e) {
      if (mounted) socialToast(context, e);
    }
  }

  Future<void> _join([String? preset]) async {
    final store = StoreScope.read(context);
    final code = preset ?? await askSocialCode(context, title: tr('Entra in una classe', 'Join a class'), kind: 'class');
    if (code == null || code.isEmpty) return;
    try {
      final id = await Social.joinClass(store, code);
      await store.bump('classesJoined');
      await _load();
      if (mounted && id.isNotEmpty) _open(id);
    } catch (e) {
      if (mounted) socialToast(context, e);
    }
  }

  Future<void> _deleteProfile() async {
    final store = StoreScope.read(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('Cancellare il profilo?', 'Delete the profile?')),
        content: Text(
          tr('Spariscono soprannome, amici e classifica, ed esci da tutte le classi. '
          'I compiti che hai condiviso restano alla classe senza il tuo nome. Il tuo account e i progressi restano.', 'Your nickname, friends and leaderboard disappear, and you leave all classes. The homework you shared stays with the class without your name. Your account and progress stay.'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('No', 'No'))),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(tr('Cancella', 'Delete'))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Social.deleteProfile(store);
      await store.setOpt('social.classes', null);
      if (mounted) {
        setState(() {
          _me = null;
          _classes = null;
        });
      }
    } catch (e) {
      if (mounted) socialToast(context, e);
    }
  }

  void _open(String id) => Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => ClassPage(classId: id)))
      .then((_) => _load());

  Future<void> _openNotices() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const NoticesPage()));
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    if (store.accountCode != _loadedFor && !_loading) WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    Widget body;
    if (store.accountCode == null) {
      body = ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('👥', textAlign: TextAlign.center, style: TextStyle(fontSize: 56)),
          const SizedBox(height: 12),
          Text(tr('Classe e amici', 'Class and friends'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          // 3.8 "minimal": una frase e un pulsante; tutto il resto nella pagina dell'account.
          Text(
            tr('Chat, agenda condivisa e sfide con la classe. Serve l\'account Easy Lesson: anonimo, niente email.', 'Chat, shared planner and challenges with the class. You need the Easy Lesson account: anonymous, no email.'),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Center(
            child: FilledButton.icon(
              onPressed: () => openAccountPage(context),
              icon: const Icon(Icons.key_rounded),
              label: Text(tr('Crea o usa il tuo codice', 'Create or use your code')),
            ),
          ),
        ],
      );
    } else if (_loading && _me == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      body = ListView(padding: const EdgeInsets.all(24), children: [
        Text(_error is CloudException ? (_error as CloudException).message : '$_error', style: TextStyle(color: scheme.error)),
        const SizedBox(height: 12),
        FilledButton(onPressed: _load, child: Text(tr('Riprova', 'Try again'))),
      ]);
    } else if (_me == null) {
      body = ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('🦊', textAlign: TextAlign.center, style: TextStyle(fontSize: 56)),
          const SizedBox(height: 12),
          Text(
            tr('Scegli un soprannome e un\'emoji: è tutto quello che vedranno compagni e amici.', 'Choose a nickname and an emoji: it\'s all classmates and friends will see.'),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            icon: const Icon(Icons.badge_outlined),
            label: Text(tr('Scegli il soprannome', 'Choose a nickname')),
            onPressed: () async {
              final p = await editSocialProfile(context);
              if (p != null) await _load();
            },
          ),
        ],
      );
    } else {
      final me = _me!;
      // 3.6: un avviso della moderazione va letto per forza. Finché non lo leggi la parte social è grigia
      // e si apre solo la conversazione con la moderazione. Il resto dell'app funziona.
      final locked = me.unreadNotices > 0;
      Widget section(String t) => Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 4),
            child: Text(t, style: Theme.of(context).textTheme.titleMedium),
          );
      final social = <Widget>[
        Card(
          child: ListTile(
            leading: Text(me.avatar, style: const TextStyle(fontSize: 34)),
            title: Text(me.nickname, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(me.hiddenByModeration
                ? tr('Soprannome nascosto dalla moderazione: cambialo', 'Nickname hidden by moderation: change it')
                : tr('Codice amico ${me.friendCode} · ${me.weekXp} XP questa settimana', 'Friend code ${me.friendCode} · ${me.weekXp} XP this week')),
            trailing: IconButton(
              tooltip: tr('Modifica', 'Edit'),
              icon: const Icon(Icons.edit_outlined),
              onPressed: () async {
                final p = await editSocialProfile(context, current: me);
                if (p != null) await _load();
              },
            ),
          ),
        ),
        if (me.suspension != null)
          Card(
            color: scheme.errorContainer,
            child: ListTile(
              leading: Icon(Icons.block_rounded, color: scheme.onErrorContainer),
              title: Text(me.suspension!, style: TextStyle(color: scheme.onErrorContainer)),
              subtitle: Text(tr('Puoi guardare, ma non scrivere.', 'You can look, but not write.'), style: TextStyle(color: scheme.onErrorContainer)),
            ),
          ),
        section(tr('La tua classe', 'Your class')),
        if ((_classes ?? const []).isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(tr('Non sei ancora in nessuna classe. Entra con il codice di un compagno o creane una: '
                'chat rapida, agenda condivisa e sfida della settimana.', 'You\'re not in any class yet. Join with a classmate\'s code or create one: quick chat, shared planner and the weekly challenge.')),
          ),
        for (final c in _classes ?? const <ClassSummary>[])
          Card(
            child: ListTile(
              leading: CircleAvatar(child: Text(c.name.characters.take(2).toString())),
              title: Text(c.name),
              subtitle: Text(
                _lastMessage[c.id] ?? 'Chat, agenda e sfide · ${c.members} ${c.members == 1 ? 'membro' : 'membri'}${c.admin ? ' · amministratore' : ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: UnreadDot(chat: 'class:${c.id}', name: c.name),
              onTap: () => _open(c.id),
            ),
          ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(onPressed: () => _join(), icon: const Icon(Icons.login_rounded), label: Text(tr('Entra con un codice', 'Join with a code'))),
            OutlinedButton.icon(onPressed: _create, icon: const Icon(Icons.add_rounded), label: Text(tr('Crea una classe', 'Create a class'))),
          ],
        ),
        section(tr('Classifica della settimana', 'This week\'s leaderboard')),
        // 3.8: i primi tre direttamente qui; tutto il resto (e le richieste) nella pagina degli amici.
        Card(
          child: Column(children: [
            for (final f in (_friends?.leaderboard ?? const <Friend>[]).take(3))
              ListTile(
                dense: true,
                leading: SizedBox(width: 24, child: Center(child: Text('${f.rank}', style: const TextStyle(fontWeight: FontWeight.w800)))),
                title: Text('${f.avatar} ${f.me ? tr('Tu', 'You') : f.nickname}', style: TextStyle(fontWeight: f.me ? FontWeight.w700 : null)),
                trailing: Text('${f.weekXp} XP'),
              ),
            ListTile(
              leading: Icon(Icons.emoji_events_rounded, color: scheme.primary),
              title: Text((_friends?.incoming.isNotEmpty ?? false)
                  ? '${_friends!.incoming.length} ${_friends!.incoming.length == 1 ? tr('richiesta di amicizia', 'friend request') : tr('richieste di amicizia', 'friend requests')}'
                  : tr('Classifica completa e amici', 'Full leaderboard and friends')),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                if (_friends?.incoming.isNotEmpty ?? false) Badge(label: Text('${_friends!.incoming.length}')),
                const Icon(Icons.chevron_right_rounded),
              ]),
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const FriendsPage())).then((_) => _load()),
            ),
          ]),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: () => showShareCode(context,
                  title: tr('Il tuo codice amico', 'Your friend code'), code: me.friendCode, link: friendLink(me.friendCode), hint: tr('Inquadra con Easy Lesson', 'Scan with Easy Lesson')),
              icon: const Icon(Icons.qr_code_2_rounded),
              label: Text(tr('Il mio codice', 'My code')),
            ),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const FriendsPage())).then((_) => _load()),
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: Text(tr('Aggiungi', 'Add')),
            ),
          ],
        ),
        // 3.7.1: solo per i maggiorenni verificati di persona dalla moderazione (gli altri non la vedono).
        if (me.adult) ...[
          section(tr('Chat dei grandi', 'Adults\' chat')),
          Card(
            child: ListTile(
              leading: const Text('🔞', style: TextStyle(fontSize: 28)),
              title: Text(tr('Chat dei grandi', 'Adults\' chat')),
              subtitle: Text(tr('Solo maggiorenni verificati · testo, foto e sticker · 24 ore', 'Verified adults only · text, photos and stickers · 24 hours')),
              trailing: const UnreadDot(chat: 'adult'),
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AdultChatPage())).then((_) => _load()),
            ),
          ),
          const DmEntryTile(),
        ],
        if (me.strikes > 0)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            leading: Icon(Icons.gavel_rounded, color: scheme.error),
            title: Text(tr('Avvisi della moderazione', 'Moderation notices')),
            subtitle: Text('${me.strikes} ${me.strikes == 1 ? tr('avviso', 'warning') : tr('avvisi', 'warnings')}'),
            trailing: const UnreadDot(chat: 'notice'),
            onTap: _openNotices,
          ),
        const SizedBox(height: 20),
        Text(
          tr('Nella classe si usano solo frasi pronte, compiti e verifiche. '
          'Se vedi qualcosa di brutto, tienilo premuto e segnalalo.', 'In the class you can only use ready-made phrases, homework and tests. If you see something bad, press and hold it and report it.'),
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: scheme.error),
            icon: const Icon(Icons.person_remove_outlined),
            label: Text(tr('Cancella il profilo di classe e amici', 'Delete the class and friends profile')),
            onPressed: _deleteProfile,
          ),
        ),
      ];
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            if (locked) ModLockBanner(count: me.unreadNotices, onOpen: _openNotices),
            if (locked)
              // Si vede ma non si tocca, in grigio.
              IgnorePointer(
                child: ExcludeSemantics(
                  child: Opacity(
                    opacity: 0.45,
                    child: ColorFiltered(
                      colorFilter: const ColorFilter.matrix(<double>[
                        0.2126, 0.7152, 0.0722, 0, 0, //
                        0.2126, 0.7152, 0.0722, 0, 0,
                        0.2126, 0.7152, 0.0722, 0, 0,
                        0, 0, 0, 1, 0,
                      ]),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: social),
                    ),
                  ),
                ),
              )
            else
              ...social,
          ],
        ),
      );
    }
    final title = widget.asTab ? tr('Amici', 'Friends') : tr('Classe e amici', 'Class and friends');
    return Scaffold(
      appBar: AppBar(title: Text(title), automaticallyImplyLeading: !widget.asTab),
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 720), child: body)),
    );
  }
}

/// Apre il link di un QR (easylesson://class?c=… / friend?c=…).
Future<void> openSocialLink(BuildContext context, String link) async {
  final (kind, code) = parseCodeText(link);
  final store = StoreScope.read(context);
  if (store.accountCode == null) {
    await openClassHub(context);
    return;
  }
  try {
    if (kind == 'class') {
      final id = await Social.joinClass(store, code);
      await store.bump('classesJoined');
      if (context.mounted) await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ClassPage(classId: id)));
    } else if (kind == 'friend') {
      final status = await Social.addFriend(store, code);
      if (context.mounted) socialToast(context, status == 'friends' ? tr('Siete amici!', 'You\'re friends!') : tr('Richiesta di amicizia mandata', 'Friend request sent'));
    }
  } on CloudException catch (e) {
    if (!context.mounted) return;
    if (e.status == 409) {
      await openClassHub(context);
    } else {
      socialToast(context, e);
    }
  }
}

// ---------------------------------------------------------------------------- una classe

Map<String, (String, IconData)> get _kinds => {
  'test': (tr('Verifica', 'Test'), Icons.assignment_late_outlined),
  'homework': (tr('Compiti', 'Homework'), Icons.menu_book_outlined),
  'other': (tr('Altro', 'Other'), Icons.push_pin_outlined),
};

const _months = ['gen', 'feb', 'mar', 'apr', 'mag', 'giu', 'lug', 'ago', 'set', 'ott', 'nov', 'dic'];
const _weekdays = ['lunedì', 'martedì', 'mercoledì', 'giovedì', 'venerdì', 'sabato', 'domenica'];

String _dayLabel(DateTime d) {
  final today = DateTime.now();
  final t = DateTime(today.year, today.month, today.day);
  final diff = DateTime(d.year, d.month, d.day).difference(t).inDays;
  if (diff == 0) return tr('Oggi', 'Today');
  if (diff == 1) return tr('Domani', 'Tomorrow');
  if (diff == -1) return tr('Ieri', 'Yesterday');
  return '${_weekdays[d.weekday - 1][0].toUpperCase()}${_weekdays[d.weekday - 1].substring(1)} ${d.day} ${_months[d.month - 1]}';
}

class ClassPage extends StatefulWidget {
  const ClassPage({super.key, required this.classId});
  final String classId;
  @override
  State<ClassPage> createState() => _ClassPageState();
}

class _ClassPageState extends State<ClassPage> {
  ClassInfo? _info;
  List<ClassItem>? _items;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final store = StoreScope.read(context);
    try {
      // Prima i progressi (così la sfida è aggiornata), poi tutto il resto.
      final lv = levelOf(store);
      await Social.sync(store, xp: lv.xp, level: lv.level, force: true);
      final info = await Social.classInfo(store, widget.classId);
      final items = await Social.items(store, widget.classId);
      if (info.challenges.any((c) => c.completed)) await store.setOpt('egg.classWin', true);
      if (!mounted) return;
      setState(() {
        _info = info;
        _items = items;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _addItem() async {
    final store = StoreScope.read(context);
    final out = await showDialog<(String, String, String, DateTime)>(context: context, builder: (_) => const _ItemDialog());
    if (out == null) return;
    try {
      await Social.addItem(store, widget.classId, kind: out.$1, subject: out.$2, title: out.$3, day: out.$4);
      await _load();
    } catch (e) {
      if (mounted) socialToast(context, e);
    }
  }

  Future<void> _itemMenu(ClassItem it) async {
    final store = StoreScope.read(context);
    final a = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(it.title),
              subtitle: Text('${it.subject.isEmpty ? '' : '${it.subject} · '}${_dayLabel(it.date)} · ${tr('scritto da', 'written by')} ${it.author}'),
            ),
            ListTile(
              leading: const Icon(Icons.add_task_rounded),
              title: Text(tr('Aggiungi alla mia agenda', 'Add to my planner')),
              onTap: () => Navigator.pop(c, 'agenda'),
            ),
            ListTile(
              leading: Icon(it.confirmedByMe ? Icons.thumb_up_alt_rounded : Icons.thumb_up_alt_outlined),
              title: Text(it.confirmedByMe ? tr('Togli la conferma', 'Remove the confirmation') : tr('Confermo, è giusto', 'I confirm, it\'s right')),
              onTap: () => Navigator.pop(c, 'confirm'),
            ),
            if (it.canDelete)
              ListTile(leading: const Icon(Icons.delete_outline_rounded), title: Text(tr('Cancella', 'Delete')), onTap: () => Navigator.pop(c, 'delete')),
            if (!it.byMe)
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: Text(tr('Segnala (falso o offensivo)', 'Report (fake or offensive)')),
                onTap: () => Navigator.pop(c, 'report'),
              ),
          ],
        ),
      ),
    );
    if (a == null || !mounted) return;
    try {
      switch (a) {
        case 'agenda':
          await store.addAgenda(
            date: it.date,
            kind: switch (it.kind) { 'test' => 'verifica', 'homework' => 'compito', _ => 'altro' },
            subject: it.subject,
            text: it.title,
          );
          if (mounted) socialToast(context, tr('Aggiunto alla tua agenda', 'Added to your planner'));
        case 'confirm':
          await Social.confirm(store, widget.classId, it.id);
          await _load();
        case 'delete':
          await Social.deleteItem(store, widget.classId, it.id);
          await _load();
        case 'report':
          await Social.report(store, kind: 'item', target: it.id);
          if (mounted) socialToast(context, tr('Segnalato, grazie', 'Reported, thanks'));
      }
    } catch (e) {
      if (mounted) socialToast(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    if (info == null) {
      return Scaffold(
        appBar: AppBar(title: Text(tr('Classe', 'Class'))),
        body: Center(
          child: _error == null
              ? const CircularProgressIndicator()
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_error is CloudException ? (_error as CloudException).message : '$_error'),
                ),
        ),
      );
    }
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(info.name),
          actions: [
            IconButton(
              tooltip: tr('Invita', 'Invite'),
              icon: const Icon(Icons.qr_code_rounded),
              onPressed: () => showShareCode(context,
                  title: tr('Invita in ${info.name}', 'Invite to ${info.name}'), code: info.joinCode, link: classLink(info.joinCode), hint: tr('Inquadra il QR con Easy Lesson', 'Scan the QR with Easy Lesson')),
            ),
          ],
          bottom: TabBar(tabs: [
            Tab(icon: const Icon(Icons.event_note_outlined), text: tr('Agenda', 'Planner')),
            const Tab(icon: Icon(Icons.chat_bubble_outline_rounded), text: 'Chat'),
            Tab(icon: const Icon(Icons.emoji_events_outlined), text: tr('Sfide', 'Challenges')),
            Tab(icon: const Icon(Icons.groups_outlined), text: tr('Classe', 'Class')),
          ]),
        ),
        // Il pulsante per aggiungere compiti solo nella scheda Agenda.
        floatingActionButton: Builder(
          builder: (context) {
            final tabs = DefaultTabController.of(context);
            return ListenableBuilder(
              listenable: tabs,
              builder: (context, _) => tabs.index == 0
                  ? FloatingActionButton.extended(
                      onPressed: _addItem,
                      icon: const Icon(Icons.add_rounded),
                      label: Text(tr('Compito o verifica', 'Homework or test')),
                    )
                  : const SizedBox.shrink(),
            );
          },
        ),
        body: TabBarView(children: [
          RefreshIndicator(onRefresh: _load, child: _agenda()),
          ClassChatTab(classId: info.id, admin: info.admin),
          RefreshIndicator(onRefresh: _load, child: _ChallengesTab(info: info, onChanged: _load)),
          RefreshIndicator(onRefresh: _load, child: _MembersTab(info: info, onChanged: _load)),
        ]),
      ),
    );
  }

  Widget _agenda() {
    final items = _items ?? const <ClassItem>[];
    final scheme = Theme.of(context).colorScheme;
    if (items.isEmpty) {
      return ListView(padding: const EdgeInsets.all(32), children: [
        const Text('📭', textAlign: TextAlign.center, style: TextStyle(fontSize: 48)),
        const SizedBox(height: 8),
        Text(tr('Ancora niente. Aggiungi la prossima verifica o i compiti: li vede tutta la classe.', 'Nothing yet. Add the next test or homework: the whole class sees it.'), textAlign: TextAlign.center),
      ]);
    }
    final rows = <Widget>[];
    String? lastDay;
    for (final it in items) {
      if (it.day != lastDay) {
        lastDay = it.day;
        rows.add(Padding(
          padding: const EdgeInsets.fromLTRB(4, 14, 4, 4),
          child: Text(_dayLabel(it.date), style: Theme.of(context).textTheme.titleSmall?.copyWith(color: scheme.primary)),
        ));
      }
      final k = _kinds[it.kind] ?? _kinds['other']!;
      rows.add(Card(
        child: ListTile(
          leading: Icon(k.$2, color: it.kind == 'test' ? scheme.error : scheme.primary),
          title: Text(it.subject.isEmpty ? it.title : '${it.subject}: ${it.title}'),
          subtitle: Text('${k.$1} · ${it.author}'),
          trailing: TextButton.icon(
            onPressed: () async {
              try {
                await Social.confirm(StoreScope.read(context), widget.classId, it.id);
                await _load();
              } catch (e) {
                if (mounted) socialToast(context, e);
              }
            },
            icon: Icon(it.confirmedByMe ? Icons.thumb_up_alt_rounded : Icons.thumb_up_alt_outlined, size: 18),
            label: Text('${it.confirms}'),
          ),
          onTap: () => _itemMenu(it),
          onLongPress: () => _itemMenu(it),
        ),
      ));
    }
    return ListView(padding: const EdgeInsets.fromLTRB(12, 0, 12, 96), children: rows);
  }
}

class _ItemDialog extends StatefulWidget {
  const _ItemDialog();
  @override
  State<_ItemDialog> createState() => _ItemDialogState();
}

class _ItemDialogState extends State<_ItemDialog> {
  String _kind = 'test';
  TextEditingController? _subject;
  final _title = TextEditingController();
  DateTime _day = DateTime.now().add(const Duration(days: 1));

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.read(context);
    final subjects = {for (final a in store.agenda) if (a.subject.isNotEmpty) a.subject}.toList()..sort();
    return AlertDialog(
      title: Text(tr('Per tutta la classe', 'For the whole class')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SegmentedButton<String>(
              segments: [
                for (final e in _kinds.entries) ButtonSegment(value: e.key, label: Text(e.value.$1), icon: Icon(e.value.$2)),
              ],
              selected: {_kind},
              showSelectedIcon: false,
              onSelectionChanged: (v) => setState(() => _kind = v.first),
            ),
            const SizedBox(height: 8),
            Autocomplete<String>(
              optionsBuilder: (v) => subjects.where((s) => s.toLowerCase().contains(v.text.toLowerCase())),
              fieldViewBuilder: (context, ctrl, focus, onSubmit) {
                _subject = ctrl;
                return TextField(
                  controller: ctrl,
                  focusNode: focus,
                  maxLength: 40,
                  decoration: InputDecoration(labelText: tr('Materia', 'Subject')),
                );
              },
            ),
            TextField(
              controller: _title,
              maxLength: 80,
              decoration: InputDecoration(labelText: tr('Cosa', 'What'), hintText: tr('Es. capitolo 4, esercizi 1-10', 'E.g. chapter 4, exercises 1-10')),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_rounded),
              title: Text(_dayLabel(_day)),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _day,
                  firstDate: DateTime.now().subtract(const Duration(days: 1)),
                  lastDate: DateTime.now().add(const Duration(days: 300)),
                );
                if (d != null) setState(() => _day = d);
              },
            ),
            Text(tr('Lo vedono tutti i compagni con il tuo soprannome.', 'All classmates see it with your nickname.'), style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('Annulla', 'Cancel'))),
        FilledButton(
          onPressed: () {
            if (_title.text.trim().length < 2) return;
            Navigator.pop(context, (_kind, _subject?.text.trim() ?? '', _title.text.trim(), _day));
          },
          child: Text(tr('Condividi', 'Share')),
        ),
      ],
    );
  }
}

class _ChallengesTab extends StatelessWidget {
  const _ChallengesTab({required this.info, required this.onChanged});
  final ClassInfo info;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = info.challenges.where((c) => c.active).toList();
    final past = info.challenges.where((c) => !c.active).toList();
    Widget card(ClassChallenge c) {
      final m = challengeMetrics[c.metric];
      final left = c.ends.difference(DateTime.now());
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(m?.$2 ?? '🏁', style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 10),
                Expanded(child: Text(c.title, style: const TextStyle(fontWeight: FontWeight.w700))),
                if (c.completed) const Text('🎉', style: TextStyle(fontSize: 22)),
              ]),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(value: c.progress, minHeight: 10),
              ),
              const SizedBox(height: 6),
              Text(
                '${c.done} / ${c.target}${c.metric == 'studied' ? ' minuti' : ''} · ${c.players} ${c.players == 1 ? 'compagno ha' : 'compagni hanno'} contribuito'
                '${c.active ? ' · ${left.inDays > 0 ? tr('mancano ${left.inDays} giorni', '${left.inDays} days left') : tr('ultimo giorno', 'last day')}' : ''}',
                style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      children: [
        Text(tr('Si conta quello che fate da quando parte la sfida: studio (con il timer), compiti segnati come fatti, giorni.', 'What counts is what you do from when the challenge starts: study (with the timer), homework marked done, days.'),
            style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        ...active.map(card),
        if (info.admin)
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.add_rounded),
              label: Text(tr('Nuova sfida', 'New challenge')),
              onPressed: () => _newChallenge(context),
            ),
          ),
        if (past.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(tr('Finite', 'Finished'), style: Theme.of(context).textTheme.titleSmall),
          ...past.map(card),
        ],
      ],
    );
  }

  Future<void> _newChallenge(BuildContext context) async {
    final store = StoreScope.read(context);
    var metric = 'studied';
    var days = 7.0;
    final n = info.members.length;
    double perMember(String m) => switch (m) { 'studied' => 120.0, 'agendaDone' => 5.0, _ => 4.0 };
    var target = perMember(metric) * n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setState) => AlertDialog(
          title: Text(tr('Nuova sfida', 'New challenge')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final e in challengeMetrics.entries)
                    ChoiceChip(
                      label: Text('${e.value.$2} ${e.value.$1}'),
                      selected: metric == e.key,
                      onSelected: (_) => setState(() {
                        metric = e.key;
                        target = perMember(metric) * n;
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text('${tr('Obiettivo', 'Goal')}: ${target.round()}${metric == 'studied' ? ' ${tr('minuti', 'minutes')} (${(target / 60).round()} ${tr('ore', 'hours')})' : ''}'),
              Slider(
                value: target,
                min: perMember(metric),
                max: perMember(metric) * n * 4,
                divisions: (n * 4 - 1).clamp(1, 200),
                onChanged: (v) => setState(() => target = v),
              ),
              Text(tr('Durata: ${days.round()} giorni', 'Duration: ${days.round()} days')),
              Slider(value: days, min: 1, max: 31, divisions: 30, onChanged: (v) => setState(() => days = v)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('Annulla', 'Cancel'))),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(tr('Lancia', 'Start'))),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await Social.newChallenge(store, info.id, metric: metric, target: target.round(), days: days.round());
      await onChanged();
    } catch (e) {
      if (context.mounted) socialToast(context, e);
    }
  }
}

class _MembersTab extends StatelessWidget {
  const _MembersTab({required this.info, required this.onChanged});
  final ClassInfo info;
  final Future<void> Function() onChanged;

  Future<void> _act(BuildContext context, Future<void> Function() f, [String? done]) async {
    try {
      await f();
      if (done != null && context.mounted) socialToast(context, done);
      await onChanged();
    } catch (e) {
      if (context.mounted) socialToast(context, e);
    }
  }

  Future<bool> _sure(BuildContext context, String title, String text) async =>
      await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(title),
          content: Text(text),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('No', 'No'))),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(tr('Sì', 'Yes'))),
          ],
        ),
      ) ==
      true;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.read(context);
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.vpn_key_outlined),
            title: Text(tr('Codice d\'invito: ${info.joinCode}', 'Invite code: ${info.joinCode}')),
            subtitle: Text(info.admin ? tr('Tocca per il QR · tieni premuto per cambiarlo', 'Tap for the QR · press and hold to change it') : tr('Tocca per il QR', 'Tap for the QR')),
            onTap: () => showShareCode(context, title: tr('Invita in ${info.name}', 'Invite to ${info.name}'), code: info.joinCode, link: classLink(info.joinCode)),
            onLongPress: !info.admin
                ? null
                : () async {
                    if (!await _sure(context, tr('Cambiare il codice?', 'Change the code?'), tr('Quello vecchio non funzionerà più (chi è già dentro resta).', 'The old one won\'t work anymore (those already in stay).'))) return;
                    if (context.mounted) await _act(context, () => Social.newJoinCode(store, info.id), tr('Codice cambiato', 'Code changed'));
                  },
          ),
        ),
        const SizedBox(height: 8),
        Text(tr('${info.members.length} membri', '${info.members.length} members'), style: Theme.of(context).textTheme.titleSmall),
        for (final m in info.members)
          ListTile(
            leading: Text(m.avatar, style: const TextStyle(fontSize: 28)),
            title: Text(m.me ? '${m.nickname} (tu)' : m.nickname),
            subtitle: Text('${tr('Livello', 'Level')} ${m.level}${m.owner ? tr(' · ha creato la classe', ' · created the class') : m.admin ? tr(' · amministratore', ' · admin') : m.moderator ? tr(' · moderatore', ' · moderator') : ''}'),
            trailing: m.me
                ? null
                : PopupMenuButton<String>(
                    onSelected: (v) async {
                      switch (v) {
                        case 'promote':
                        case 'demote':
                        case 'moderator':
                          await _act(context, () => Social.member(store, info.id, m.id, v));
                        case 'kick':
                          if (await _sure(context, 'Togliere ${m.nickname}?', tr('Potrà rientrare solo con un nuovo codice.', 'They can only come back with a new code.')) && context.mounted) {
                            await _act(context, () => Social.member(store, info.id, m.id, 'kick'));
                          }
                        case 'report':
                          await _act(context, () => Social.report(store, kind: 'member', target: '${info.id}:${m.id}'), tr('Segnalato, grazie', 'Reported, thanks'));
                      }
                    },
                    itemBuilder: (_) => [
                      if (info.admin && !m.admin) PopupMenuItem(value: 'promote', child: Text(tr('Rendi amministratore', 'Make admin'))),
                      if (info.admin && !m.admin && !m.moderator)
                        PopupMenuItem(value: 'moderator', child: Text(tr('Rendi moderatore (può togliere i compiti)', 'Make moderator (can remove homework)'))),
                      if (info.admin && m.moderator) PopupMenuItem(value: 'demote', child: Text(tr('Togli moderatore', 'Remove moderator'))),
                      if (info.admin && m.admin && !m.owner) PopupMenuItem(value: 'demote', child: Text(tr('Togli amministratore', 'Remove admin'))),
                      if (info.admin && !m.owner) PopupMenuItem(value: 'kick', child: Text(tr('Togli dalla classe', 'Remove from the class'))),
                      PopupMenuItem(value: 'report', child: Text(tr('Segnala il soprannome', 'Report the nickname'))),
                    ],
                  ),
          ),
        const Divider(),
        if (info.admin)
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: Text(tr('Rinomina la classe', 'Rename the class')),
            onTap: () async {
              final ctrl = TextEditingController(text: info.name);
              final name = await showDialog<String>(
                context: context,
                builder: (c) => AlertDialog(
                  title: Text(tr('Nome della classe', 'Class name')),
                  content: TextField(controller: ctrl, maxLength: 30, autofocus: true),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(c), child: Text(tr('Annulla', 'Cancel'))),
                    FilledButton(onPressed: () => Navigator.pop(c, ctrl.text), child: Text(tr('Salva', 'Save'))),
                  ],
                ),
              );
              if (name != null && name.trim().isNotEmpty && context.mounted) {
                await _act(context, () => Social.renameClass(store, info.id, name.trim()));
              }
            },
          ),
        ListTile(
          leading: Icon(Icons.logout_rounded, color: scheme.error),
          title: Text(tr('Esci dalla classe', 'Leave the class'), style: TextStyle(color: scheme.error)),
          subtitle: info.members.length == 1 ? Text(tr('Sei l\'ultimo: la classe verrà cancellata', 'You\'re the last one: the class will be deleted')) : null,
          onTap: () async {
            if (!await _sure(context, tr('Uscire da ${info.name}?', 'Leave ${info.name}?'), tr('Potrai rientrare con il codice.', 'You can come back with the code.'))) return;
            try {
              await Social.leaveClass(store, info.id);
              if (context.mounted) Navigator.of(context).pop();
            } catch (e) {
              if (context.mounted) socialToast(context, e);
            }
          },
        ),
      ],
    );
  }
}

/// "Hai un avviso della moderazione da leggere": l'unica cosa che si può aprire finché non lo leggi.
class ModLockBanner extends StatelessWidget {
  const ModLockBanner({super.key, required this.count, required this.onOpen});
  final int count;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.gavel_rounded, color: scheme.onErrorContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                count == 1 ? tr('Hai un avviso della moderazione da leggere', 'You have a moderation notice to read') : tr('Hai $count avvisi della moderazione da leggere', 'You have $count moderation notices to read'),
                style: TextStyle(fontWeight: FontWeight.w800, color: scheme.onErrorContainer),
              ),
            ),
          ]),
          const SizedBox(height: 6),
          Text(
            tr('Finché non lo leggi, chat, classi e amici restano in grigio. Orario, voti e il resto dell\'app funzionano.', 'Until you read it, chat, classes and friends stay grey. Timetable, grades and the rest of the app work.'),
            style: TextStyle(color: scheme.onErrorContainer),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: onOpen, icon: const Icon(Icons.mark_email_unread_rounded), label: Text(tr('Leggi l\'avviso', 'Read the notice'))),
        ]),
      ),
    );
  }
}

/// Freccia della riga, con il numero dei messaggi nuovi arrivati in diretta (se ce ne sono).
class UnreadDot extends StatelessWidget {
  const UnreadDot({super.key, required this.chat, this.name});
  final String chat;

  /// Nome da usare nelle notifiche di questa chat (es. il nome della classe).
  final String? name;

  @override
  Widget build(BuildContext context) {
    if (name != null) Live.instance.names[chat] = name!;
    return ListenableBuilder(
      listenable: Live.instance,
      builder: (context, _) {
        final n = Live.instance.unreadOf(chat);
        return Row(mainAxisSize: MainAxisSize.min, children: [
          if (n > 0) Badge(label: Text(n > 99 ? '99+' : '$n')),
          const Icon(Icons.chevron_right_rounded),
        ]);
      },
    );
  }
}

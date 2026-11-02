import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../cloud.dart';
import '../log.dart';
import '../mission_engine.dart';
import '../native.dart';
import '../store.dart';
import 'achievements.dart';

/// Menu sviluppatore nascosto ("Sviluppatore²"): si apre tenendo premuto il titolo delle
/// opzioni sviluppatore e scrivendo il PIN, che controlla il server (secret DEV_PIN del Worker).
/// Resta aperto fino a quando si chiude l'app (al massimo 12 ore).
class DeepDev {
  DeepDev._();
  static DateTime? unlockedUntil;
  static bool get open => unlockedUntil != null && DateTime.now().isBefore(unlockedUntil!);
}

Future<void> openDeepDevGate(BuildContext context) async {
  if (DeepDev.open) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const DeepDevPage()));
    return;
  }
  final store = StoreScope.read(context);
  final messenger = ScaffoldMessenger.of(context);
  final nav = Navigator.of(context);
  final ctrl = TextEditingController();
  final pin = await showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      icon: const Text('🕳️', style: TextStyle(fontSize: 36)),
      title: const Text('Chi va là?'),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        obscureText: true,
        decoration: const InputDecoration(hintText: 'Password'),
        onSubmitted: (v) => Navigator.pop(c, v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annulla')),
        FilledButton(onPressed: () => Navigator.pop(c, ctrl.text), child: const Text('Entra')),
      ],
    ),
  );
  if (pin == null || pin.isEmpty) return;
  try {
    if (!await Cloud.devUnlock(pin)) {
      AppLog.w('dev', 'PIN del menu nascosto sbagliato');
      messenger.showSnackBar(const SnackBar(content: Text('Password sbagliata')));
      return;
    }
  } on CloudException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
    return;
  }
  DeepDev.unlockedUntil = DateTime.now().add(const Duration(hours: 12));
  AppLog.i('dev', 'Menu nascosto aperto');
  await store.setOpt('ach.deepDev', true);
  nav.push(MaterialPageRoute<void>(builder: (_) => const DeepDevPage()));
}

class DeepDevPage extends StatelessWidget {
  const DeepDevPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    void push(Widget page) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
    void toast(String s) => ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(s)));
    Widget tile(IconData icon, String title, String? subtitle, VoidCallback onTap) => ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon, color: scheme.primary),
          title: Text(title),
          subtitle: subtitle == null ? null : Text(subtitle),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onTap,
        );
    Widget group(String title, IconData icon, List<Widget> children) => Card(
          margin: const EdgeInsets.symmetric(vertical: 5),
          clipBehavior: Clip.antiAlias,
          child: ExpansionTile(
            key: PageStorageKey('deep-$title'),
            leading: Icon(icon, color: scheme.primary),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            children: children,
          ),
        );
    final prefs = store.rawPrefs();
    final lv = levelOf(store);

    return Scaffold(
      appBar: AppBar(title: const Text('Sviluppatore²')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Text(
                'Qui si può rompere tutto. Ogni modifica è scritta nel log. '
                'Aperto fino alle ${TimeOfDay.fromDateTime(DeepDev.unlockedUntil ?? DateTime.now()).format(context)}.',
                style: TextStyle(color: scheme.error),
              ),
              const SizedBox(height: 8),
              group('Memoria grezza', Icons.memory_rounded, [
                tile(Icons.edit_note_rounded, 'Modifica una chiave', '${prefs.length} chiavi salvate',
                    () => push(const _RawPrefsPage())),
                tile(Icons.data_object_rounded, 'Opzioni (el.extras) come JSON', 'Tutte le opzioni in un editor',
                    () => push(const _ExtrasEditor())),
                tile(Icons.download_rounded, 'Stato completo', 'Tutto quello che l\'app ha in memoria, da copiare',
                    () => push(_TextOut('Stato completo', const JsonEncoder.withIndent('  ').convert(prefs)))),
                tile(Icons.upload_rounded, 'Incolla uno stato completo', 'Sovrascrive con un backup dagli appunti', () async {
                  final data = await Clipboard.getData(Clipboard.kTextPlain);
                  try {
                    final n = await store.restore(data?.text ?? '');
                    toast('Ripristinate $n chiavi');
                  } on FormatException catch (e) {
                    toast(e.message);
                  }
                }),
              ]),
              group('Progressi e livelli', Icons.military_tech_outlined, [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: LevelBadge(level: lv.level, size: 36),
                  title: Text('Livello ${lv.level} · ${lv.xp} XP'),
                  subtitle: Text('Bonus XP: ${store.stat('xpBonus')} · ${unlockedIds(store).length}/${achievements.length} obiettivi'),
                ),
                tile(Icons.add_circle_outline_rounded, 'Cambia il bonus XP', 'Anche negativo', () async {
                  final v = await _askText(context, 'Bonus XP', '${store.stat('xpBonus')}', number: true);
                  final n = int.tryParse(v ?? '');
                  if (n != null) await store.setOpt('stat.xpBonus', n == 0 ? null : n);
                }),
                tile(Icons.pin_outlined, 'Contatori', 'Giorni, serie, orari aperti… (modificabili)', () => push(const _CountersPage())),
                tile(Icons.checklist_rounded, 'Obiettivi uno per uno', 'Sblocca o blocca', () => push(const _AchievementsEditor())),
                tile(Icons.lock_open_rounded, 'Sblocca tutti gli obiettivi', null,
                    () => store.setOpt('ach.done', achievements.map((a) => a.id).join(','))),
                tile(Icons.restart_alt_rounded, 'Azzera tutti i progressi', 'Obiettivi, contatori, sorprese', () async {
                  for (final k in store.rawExtrasKeys().where((k) =>
                      k.startsWith('stat.') || k.startsWith('statmap.') || k.startsWith('egg.') || k.startsWith('ach.'))) {
                    await store.setOpt(k, null);
                  }
                  toast('Progressi azzerati (sul server restano: si riuniscono alla prossima sincronizzazione)');
                }),
                tile(Icons.flag_outlined, 'Missioni nuove adesso', 'Rifà la scelta di oggi e della settimana', () async {
                  for (final k in ['mis.d.key', 'mis.w.key']) {
                    await store.setOpt(k, null);
                  }
                  await Missions.check(store);
                  toast('Missioni rifatte');
                }),
                tile(Icons.event_available_outlined, 'Riscarica gli eventi', 'Dal server, subito', () async {
                  await Missions.refreshEvents(store, force: true);
                  toast('${Missions.events(store).length} eventi in memoria');
                }),
                tile(Icons.celebration_rounded, 'Prova la festa del livello', null, () => showLevelUp(context, lv.level + 1)),
                tile(Icons.refresh_rounded, 'Ricontrolla gli obiettivi adesso', null, () => checkAchievements(context)),
              ]),
              group('Cloud', Icons.cloud_outlined, [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.dns_outlined, color: scheme.primary),
                  title: const Text('Indirizzo del server'),
                  subtitle: Text(Cloud.baseUrl),
                  onTap: () async {
                    final v = await _askText(context, 'Indirizzo del server (vuoto = predefinito)', Cloud.overrideUrl ?? '');
                    if (v == null) return;
                    Cloud.overrideUrl = v.trim().isEmpty ? null : v.trim();
                    await store.setOpt('dev.cloudUrl', Cloud.overrideUrl);
                  },
                ),
                tile(Icons.favorite_border_rounded, 'Il server è vivo?', null, () async {
                  final sw = Stopwatch()..start();
                  final ok = await Cloud.health();
                  toast(ok ? 'Sì, ${sw.elapsedMilliseconds} ms' : 'Non risponde');
                }),
                tile(Icons.terminal_rounded, 'Chiamata a mano', 'GET/PUT/POST/DELETE su /v1/…, con o senza il tuo codice',
                    () => push(const _CloudConsole())),
                tile(Icons.sync_rounded, 'Sincronizza adesso', null, () async {
                  try {
                    toast(await CloudSync.syncNow(store));
                  } on CloudException catch (e) {
                    toast(e.message);
                  }
                }),
                tile(Icons.cloud_upload_outlined, 'Forza il caricamento del backup', null, () async {
                  try {
                    toast(await CloudSync.uploadBackupIfChanged(store, force: true) ? 'Caricato' : 'Serve account e consenso');
                  } on CloudException catch (e) {
                    toast(e.message);
                  }
                }),
                tile(Icons.receipt_long_rounded, 'Ultima risposta del server', null,
                    () => push(_TextOut('Ultima risposta', Cloud.lastResponse ?? 'Nessuna'))),
                tile(Icons.data_array_rounded, 'Progressi che verrebbero mandati', null,
                    () => push(_TextOut('Progressi', const JsonEncoder.withIndent('  ').convert(store.progressData.toJson())))),
              ]),
              group('Rete', Icons.public_rounded, [
                tile(Icons.http_rounded, 'Console HTTP', 'Qualsiasi indirizzo, con intestazioni e corpo', () => push(const _HttpConsole())),
              ]),
              if (NativeBridge.supported)
                group('Android', Icons.android_rounded, [
                  tile(Icons.settings_input_component_rounded, 'Chiama il canale nativo',
                      'easylesson/native: qualsiasi metodo, argomenti in JSON', () => push(const _NativeConsole())),
                ]),
              group('Esperimenti', Icons.science_rounded, [
                tile(Icons.restart_alt_rounded, 'Ricarica tutto dalla memoria', null, () {
                  store.reload();
                  toast('Ricaricato');
                }),
                tile(Icons.dangerous_outlined, 'Errore non gestito', 'Un\'eccezione lanciata fuori da tutto (per provare il log)', () {
                  scheduleMicrotask(() => throw StateError('Errore non gestito dal menu nascosto'));
                }),
                tile(Icons.lock_clock_outlined, 'Chiudi il menu nascosto', 'La prossima volta servirà di nuovo il PIN', () {
                  DeepDev.unlockedUntil = null;
                  Navigator.of(context).pop();
                }),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

Future<String?> _askText(BuildContext context, String title, String initial, {bool number = false, int lines = 1}) {
  final ctrl = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        maxLines: lines,
        keyboardType: number ? const TextInputType.numberWithOptions(signed: true) : null,
        style: const TextStyle(fontFamily: 'monospace'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annulla')),
        FilledButton(onPressed: () => Navigator.pop(c, ctrl.text), child: const Text('OK')),
      ],
    ),
  );
}

/// Testo lungo, selezionabile e copiabile.
class _TextOut extends StatelessWidget {
  const _TextOut(this.title, this.text);
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(title),
          actions: [
            IconButton(
              tooltip: 'Copia',
              icon: const Icon(Icons.copy_rounded),
              onPressed: () => Clipboard.setData(ClipboardData(text: text)),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: SelectableText(text, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
        ),
      );
}

// ---------------------------------------------------------------------------
// Memoria grezza

class _RawPrefsPage extends StatefulWidget {
  const _RawPrefsPage();

  @override
  State<_RawPrefsPage> createState() => _RawPrefsPageState();
}

class _RawPrefsPageState extends State<_RawPrefsPage> {
  String _q = '';

  String _type(Object? v) => switch (v) {
        bool _ => 'bool',
        int _ => 'int',
        double _ => 'double',
        List _ => 'lista',
        _ => 'testo',
      };

  Object? _parse(String type, String text) => switch (type) {
        'bool' => text.trim() == 'true',
        'int' => int.parse(text.trim()),
        'double' => double.parse(text.trim()),
        'lista' => [for (final x in jsonDecode(text) as List) '$x'],
        _ => text,
      };

  Future<void> _edit(String key, Object? value) async {
    final store = StoreScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    final type = _type(value);
    final text = value is List ? jsonEncode(value) : '${value ?? ''}';
    final v = await _askText(context, '$key ($type)', text, lines: text.length > 60 ? 8 : 1);
    if (v == null) return;
    try {
      await store.setRawPref(key, _parse(type, v));
      setState(() {});
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Valore non valido per $type: $e')));
    }
  }

  Future<void> _add() async {
    final store = StoreScope.read(context);
    final key = await _askText(context, 'Nome della chiave nuova', 'el.');
    if (key == null || key.trim().isEmpty || !mounted) return;
    final v = await _askText(context, 'Valore (testo; scrivi true/false o un numero per gli altri tipi)', '');
    if (v == null) return;
    final t = v.trim();
    final Object value = t == 'true' || t == 'false' ? t == 'true' : (int.tryParse(t) ?? double.tryParse(t) ?? v);
    await store.setRawPref(key.trim(), value);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final all = store.rawPrefs();
    final keys = all.keys.where((k) => k.toLowerCase().contains(_q.toLowerCase())).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text('Memoria · ${all.length} chiavi'),
        actions: [IconButton(tooltip: 'Aggiungi', onPressed: _add, icon: const Icon(Icons.add_rounded))],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Filtra'),
              onChanged: (v) => setState(() => _q = v),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: keys.length,
              itemBuilder: (context, i) {
                final k = keys[i];
                final v = all[k];
                final preview = '$v';
                return ListTile(
                  title: Text(k, style: const TextStyle(fontFamily: 'monospace')),
                  subtitle: Text(
                    '${_type(v)} · ${preview.length > 120 ? '${preview.substring(0, 120)}…' : preview}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => _edit(k, v),
                  trailing: IconButton(
                    tooltip: 'Cancella',
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: () async {
                      await store.setRawPref(k, null);
                      setState(() {});
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ExtrasEditor extends StatefulWidget {
  const _ExtrasEditor();

  @override
  State<_ExtrasEditor> createState() => _ExtrasEditorState();
}

class _ExtrasEditorState extends State<_ExtrasEditor> {
  late final TextEditingController _ctrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    final raw = StoreScope.read(context).rawPrefs()['el.extras'];
    Object? decoded;
    try {
      decoded = jsonDecode('${raw ?? '{}'}');
    } catch (_) {
      decoded = {};
    }
    _ctrl = TextEditingController(text: const JsonEncoder.withIndent('  ').convert(decoded));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final store = StoreScope.read(context);
    final nav = Navigator.of(context);
    try {
      final v = jsonDecode(_ctrl.text);
      if (v is! Map) throw const FormatException('Deve essere un oggetto { … }');
      await store.setRawPref('el.extras', jsonEncode(v));
      nav.pop();
    } catch (e) {
      setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('el.extras'),
          actions: [IconButton(tooltip: 'Salva', onPressed: _save, icon: const Icon(Icons.save_rounded))],
        ),
        body: Column(
          children: [
            if (_error != null)
              MaterialBanner(content: Text(_error!), actions: [
                TextButton(onPressed: () => setState(() => _error = null), child: const Text('OK')),
              ]),
            Expanded(
              child: TextField(
                controller: _ctrl,
                maxLines: null,
                expands: true,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                decoration: const InputDecoration(contentPadding: EdgeInsets.all(12), border: InputBorder.none),
              ),
            ),
          ],
        ),
      );
}

// ---------------------------------------------------------------------------
// Progressi

class _CountersPage extends StatelessWidget {
  const _CountersPage();

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final keys = store.rawExtrasKeys().where((k) => k.startsWith('stat.')).toList()..sort();
    return Scaffold(
      appBar: AppBar(title: Text('Contatori · ${keys.length}')),
      body: ListView(
        children: [
          for (final k in keys)
            ListTile(
              title: Text(k.substring(5), style: const TextStyle(fontFamily: 'monospace')),
              trailing: Text('${store.opt<Object?>(k, null)}', style: const TextStyle(fontWeight: FontWeight.w700)),
              onTap: () async {
                final v = await _askText(context, k, '${store.opt<Object?>(k, null)}');
                if (v == null) return;
                final n = int.tryParse(v.trim());
                await store.setOpt(k, n ?? (v.trim().isEmpty ? null : v));
              },
            ),
        ],
      ),
    );
  }
}

class _AchievementsEditor extends StatelessWidget {
  const _AchievementsEditor();

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final done = unlockedIds(store);
    return Scaffold(
      appBar: AppBar(title: Text('Obiettivi · ${done.length}/${achievements.length}')),
      body: ListView(
        children: [
          for (final a in achievements)
            SwitchListTile(
              secondary: Text(a.emoji, style: const TextStyle(fontSize: 24)),
              title: Text('${a.title}  ·  ${a.id}'),
              subtitle: Text('${a.tier.label} ${a.tier.xp} XP · ${a.how}'),
              value: done.contains(a.id),
              onChanged: (v) {
                final s = {...done};
                v ? s.add(a.id) : s.remove(a.id);
                store.setOpt('ach.done', (s.toList()..sort()).join(','));
              },
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Console

class _Console extends StatefulWidget {
  const _Console({
    required this.title,
    required this.fields,
    required this.run,
    this.methods = const [],
  });
  final String title;

  /// (etichetta, valore iniziale, righe)
  final List<(String, String, int)> fields;
  final List<String> methods;
  final Future<String> Function(String method, List<String> values) run;

  @override
  State<_Console> createState() => _ConsoleState();
}

class _ConsoleState extends State<_Console> {
  late final List<TextEditingController> _ctrls = [for (final f in widget.fields) TextEditingController(text: f.$2)];
  late String _method = widget.methods.isEmpty ? '' : widget.methods.first;
  String _out = '';
  bool _busy = false;

  @override
  void dispose() {
    for (final c in _ctrls) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _go() async {
    setState(() {
      _busy = true;
      _out = '';
    });
    final sw = Stopwatch()..start();
    String res;
    try {
      res = await widget.run(_method, [for (final c in _ctrls) c.text]);
    } catch (e) {
      res = 'ERRORE: $e';
    }
    AppLog.i('dev²', '${widget.title}: ${sw.elapsedMilliseconds} ms');
    if (mounted) {
      setState(() {
        _busy = false;
        _out = '⏱ ${sw.elapsedMilliseconds} ms\n\n$res';
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          actions: [
            if (_out.isNotEmpty)
              IconButton(
                tooltip: 'Copia',
                icon: const Icon(Icons.copy_rounded),
                onPressed: () => Clipboard.setData(ClipboardData(text: _out)),
              ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (widget.methods.isNotEmpty)
              SegmentedButton<String>(
                segments: [for (final m in widget.methods) ButtonSegment(value: m, label: Text(m))],
                selected: {_method},
                onSelectionChanged: (s) => setState(() => _method = s.first),
              ),
            for (var i = 0; i < widget.fields.length; i++)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: TextField(
                  controller: _ctrls[i],
                  minLines: widget.fields[i].$3,
                  maxLines: widget.fields[i].$3 == 1 ? 1 : 12,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                  decoration: InputDecoration(labelText: widget.fields[i].$1),
                ),
              ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _busy ? null : _go,
              icon: _busy
                  ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.play_arrow_rounded),
              label: const Text('Esegui'),
            ),
            const SizedBox(height: 12),
            SelectableText(_out, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
          ],
        ),
      );
}

String _cut(String s) => s.length > 20000 ? '${s.substring(0, 20000)}\n… (${s.length} caratteri in tutto)' : s;

class _CloudConsole extends StatelessWidget {
  const _CloudConsole();

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.read(context);
    return _Console(
      title: 'Chiamata al server',
      methods: const ['GET', 'PUT', 'POST', 'DELETE'],
      fields: const [('Percorso dopo /v1', '/me', 1), ('Corpo (JSON, facoltativo)', '', 4), ('Usa il mio codice? (sì/no)', 'sì', 1)],
      run: (method, v) => Cloud.raw(
        method,
        v[0].startsWith('/') ? v[0] : '/${v[0]}',
        code: v[2].trim().toLowerCase().startsWith('s') ? store.accountCode : null,
        body: v[1].trim().isEmpty ? null : v[1],
      ).then(_cut, onError: (Object e) => 'ERRORE: $e\n\n${Cloud.lastResponse ?? ''}'),
    );
  }
}

class _HttpConsole extends StatelessWidget {
  const _HttpConsole();

  @override
  Widget build(BuildContext context) => _Console(
        title: 'Console HTTP',
        methods: const ['GET', 'POST', 'PUT', 'DELETE', 'HEAD'],
        fields: const [
          ('URL', 'https://api.github.com/repos/Andrea-nonloso/Easy-lesson-v2', 1),
          ('Intestazioni (JSON)', '{}', 3),
          ('Corpo', '', 4),
        ],
        run: (method, v) async {
          final req = http.Request(method, Uri.parse(v[0].trim()));
          final h = jsonDecode(v[1].trim().isEmpty ? '{}' : v[1]) as Map;
          req.headers.addAll({for (final e in h.entries) '${e.key}': '${e.value}'});
          if (v[2].isNotEmpty) req.body = v[2];
          final res = await http.Response.fromStream(await req.send().timeout(const Duration(seconds: 30)));
          final headers = res.headers.entries.map((e) => '${e.key}: ${e.value}').join('\n');
          return 'HTTP ${res.statusCode} ${res.reasonPhrase ?? ''}\n$headers\n\n'
              '${_cut(utf8.decode(res.bodyBytes, allowMalformed: true))}';
        },
      );
}

class _NativeConsole extends StatelessWidget {
  const _NativeConsole();

  static const _ch = MethodChannel('easylesson/native');

  @override
  Widget build(BuildContext context) => _Console(
        title: 'Canale nativo',
        fields: const [('Metodo', 'appIcon', 1), ('Argomenti (JSON, facoltativo)', '', 4)],
        run: (_, v) async {
          final args = v[1].trim().isEmpty ? null : jsonDecode(v[1]);
          final res = await _ch.invokeMethod<Object?>(v[0].trim(), args);
          return const JsonEncoder.withIndent('  ').convert(res);
        },
      );
}

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show timeDilation;
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../log.dart';
import '../models.dart';
import '../native.dart';
import '../store.dart';
import '../updater.dart';
import 'achievements.dart';
import 'widgets.dart';

/// Strumenti in più delle opzioni sviluppatore (notifiche, widget, memoria, rete, interfaccia).
List<Widget> devExtraTiles(
  BuildContext context,
  AppStore store,
  Widget Function(IconData icon, String title, String? subtitle, VoidCallback? onTap) tile,
) {
  final scheme = Theme.of(context).colorScheme;
  void push(Widget page) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  void toast(String s) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(s)));
  Widget sw(String key, IconData icon, String title, String subtitle, {void Function(bool v)? also}) =>
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        secondary: Icon(icon, color: scheme.primary),
        title: Text(title),
        subtitle: Text(subtitle),
        value: store.opt(key, false),
        onChanged: (v) {
          also?.call(v);
          store.setOpt(key, v ? true : null);
        },
      );

  final first = store.firstRun;
  return [
    tile(
      Icons.query_stats_rounded,
      'Statistiche dell\'app',
      'Aperta ${store.launches} volte'
          '${first == null ? '' : ' dal ${first.day}/${first.month}/${first.year}'}\n'
          '${store.agenda.length} cose in agenda · ${nicknames.length} soprannomi · '
          '${store.customBells == null ? 'campanelle della scuola' : 'campanelle scelte a mano'}',
      null,
    ),
    const SectionLabel('Notifiche e widget'),
    tile(Icons.notifications_rounded, 'Notifica di prova', 'Arriva subito, sul canale "Prossima lezione"', () async {
      await NativeBridge.requestNotificationPermission();
      await NativeBridge.testNotification('Notifica di prova 🧪', 'Inviata dalle opzioni sviluppatore alle '
          '${TimeSlot.fmt(DateTime.now().hour * 60 + DateTime.now().minute)}');
    }),
    tile(Icons.wb_twilight_rounded, 'Prova il riepilogo della sera', 'Come arriverebbe stasera', () async {
      final list = NativeBridge.reminders(store, DateTime.now().subtract(const Duration(days: 1)));
      final ev = list.where((m) => (m['id'] as int) % 10 == 6 && (m['id'] as int) >= 3000).toList();
      if (ev.isEmpty) return toast('Niente da riassumere (serve il tuo orario)');
      await NativeBridge.testNotification('${ev.first['title']}', '${ev.first['body']}', channel: 'giorno');
    }),
    tile(
      Icons.schedule_send_rounded,
      'Notifiche programmate',
      'Tutte quelle in arrivo nelle prossime 3 settimane',
      () => push(const _ScheduledPage()),
    ),
    tile(Icons.widgets_outlined, 'Dati del widget', 'Il JSON mandato al widget Android', () {
      push(_TextPage(
        title: 'Dati del widget',
        text: const JsonEncoder.withIndent('  ').convert(NativeBridge.widgetData(store)),
      ));
    }),
    tile(Icons.sync_rounded, 'Aggiorna widget e notifiche ora', null, () async {
      await NativeBridge.sync(store);
      toast('Fatto');
    }),
    const SectionLabel('Aggiornamenti'),
    if (Updater.supported)
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        secondary: Icon(Icons.science_outlined, color: scheme.primary),
        title: const Text('Canale Beta 🧪'),
        subtitle: Text(store.betaUpdates
            ? 'Ricevi le versioni di prova prima degli altri (possono avere difetti)'
            : 'Canale Stabile: solo le versioni ufficiali'),
        value: store.betaUpdates,
        onChanged: (v) => store.setBetaUpdates(v),
      ),
    sw('dev.fakeOld', Icons.history_toggle_off_rounded, 'Fai finta di essere vecchio',
        'L\'app crede di essere la 0.0.1: così provi il messaggio di aggiornamento',
        also: (v) => Updater.pretendOld = v),
    tile(Icons.cloud_sync_outlined, 'Controlla GitHub adesso', 'E mostra la risposta', () async {
      final info = await Updater.check(beta: store.betaUpdates);
      if (!context.mounted) return;
      push(_TextPage(
        title: info == null ? 'Nessun aggiornamento' : 'Trovata la ${info.version}',
        text: '${info == null ? '' : 'Download: ${info.downloadUrl ?? info.pageUrl}\n\n'}${Updater.lastResponse ?? 'Nessuna risposta'}',
      ));
    }),
    if (NativeBridge.supported)
      tile(Icons.notification_add_outlined, 'Prova il controllo in background', 'Se c\'è una versione nuova arriva la notifica',
          () async {
        await NativeBridge.runUpdateCheckNow();
        toast('Controllo avviato: se c\'è un aggiornamento arriva la notifica');
      }),
    const SectionLabel('Memoria'),
    tile(Icons.storage_rounded, 'Cosa c\'è salvato', 'Tutte le chiavi, con dimensione e contenuto',
        () => push(const _PrefsPage())),
    tile(Icons.restart_alt_rounded, 'Rifai il setup iniziale', 'Riparte la schermata di benvenuto (i dati restano)',
        () {
      Navigator.of(context).popUntil((r) => r.isFirst);
      store.restartSetup();
    }),
    const SectionLabel('Rete'),
    tile(Icons.network_check_rounded, 'Prova la connessione', 'Server di Easy Lesson e GitHub, con i tempi', () async {
      toast('Provo…');
      Future<String> ping(String name, String url) async {
        final sw = Stopwatch()..start();
        try {
          final r = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 20));
          return '$name: HTTP ${r.statusCode} in ${sw.elapsedMilliseconds} ms (${r.bodyBytes.length} byte)';
        } catch (e) {
          return '$name: errore dopo ${sw.elapsedMilliseconds} ms\n  $e';
        }
      }

      final res = await Future.wait([
        ping('Server Easy Lesson', 'https://us-central1-easy-lesson.cloudfunctions.net/getListe?type=studs'),
        ping('GitHub', 'https://api.github.com/repos/$githubRepo'),
        ping('Sito della scuola', 'https://www.isrosselliaprilia.edu.it/'),
      ]);
      for (final r in res) {
        AppLog.i('rete', r);
      }
      if (context.mounted) push(_TextPage(title: 'Connessione', text: res.join('\n\n')));
    }),
    const SectionLabel('Interfaccia'),
    sw('dev.perf', Icons.speed_rounded, 'Grafico delle prestazioni', 'I tempi di disegno di ogni fotogramma'),
    sw('dev.semantics', Icons.accessibility_new_rounded, 'Vista accessibilità',
        'Come vede l\'app un lettore di schermo (tocca 2 volte per uscire dalle impostazioni)'),
    sw('dev.slow', Icons.slow_motion_video_rounded, 'Animazioni al rallentatore', '5 volte più lente',
        also: (v) => timeDilation = v ? 5.0 : 1.0),
    tile(Icons.text_fields_rounded, 'Schermo e testo', null, () {
      final mq = MediaQuery.of(context);
      push(_TextPage(
        title: 'Schermo e testo',
        text: 'Dimensioni: ${mq.size.width.toStringAsFixed(0)} × ${mq.size.height.toStringAsFixed(0)} dp\n'
            'Densità: ${mq.devicePixelRatio.toStringAsFixed(2)}\n'
            'Testo: ${(mq.textScaler.scale(100)).toStringAsFixed(0)}%\n'
            'Margini sicuri: ${mq.padding}\n'
            'Tema scuro: ${Theme.of(context).brightness == Brightness.dark}\n'
            'Lingua: ${Localizations.localeOf(context)}',
      ));
    }),
    const SectionLabel('Diagnostica'),
    tile(Icons.bug_report_outlined, 'Provoca un errore', 'Per vedere se finisce nel log', () {
      AppLog.e('prova', StateError('Errore di prova dalle opzioni sviluppatore'), StackTrace.current);
      toast('Errore scritto nel log');
    }),
    const SectionLabel('Memoria'),
    tile(Icons.refresh_rounded, 'Rileggi tutto dalla memoria', 'Come chiudere e riaprire l\'app', () {
      store.reload();
      toast('Riletto');
    }),
    tile(Icons.sync_problem_rounded, 'Aggiorna il mio orario adesso', 'E controlla se è cambiato', () async {
      final changed = await store.refreshMine(olderThan: Duration.zero);
      toast(changed ? 'L\'orario è cambiato: guarda la home' : 'Nessun cambiamento');
    }),
    const SectionLabel('Obiettivi e sorprese'),
    tile(Icons.compare_arrows_rounded, 'Simula "l\'orario è cambiato"', 'Mostra l\'avviso nella home con due modifiche finte',
        () {
      store.simulateScheduleChanges();
      toast('Guarda la home');
    }),
    tile(
      Icons.celebration_outlined,
      'Sorpresa di oggi',
      easterMessage(store, DateTime.now()) ?? 'Oggi nessuna sorpresa nella home',
      null,
    ),
    tile(Icons.emoji_events_outlined, 'Obiettivi e livello', '${unlockedIds(store).length}/${achievements.length} obiettivi · '
        'livello ${levelOf(store).level}. Per modificarli serve il menu nascosto.', null),
  ];
}

/// Testo lungo da leggere e copiare.
class _TextPage extends StatelessWidget {
  const _TextPage({required this.title, required this.text});

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
              onPressed: () {
                Clipboard.setData(ClipboardData(text: text));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copiato')));
              },
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: SelectableText(text, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
        ),
      );
}

class _ScheduledPage extends StatelessWidget {
  const _ScheduledPage();

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final list = NativeBridge.reminders(store, DateTime.now());
    String when(int ms) {
      final d = DateTime.fromMillisecondsSinceEpoch(ms);
      return '${dayShort[d.weekday - 1]} ${d.day}/${d.month} ${TimeSlot.fmt(d.hour * 60 + d.minute)}';
    }

    return Scaffold(
      appBar: AppBar(title: Text('${list.length} notifiche')),
      body: list.isEmpty
          ? const Center(child: Text('Nessuna notifica: attivale in Impostazioni → Notifiche'))
          : ListView.builder(
              itemCount: list.length,
              itemBuilder: (context, i) {
                final m = list[i];
                return ListTile(
                  dense: true,
                  leading: Text(m['ch'] == 'lezioni' ? '📚' : '🌙'),
                  title: Text('${when(m['at'] as int)} · ${m['title']}'),
                  subtitle: Text('${m['body']}'),
                  trailing: Text('#${m['id']}'),
                );
              },
            ),
    );
  }
}

class _PrefsPage extends StatefulWidget {
  const _PrefsPage();

  @override
  State<_PrefsPage> createState() => _PrefsPageState();
}

class _PrefsPageState extends State<_PrefsPage> {
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final prefs = store.rawPrefs();
    final total = prefs.values.fold<int>(0, (n, v) => n + '$v'.length);
    String size(int n) => n < 1024 ? '$n B' : '${(n / 1024).toStringAsFixed(1)} KB';
    return Scaffold(
      appBar: AppBar(title: Text('Memoria · ${size(total)}')),
      body: ListView(
        children: [
          for (final e in prefs.entries)
            ListTile(
              dense: true,
              title: Text(e.key, style: const TextStyle(fontFamily: 'monospace')),
              subtitle: Text(
                '${e.value.runtimeType} · ${size('${e.value}'.length)}\n${'${e.value}'.length > 80 ? '${'${e.value}'.substring(0, 80)}…' : e.value}',
              ),
              isThreeLine: true,
              onTap: () {
                var text = '${e.value}';
                try {
                  text = const JsonEncoder.withIndent('  ').convert(jsonDecode(text));
                } catch (_) {/* non è JSON */}
                Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => _TextPage(title: e.key, text: text)));
              },
              trailing: IconButton(
                tooltip: 'Cancella',
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: Text('Cancellare ${e.key}?'),
                      content: const Text('L\'app rilegge tutto subito. Non si può annullare.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annulla')),
                        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Cancella')),
                      ],
                    ),
                  );
                  if (ok == true) {
                    await store.removePref(e.key);
                    if (mounted) setState(() {});
                  }
                },
              ),
            ),
        ],
      ),
    );
  }
}

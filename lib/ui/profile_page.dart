import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../cloud.dart';
import '../progress.dart';
import '../shop.dart';
import '../store.dart';
import 'achievements.dart';
import 'class_page.dart' show openClassHub;
import 'code_scanner.dart';
import 'missions_page.dart';
import 'recovery_pdf.dart';
import 'shop_page.dart';
import 'widgets.dart';

void openProfile(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ProfilePage()));

/// Profilo: livello, statistiche, obiettivi, ricompense e account Easy Lesson Cloud.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final lv = levelOf(store);
    final studied = store.studyMinutes.values.fold(0, (a, b) => a + b);
    Widget stat(String emoji, String value, String label) => Expanded(
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 22)),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
            ],
          ),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('Profilo e progressi')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              const LevelCard(),
              const SizedBox(height: 6),
              Text(
                'Prossima ricompensa al livello ${lv.nextReward} · mancano ${xpForLevel(lv.nextReward) - lv.xp} XP',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  stat('📅', '${store.stat('days')}', 'giorni'),
                  stat('🔥', '${store.stat('streak')}', 'di fila\n(record ${store.stat('bestStreak')})'),
                  stat('👀', '${store.stat('views')}', 'orari aperti'),
                  stat('⏱️', '${studied ~/ 60}h', 'di studio'),
                ],
              ),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.emoji_events_outlined, color: scheme.primary),
                title: const Text('Obiettivi'),
                subtitle: Text('${unlockedIds(store).length} su ${achievements.length} sbloccati'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => openAchievements(context),
              ),
              const MissionsSummaryTile(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.redeem_rounded, color: scheme.primary),
                title: const Text('Ricompense'),
                subtitle: const Text('Ogni 5 livelli si sblocca qualcosa'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const RewardsPage())),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.storefront_rounded, color: scheme.primary),
                title: const Text('Negozio'),
                subtitle: Text('🪙 ${Shop.balance(lv.xp, store)} monete · cornici, titoli, avatar, temi'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => openShop(context),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.groups_rounded, color: scheme.primary),
                title: const Text('Classe e amici'),
                subtitle: const Text('Agenda condivisa, sfide di classe, classifica'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => openClassHub(context),
              ),
              const SectionLabel('Account Easy Lesson'),
              const AccountPanel(),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Account

/// Crea un account, ho già un codice, ho perso il codice; oppure (se c'è) codice, recupero,
/// sincronizzazione e backup. Si usa nel profilo e nell'ultimo passo del setup iniziale.
class AccountPanel extends StatefulWidget {
  const AccountPanel({super.key, this.compact = false});

  /// Versione corta per il setup iniziale.
  final bool compact;

  @override
  State<AccountPanel> createState() => _AccountPanelState();
}

class _AccountPanelState extends State<AccountPanel> {
  bool _busy = false;
  bool _showCode = false;

  /// Codici trovati nel backup di Google (telefono nuovo).
  (String, String?)? _found;

  @override
  void initState() {
    super.initState();
    if (StoreScope.read(context).accountCode == null && CloudVault.supported) {
      CloudVault.read().then((v) {
        if (mounted && v != null) setState(() => _found = v);
      });
    }
  }

  void _toast(String s) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(s)));

  Future<void> _run(Future<void> Function() job) async {
    if (_busy) return job();
    setState(() => _busy = true);
    try {
      await job();
    } on CloudException catch (e) {
      if (mounted) _toast(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _create() => _run(() async {
        final store = StoreScope.read(context);
        final (code, rec) = await CloudAccount.create(store);
        await CloudSync.syncNow(store, quiet: true);
        if (!mounted) return;
        await showCodeDialog(context, code, recovery: rec, fresh: true);
        if (mounted) _toast('Account creato: i tuoi progressi ora sono al sicuro ☁️');
      });

  Future<void> _loginWith(String code) => _run(() async {
        final store = StoreScope.read(context);
        final me = await CloudAccount.login(store, code);
        if (!mounted) return;
        setState(() => _found = null);
        _toast('Bentornato! Livello ${levelOf(store).level} recuperato');
        if (me['backup'] != null) await _offerRestore();
      });

  Future<void> _offerRestore() async {
    final restore = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('C\'è un backup sul server'),
        content: const Text('Vuoi rimetterlo su questo dispositivo? Sostituisce i dati di adesso.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('No')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Ripristina')),
        ],
      ),
    );
    if (restore == true) await _restore(ask: false);
  }

  Future<void> _login() async {
    final code = await _askCode(context, 'Ho già un codice',
        'Scrivi o incolla il codice che hai salvato. Spazi e trattini non contano, maiuscole sì.');
    if (code == null) return;
    if (!looksLikeAccountCode(code)) {
      _toast('Il codice è troppo corto: controlla di averlo copiato tutto');
      return;
    }
    await _loginWith(code);
  }

  Future<void> _recover() async {
    final rec = await _askCode(context, 'Ho perso il codice',
        'Scrivi il codice di recupero (quello del foglio di recupero). Riceverai un codice nuovo: '
            'quello vecchio smetterà di funzionare.');
    if (rec == null) return;
    if (!looksLikeAccountCode(rec)) {
      _toast('Il codice di recupero è troppo corto');
      return;
    }
    await _run(() async {
      final store = StoreScope.read(context);
      final code = await CloudAccount.recover(store, rec);
      if (!mounted) return;
      await showCodeDialog(context, code, recovery: rec, fresh: true, title: '🔑 Il tuo codice nuovo');
      if (mounted) await _offerRestore();
    });
  }

  Future<void> _restore({bool ask = true}) async {
    final store = StoreScope.read(context);
    if (ask) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Ripristinare dal server?'),
          content: const Text('Le parti salvate nel backup sostituiscono quelle di questo dispositivo.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annulla')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Ripristina')),
          ],
        ),
      );
      if (ok != true) return;
    }
    await _run(() async {
      final n = await CloudSync.restoreFromServer(store);
      if (mounted) _toast('Ripristinate $n impostazioni dal server');
    });
  }

  Future<void> _upload() async {
    final store = StoreScope.read(context);
    if (!store.opt('cloud.consent', false)) {
      final ok = await showBackupConsent(context);
      if (!ok) return;
    }
    await _run(() async {
      await CloudSync.uploadBackupIfChanged(store, force: true);
      if (mounted) _toast('Backup caricato (${_kb(store.opt('cloud.backupSize', 0))})');
    });
  }

  Future<void> _newRecovery() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Nuovo codice di recupero?'),
        content: const Text('Quello vecchio smetterà di funzionare: ricordati di buttare o aggiornare il foglio stampato.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annulla')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Crea')),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() async {
      final store = StoreScope.read(context);
      final rec = await CloudAccount.newRecoveryCode(store);
      if (mounted) await showCodeDialog(context, store.accountCode!, recovery: rec, fresh: true, title: 'Codici aggiornati');
    });
  }

  Future<void> _logout() async {
    final store = StoreScope.read(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Scollegare questo dispositivo?'),
        content: const Text(
          'Il tuo account resta sul server. Per ricollegarti ti servirà il codice: '
          'controlla di averlo salvato prima di continuare.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annulla')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Scollega')),
        ],
      ),
    );
    if (ok == true) await CloudAccount.logout(store);
  }

  Future<void> _deleteAccount() async {
    final store = StoreScope.read(context);
    final code = store.accountCode;
    if (code == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Eliminare l\'account?'),
        content: const Text(
          'Dal server spariscono per sempre livello, obiettivi salvati e backup. '
          'Sul dispositivo resta tutto. Non si può annullare.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annulla')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(c).colorScheme.error),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() async {
      await Cloud.deleteAccount(code);
      await CloudAccount.logout(store);
      for (final k in [
        'cloud.lastSync',
        'cloud.backupAt',
        'cloud.backupSign',
        'cloud.backupSize',
        'cloud.auto',
        'cloud.consent',
        'cloud.recoveryPending',
      ]) {
        await store.setOpt(k, null);
      }
      if (mounted) _toast('Account eliminato dal server');
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final code = store.accountCode;
    final small = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    Widget item(IconData icon, String title, String? subtitle, VoidCallback? onTap, {Color? color}) => ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon, color: color ?? scheme.primary),
          title: Text(title, style: color == null ? null : TextStyle(color: color)),
          subtitle: subtitle == null ? null : Text(subtitle),
          onTap: _busy ? null : onTap,
        );

    if (code == null) {
      final found = _found;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (found != null)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              color: scheme.primaryContainer,
              child: ListTile(
                leading: const Icon(Icons.restore_rounded),
                title: const Text('Ho trovato il tuo codice'),
                subtitle: const Text('Salvato nel backup del tuo account Google'),
                trailing: FilledButton(onPressed: _busy ? null : () => _loginWith(found.$1), child: const Text('Entra')),
              ),
            ),
          Text(
            'Con un codice segreto salvi livello e obiettivi sul server di Easy Lesson e li ritrovi '
            'su un altro telefono. Niente email, niente password: solo il codice. '
            'È facoltativo: senza, tutto resta su questo dispositivo.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy ? null : _create,
            icon: _busy
                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2.2))
                : const Icon(Icons.key_rounded),
            label: const Text('Crea il mio codice'),
          ),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: _busy ? null : _login,
            icon: const Icon(Icons.login_rounded),
            label: const Text('Ho già un codice'),
          ),
          TextButton(onPressed: _busy ? null : _recover, child: const Text('Ho perso il codice')),
        ],
      );
    }

    final lastSync = DateTime.tryParse(store.opt('cloud.lastSync', ''));
    final backupAt = DateTime.tryParse(store.opt('cloud.backupAt', ''));
    final verified = DateTime.tryParse(store.opt('cloud.verifiedAt', ''));
    final masked = code.replaceAll(RegExp(r'[^\-]'), '•');
    final rec = store.recoveryCode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (store.opt('cloud.recoveryPending', false))
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            color: scheme.errorContainer,
            child: ListTile(
              leading: const Icon(Icons.warning_amber_rounded),
              title: const Text('Salva il codice di recupero'),
              subtitle: const Text('Ne è stato creato uno: senza, se perdi il codice perdi anche i dati'),
              onTap: () async {
                await showCodeDialog(context, code, recovery: store.recoveryCode, fresh: true);
                await store.setOpt('cloud.recoveryPending', null);
              },
            ),
          ),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
            child: Row(
              children: [
                Expanded(
                  child: SelectableText(
                    _showCode ? code : masked,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  tooltip: _showCode ? 'Nascondi' : 'Mostra',
                  onPressed: () => setState(() => _showCode = !_showCode),
                  icon: Icon(_showCode ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                ),
                IconButton(
                  tooltip: 'Copia e QR',
                  onPressed: () => showCodeDialog(context, code, recovery: rec),
                  icon: const Icon(Icons.qr_code_2_rounded),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('Non dare il codice a nessuno: chi ce l\'ha entra nel tuo account.', style: small),
        ),
        if (!widget.compact) ...[
          const SectionLabel('Non perdere il codice'),
          item(Icons.picture_as_pdf_outlined, 'Foglio di recupero (PDF)', 'Codice e codice di recupero con i QR, da stampare',
              () => exportRecoverySheet(context, code: code, recovery: rec, name: store.username)),
          item(
            Icons.health_and_safety_outlined,
            'Codice di recupero',
            rec == null ? 'Non è su questo dispositivo: creane uno nuovo se non hai il foglio' : 'Toccalo per vederlo',
            rec == null ? _newRecovery : () => showCodeDialog(context, rec, title: 'Codice di recupero'),
          ),
          if (rec != null) item(Icons.autorenew_rounded, 'Crea un codice di recupero nuovo', 'Se quello vecchio è finito in mani sbagliate', _newRecovery),
          item(Icons.password_rounded, 'Salva nel gestore password', 'Google, Samsung, il browser…',
              () => saveCodeToPasswordManager(context, code)),
          if (CloudVault.supported)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: Icon(Icons.cloud_done_outlined, color: scheme.primary),
              title: const Text('Copia nel backup di Google'),
              subtitle: const Text('Su un telefono nuovo con lo stesso account Google il codice si ritrova da solo'),
              value: store.opt('cloud.vault', true),
              onChanged: (v) async {
                await store.setOpt('cloud.vault', v ? null : false);
                if (v) {
                  await CloudVault.save(store);
                } else {
                  await CloudVault.clear();
                }
              },
            ),
          item(Icons.quiz_outlined, 'Controlla che te lo ricordi',
              verified == null ? 'Mai controllato' : 'Ultima volta ${relativeTime(verified)}', () => checkCodeMemory(context, force: true)),
          const SectionLabel('Sincronizzazione'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.cloud_sync_rounded, color: scheme.primary),
            title: const Text('Sincronizza adesso'),
            subtitle: Text(lastSync == null ? 'Mai sincronizzato' : 'Ultima volta ${relativeTime(lastSync)}'),
            trailing: _busy ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)) : null,
            onTap: _busy ? null : () => _run(() async => _toast(await CloudSync.syncNow(store))),
          ),
          const SectionLabel('Backup online'),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '🔒 Voti, assenze, studio, prof, agenda e nome partono cifrati con il tuo codice: '
              'sul server nessuno può leggerli. Orari, tema e impostazioni vanno in chiaro.',
              style: small,
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: Icon(Icons.backup_outlined, color: scheme.primary),
            title: const Text('Backup automatico'),
            subtitle: Text(backupAt == null
                ? 'Una volta al giorno, solo se è cambiato qualcosa'
                : 'Ultimo ${relativeTime(backupAt)} · ${_kb(store.opt('cloud.backupSize', 0))}'),
            value: store.opt('cloud.auto', false) && store.opt('cloud.consent', false),
            onChanged: (v) async {
              if (v && !store.opt('cloud.consent', false) && !await showBackupConsent(context)) return;
              await store.setOpt('cloud.auto', v ? true : null);
            },
          ),
          item(Icons.checklist_rounded, 'Cosa salvare', _sectionsSummary(CloudSync.sections(store)),
              () => showBackupConsent(context)),
          item(Icons.cloud_upload_outlined, 'Carica il backup adesso', null, _upload),
          item(Icons.cloud_download_outlined, 'Ripristina dal server', 'Rimette il backup su questo dispositivo', _restore),
          item(Icons.cloud_off_outlined, 'Cancella il backup dal server', null, () => _run(() async {
                await Cloud.deleteBackup(code);
                await store.setOpt('cloud.backupAt', null);
                await store.setOpt('cloud.backupSign', null);
                await store.setOpt('cloud.auto', null);
                _toast('Backup cancellato dal server');
              })),
          const SectionLabel('Account'),
          item(Icons.logout_rounded, 'Scollega questo dispositivo', null, _logout),
          item(Icons.delete_forever_outlined, 'Elimina l\'account', 'Cancella tutto dal server', _deleteAccount,
              color: scheme.error),
        ],
      ],
    );
  }
}

String _kb(int bytes) => bytes < 1024 ? '$bytes byte' : '${(bytes / 1024).toStringAsFixed(bytes < 10240 ? 1 : 0)} KB';

String _sectionsSummary(Set<String> secs) {
  final names = [for (final s in backupSections) if (secs.contains(s.$1)) s.$2];
  return names.isEmpty ? 'Niente' : names.join(', ');
}

/// Chiede un codice (con il tasto Incolla).
Future<String?> _askCode(BuildContext context, String title, String text) async {
  final ctrl = TextEditingController();
  final v = await showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            autofocus: true,
            autocorrect: false,
            enableSuggestions: false,
            style: const TextStyle(fontFamily: 'monospace'),
            decoration: InputDecoration(
              hintText: 'Ab3\$k-9€xQ#-…',
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (qrScannerSupported)
                    IconButton(
                      tooltip: 'Scansiona il QR',
                      icon: const Icon(Icons.qr_code_scanner_rounded),
                      onPressed: () async {
                        final v = await scanQr(c);
                        if (v != null) ctrl.text = parseCodeText(v).$2;
                      },
                    ),
                  IconButton(
                    tooltip: 'Incolla',
                    icon: const Icon(Icons.paste_rounded),
                    onPressed: () async =>
                        ctrl.text = parseCodeText((await Clipboard.getData(Clipboard.kTextPlain))?.text ?? '').$2,
                  ),
                ],
              ),
            ),
            onSubmitted: (v) => Navigator.pop(c, v.trim()),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annulla')),
        FilledButton(onPressed: () => Navigator.pop(c, ctrl.text.trim()), child: const Text('OK')),
      ],
    ),
  );
  return v == null || v.isEmpty ? null : parseCodeText(v).$2;
}

/// Link easylesson://login?c=… o easylesson://recover?r=… (QR inquadrato con la fotocamera del telefono).
Future<void> openAccountLink(BuildContext context, String link) async {
  final (kind, value) = parseCodeText(link);
  if (kind == 'raw' || !looksLikeAccountCode(value)) return;
  final store = StoreScope.read(context);
  final messenger = ScaffoldMessenger.of(context);
  final current = store.accountCode;
  if (current != null) {
    final same = kind == 'login' && normalizeAccountCode(current) == normalizeAccountCode(value);
    messenger.showSnackBar(SnackBar(
      content: Text(same
          ? 'Questo dispositivo è già collegato con questo codice ✅'
          : 'Questo dispositivo è già collegato a un account: scollegalo prima dal Profilo'),
    ));
    return;
  }
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      icon: const Icon(Icons.key_rounded),
      title: Text(kind == 'login' ? 'Entrare con questo codice?' : 'Recuperare l\'account?'),
      content: Text(kind == 'login'
          ? 'Livello, obiettivi e backup dell\'account arriveranno su questo dispositivo.'
          : 'Con il codice di recupero ricevi un codice nuovo; quello vecchio smette di funzionare.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annulla')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(kind == 'login' ? 'Entra' : 'Recupera')),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  try {
    if (kind == 'login') {
      final me = await CloudAccount.login(store, value);
      messenger.showSnackBar(SnackBar(
        content: Text(me['backup'] != null
            ? 'Bentornato! C\'è un backup: lo ripristini da Profilo → Ripristina dal server'
            : 'Bentornato! Livello ${levelOf(store).level} recuperato'),
      ));
    } else {
      final code = await CloudAccount.recover(store, value);
      if (context.mounted) {
        await showCodeDialog(context, code, recovery: value, fresh: true, title: '🔑 Il tuo codice nuovo');
      }
    }
  } on CloudException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  }
}

/// Mostra i codici grandi, con copia e QR. Se [fresh], obbliga a confermare di averli salvati.
Future<void> showCodeDialog(BuildContext context, String code, {String? recovery, bool fresh = false, String? title}) async {
  var saved = !fresh;
  final store = StoreScope.read(context);
  Widget codeBox(BuildContext c, String label, String value, String qr) => Column(
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          SelectableText(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 19, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.white,
            // Il QR è un link: la fotocamera del telefono apre Easy Lesson; lo scanner dell'app lo capisce.
            child: QrImageView(data: qr, size: 150, backgroundColor: Colors.white),
          ),
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: value));
              if (c.mounted) ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text('$label copiato')));
            },
            icon: const Icon(Icons.copy_rounded),
            label: const Text('Copia'),
          ),
        ],
      );
  await showDialog<void>(
    context: context,
    barrierDismissible: !fresh,
    builder: (c) => StatefulBuilder(
      builder: (c, setState) => AlertDialog(
        title: Text(title ?? (fresh ? '🔑 I tuoi codici' : 'Il tuo codice')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (fresh)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Salvali adesso: sono l\'unico modo per ritrovare i tuoi progressi e aprire i tuoi '
                    'dati cifrati. Se li perdi tutti e due nessuno può recuperarli, nemmeno noi.',
                  ),
                ),
              codeBox(c, 'Codice', code, accountLink(code)),
              if (recovery != null) ...[
                const Divider(height: 24),
                codeBox(c, 'Codice di recupero', recovery, recoveryLink(recovery)),
                const Text('Tienilo separato dal telefono (stampato, a casa).', textAlign: TextAlign.center),
              ],
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => exportRecoverySheet(c, code: code, recovery: recovery, name: store.username),
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('Foglio PDF'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => saveCodeToPasswordManager(c, code),
                    icon: const Icon(Icons.password_rounded),
                    label: const Text('Gestore password'),
                  ),
                ],
              ),
              if (fresh)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: saved,
                  onChanged: (v) => setState(() => saved = v ?? false),
                  title: const Text('Li ho salvati in un posto sicuro'),
                ),
            ],
          ),
        ),
        actions: [
          FilledButton(onPressed: saved ? () => Navigator.pop(c) : null, child: const Text('Fatto')),
        ],
      ),
    ),
  );
}

/// Propone di salvare il codice nel gestore password (Google, Samsung, browser…) con l'autocompletamento.
Future<void> saveCodeToPasswordManager(BuildContext context, String code) async {
  final user = TextEditingController(text: 'Easy Lesson');
  final pass = TextEditingController(text: code);
  await showDialog<void>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Salva nel gestore password'),
      content: AutofillGroup(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Tocca "Salva": il telefono o il browser dovrebbero proporti di ricordare la password. '
                'Se non succede, usa Copia e incollala tu nel gestore.'),
            const SizedBox(height: 12),
            TextField(
              controller: user,
              autofillHints: const [AutofillHints.username],
              decoration: const InputDecoration(labelText: 'Nome utente'),
            ),
            TextField(
              controller: pass,
              autofillHints: const [AutofillHints.password],
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password (il tuo codice)'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Clipboard.setData(ClipboardData(text: code)),
          child: const Text('Copia'),
        ),
        FilledButton(
          onPressed: () {
            TextInput.finishAutofillContext(shouldSave: true);
            Navigator.pop(c);
          },
          child: const Text('Salva'),
        ),
      ],
    ),
  );
  user.dispose();
  pass.dispose();
}

/// Promemoria: ogni tanto chiede le ultime 4 lettere del codice. Se non le sai, te lo fa salvare.
/// Senza [force] chiede solo dopo 3 giorni dall'account, al massimo ogni 3 giorni, e
/// non più per 60 giorni dopo una risposta giusta.
Future<void> checkCodeMemory(BuildContext context, {bool force = false}) async {
  final store = StoreScope.read(context);
  final code = store.accountCode;
  if (code == null) return;
  final now = DateTime.now();
  if (!force) {
    final since = DateTime.tryParse(store.opt('cloud.since', ''));
    final verified = DateTime.tryParse(store.opt('cloud.verifiedAt', ''));
    final asked = DateTime.tryParse(store.opt('cloud.askedAt', ''));
    if (since == null || now.difference(since).inDays < 3) return;
    if (verified != null && now.difference(verified).inDays < 60) return;
    if (asked != null && now.difference(asked).inDays < 3) return;
  }
  await store.setOpt('cloud.askedAt', now.toIso8601String());
  if (!context.mounted) return;
  final last4 = String.fromCharCodes(normalizeAccountCode(code).runes.toList().reversed.take(4).toList().reversed);
  final ctrl = TextEditingController();
  final answer = await showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      icon: const Icon(Icons.quiz_outlined),
      title: const Text('Ti ricordi il tuo codice?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Scrivi gli ultimi 4 caratteri del tuo codice Easy Lesson (maiuscole e simboli contano). '
              'Serve a controllare che l\'hai salvato davvero.'),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            autofocus: true,
            autocorrect: false,
            enableSuggestions: false,
            maxLength: 4,
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 22),
            onSubmitted: (v) => Navigator.pop(c, v),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, '?'), child: const Text('Non me lo ricordo')),
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Dopo')),
        FilledButton(onPressed: () => Navigator.pop(c, ctrl.text), child: const Text('Controlla')),
      ],
    ),
  );
  if (answer == null || !context.mounted) return;
  if (answer.trim() == last4) {
    await store.setOpt('cloud.verifiedAt', now.toIso8601String());
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Giusto! Il tuo codice è al sicuro')));
    }
    return;
  }
  await showCodeDialog(context, code,
      recovery: store.recoveryCode,
      fresh: true,
      title: answer == '?' ? 'Salvalo adesso, finché hai il telefono' : 'Non era giusto: salvalo adesso');
}

/// Link all'informativa privacy.
class PrivacyLink extends StatelessWidget {
  const PrivacyLink({super.key});

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          style: TextButton.styleFrom(padding: EdgeInsets.zero),
          onPressed: () => launchUrl(Uri.parse(privacyUrl), mode: LaunchMode.externalApplication),
          icon: const Icon(Icons.privacy_tip_outlined, size: 18),
          label: const Text('Leggi l\'informativa privacy'),
        ),
      );
}

/// Avviso privacy + scelta di cosa salvare nel backup online. true = accettato.
Future<bool> showBackupConsent(BuildContext context) async {
  final store = StoreScope.read(context);
  final chosen = {...CloudSync.sections(store)};
  var accepted = store.opt('cloud.consent', false);
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setState) => AlertDialog(
        title: const Text('Backup online'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Le parti che scegli vengono copiate sul server di Easy Lesson (Cloudflare), collegate solo al '
                'tuo codice. Quelle con il lucchetto 🔒 (e il tuo nome) partono cifrate con il tuo codice: '
                'sul server nessuno può leggerle. Le altre vanno in chiaro. Puoi cancellare tutto quando vuoi.',
              ),
              const PrivacyLink(),
              const SizedBox(height: 8),
              for (final (id, name, what) in backupSections)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: chosen.contains(id),
                  onChanged: (v) => setState(() => v == true ? chosen.add(id) : chosen.remove(id)),
                  title: Text(secretBackupSections.contains(id) ? '🔒 $name' : name),
                  subtitle: Text(what),
                ),
              const Divider(),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: accepted,
                onChanged: (v) => setState(() => accepted = v ?? false),
                title: const Text(
                  'Ho capito: uso il backup online a mio rischio, Easy Lesson è un progetto di studenti '
                  'fornito così com\'è, senza garanzie. Se perdo codice e codice di recupero, i dati cifrati '
                  'non si possono recuperare.',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annulla')),
          FilledButton(
            onPressed: accepted && chosen.isNotEmpty ? () => Navigator.pop(c, true) : null,
            child: const Text('Salva'),
          ),
        ],
      ),
    ),
  );
  if (ok != true) return false;
  await store.setOpt('cloud.consent', true);
  await store.setOpt('cloud.sections', (chosen.toList()..sort()).join(','));
  return true;
}

// ---------------------------------------------------------------------------
// Ricompense

class RewardsPage extends StatefulWidget {
  const RewardsPage({super.key});

  @override
  State<RewardsPage> createState() => _RewardsPageState();
}

class _RewardsPageState extends State<RewardsPage> {
  late Future<List<Map<String, dynamic>>> _future = Cloud.rewards();

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final level = levelOf(store).level;
    return Scaffold(
      appBar: AppBar(title: const Text('Ricompense')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          final list = snap.data ?? const [];
          if (snap.hasError || list.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Center(child: LevelBadge(level: level, size: 72)),
                const SizedBox(height: 16),
                Text(
                  snap.hasError
                      ? 'Non riesco a raggiungere il server delle ricompense.'
                      : 'Le prime ricompense stanno arrivando!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Ogni 5 livelli si sblocca qualcosa: skin, disegni, temi speciali. '
                  'Intanto il tuo distintivo cambia colore ogni 5 livelli.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                if (snap.hasError)
                  Center(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _future = Cloud.rewards()),
                      child: const Text('Riprova'),
                    ),
                  ),
              ],
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final r in list)
                Builder(builder: (context) {
                  final need = (r['level'] as num?)?.toInt() ?? 1;
                  final open = level >= need;
                  final file = r['file'] as String?;
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (open && file != null && file.isNotEmpty)
                          Image.network(
                            Cloud.rewardFileUrl(file),
                            height: 200,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const SizedBox(height: 60, child: Icon(Icons.broken_image)),
                          ),
                        ListTile(
                          leading: open ? const Icon(Icons.redeem_rounded) : const Icon(Icons.lock_outline_rounded),
                          title: Text(open ? '${r['title']}' : '???'),
                          subtitle: Text(open ? '${r['description'] ?? ''}' : 'Si sblocca al livello $need'),
                          trailing: LevelBadge(level: need, size: 32),
                          iconColor: open ? scheme.primary : null,
                        ),
                      ],
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}

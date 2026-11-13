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
import 'notices.dart' show NoticesPage;
import 'settings_sheet.dart' show showSettingsSheet;
import 'recovery_pdf.dart';
import 'shop_page.dart';
import 'widgets.dart';
import '../i18n.dart';

void openProfile(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ProfilePage()));

/// Profilo (3.6: scheda della barra): in alto livello, XP e serie, subito sotto le missioni,
/// poi obiettivi, ricompense, negozio, avvisi della moderazione e account. L'ingranaggio apre le Impostazioni.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, this.asTab = false});

  /// Scheda della barra in basso (niente freccia indietro).
  final bool asTab;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final lv = levelOf(store);
    final studied = store.studyMinutes.values.fold(0, (a, b) => a + b);
    final lastSync = DateTime.tryParse(store.opt('cloud.lastSync', ''));
    final accountText = store.accountCode == null
        ? tr('Non collegato · facoltativo', 'Not connected · optional')
        : lastSync == null
            ? tr('Collegato', 'Connected')
            : 'Sincronizzato · ${_ago(lastSync)}';
    Widget row(IconData icon, String title, String subtitle, VoidCallback onTap, {bool last = false}) => Column(children: [
          ListTile(
            leading: Icon(icon, color: scheme.primary),
            title: Text(title),
            subtitle: Text(subtitle),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: onTap,
          ),
          if (!last) const Divider(height: 1, indent: 56),
        ]);
    final notices = store.accountCode != null && store.opt<String?>('social.nick', null) != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(asTab ? tr('Profilo', 'Profile') : tr('Profilo e progressi', 'Profile and progress')),
        automaticallyImplyLeading: !asTab,
        actions: [
          IconButton(
            tooltip: tr('Impostazioni', 'Settings'),
            onPressed: () => showSettingsSheet(context),
            icon: const Icon(Icons.settings_outlined),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              // 3.8 "minimal": livello e serie in alto, poi le missioni, poi tutto il resto in un blocco solo.
              const LevelCard(),
              const SizedBox(height: 8),
              Text(
                '🔥 ${store.stat('streak')} ${tr('di fila', 'in a row')} (${tr('record', 'best')} ${store.stat('bestStreak')})  ·  📅 ${store.stat('days')} ${tr('giorni', 'days')}  ·  '
                '⏱️ ${studied ~/ 60} ${tr('h di studio', 'h of study')}',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 14),
              const MissionsSummaryTile(),
              const SizedBox(height: 10),
              Card(
                margin: EdgeInsets.zero,
                clipBehavior: Clip.antiAlias,
                child: Column(children: [
                  row(Icons.emoji_events_outlined, tr('Obiettivi', 'Achievements'), tr('${unlockedCount(store)} su ${visibleCount(store)} sbloccati', '${unlockedCount(store)} of ${visibleCount(store)} unlocked'),
                      () => openAchievements(context)),
                  row(Icons.redeem_rounded, tr('Ricompense', 'Rewards'),
                      tr('Prossima al livello ${lv.nextReward} · mancano ${xpForLevel(lv.nextReward) - lv.xp} XP', 'Next at level ${lv.nextReward} · ${xpForLevel(lv.nextReward) - lv.xp} XP to go'),
                      () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const RewardsPage()))),
                  row(Icons.storefront_rounded, tr('Negozio', 'Shop'), tr('🪙 ${Shop.balance(lv.xp, store)} monete · cornici, titoli, avatar, temi', '🪙 ${Shop.balance(lv.xp, store)} coins · frames, titles, avatars, themes'),
                      () => openShop(context)),
                  if (!asTab)
                    row(Icons.groups_rounded, tr('Classe e amici', 'Class and friends'), tr('Agenda condivisa, sfide di classe, classifica', 'Shared planner, class challenges, leaderboard'),
                        () => openClassHub(context)),
                  if (notices)
                    row(Icons.gavel_rounded, tr('Avvisi della moderazione', 'Moderation notices'), tr('Quelli ricevuti e le conversazioni', 'The ones you received and the conversations'),
                        () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const NoticesPage()))),
                  row(Icons.key_rounded, tr('Account Easy Lesson', 'Easy Lesson account'), accountText, () => openAccountPage(context), last: true),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 2) return 'adesso';
    if (d.inHours < 1) return tr('${d.inMinutes} min fa', '${d.inMinutes} min ago');
    if (d.inDays < 1) return tr('${d.inHours} h fa', '${d.inHours} h ago');
    return d.inDays == 1 ? tr('ieri', 'yesterday') : tr('${d.inDays} giorni fa', '${d.inDays} days ago');
  }
}

/// L'account (codice, recupero, sincronizzazione, backup) in una pagina sua (3.8: nel profilo c'è solo una riga).
void openAccountPage(BuildContext context) => Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text(tr('Account Easy Lesson', 'Easy Lesson account'))),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: const [AccountPanel()]),
          ),
        ),
      ),
    ));

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
        if (mounted) _toast(tr('Account creato: i tuoi progressi ora sono al sicuro ☁️', 'Account created: your progress is now safe ☁️'));
      });

  Future<void> _loginWith(String code) => _run(() async {
        final store = StoreScope.read(context);
        final me = await CloudAccount.login(store, code);
        if (!mounted) return;
        setState(() => _found = null);
        _toast(tr(tr('Bentornato! Livello ${levelOf(store).level} recuperato', 'Welcome back! Level ${levelOf(store).level} restored'), 'Welcome back! Level ${levelOf(store).level} restored'));
        if (me['backup'] != null) await _offerRestore();
      });

  Future<void> _offerRestore() async {
    final restore = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('C\'è un backup sul server', 'There\'s a backup on the server')),
        content: Text(tr('Vuoi rimetterlo su questo dispositivo? Sostituisce i dati di adesso.', 'Put it back on this device? It replaces the current data.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('No', 'No'))),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(tr('Ripristina', 'Restore'))),
        ],
      ),
    );
    if (restore == true) await _restore(ask: false);
  }

  Future<void> _login() async {
    final code = await _askCode(context, tr('Ho già un codice', 'I already have a code'),
        tr('Scrivi o incolla il codice che hai salvato. Spazi e trattini non contano, maiuscole sì.', 'Write or paste the code you saved. Spaces and dashes don\'t matter, capital letters do.'));
    if (code == null) return;
    if (!looksLikeAccountCode(code)) {
      _toast(tr('Il codice è troppo corto: controlla di averlo copiato tutto', 'The code is too short: check you copied all of it'));
      return;
    }
    await _loginWith(code);
  }

  Future<void> _recover() async {
    final rec = await _askCode(context, tr('Ho perso il codice', 'I lost my code'),
        tr('Scrivi il codice di recupero (quello del foglio di recupero). Riceverai un codice nuovo: '
            'quello vecchio smetterà di funzionare.', 'Write the recovery code (the one on the recovery sheet). You\'ll get a new code: the old one will stop working.'));
    if (rec == null) return;
    if (!looksLikeAccountCode(rec)) {
      _toast(tr('Il codice di recupero è troppo corto', 'The recovery code is too short'));
      return;
    }
    await _run(() async {
      final store = StoreScope.read(context);
      final code = await CloudAccount.recover(store, rec);
      if (!mounted) return;
      await showCodeDialog(context, code, recovery: rec, fresh: true, title: tr('🔑 Il tuo codice nuovo', '🔑 Your new code'));
      if (mounted) await _offerRestore();
    });
  }

  Future<void> _restore({bool ask = true}) async {
    final store = StoreScope.read(context);
    if (ask) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(tr('Ripristinare dal server?', 'Restore from the server?')),
          content: Text(tr('Le parti salvate nel backup sostituiscono quelle di questo dispositivo.', 'The parts saved in the backup replace those on this device.')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('Annulla', 'Cancel'))),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(tr('Ripristina', 'Restore'))),
          ],
        ),
      );
      if (ok != true) return;
    }
    await _run(() async {
      final n = await CloudSync.restoreFromServer(store);
      if (mounted) _toast(tr('Ripristinate $n impostazioni dal server', 'Restored $n settings from the server'));
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
        title: Text(tr('Nuovo codice di recupero?', 'New recovery code?')),
        content: Text(tr('Quello vecchio smetterà di funzionare: ricordati di buttare o aggiornare il foglio stampato.', 'The old one will stop working: remember to throw away or update the printed sheet.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('Annulla', 'Cancel'))),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(tr('Crea', 'Create'))),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() async {
      final store = StoreScope.read(context);
      final rec = await CloudAccount.newRecoveryCode(store);
      if (mounted) await showCodeDialog(context, store.accountCode!, recovery: rec, fresh: true, title: tr('Codici aggiornati', 'Codes updated'));
    });
  }

  Future<void> _logout() async {
    final store = StoreScope.read(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('Scollegare questo dispositivo?', 'Disconnect this device?')),
        content: Text(
          tr('Il tuo account resta sul server. Per ricollegarti ti servirà il codice: '
          'controlla di averlo salvato prima di continuare.', 'Your account stays on the server. To reconnect you\'ll need the code: check you saved it before continuing.'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('Annulla', 'Cancel'))),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(tr('Scollega', 'Disconnect'))),
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
        title: Text(tr('Eliminare l\'account?', 'Delete the account?')),
        content: Text(
          tr('Dal server spariscono per sempre livello, obiettivi salvati e backup. '
          'Sul dispositivo resta tutto. Non si può annullare.', 'Level, saved achievements and backup disappear from the server forever. Everything stays on the device. It can\'t be undone.'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('Annulla', 'Cancel'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(c).colorScheme.error),
            onPressed: () => Navigator.pop(c, true),
            child: Text(tr('Elimina', 'Delete')),
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
      if (mounted) _toast(tr('Account eliminato dal server', 'Account deleted from the server'));
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
                title: Text(tr('Ho trovato il tuo codice', 'I found your code')),
                subtitle: Text(tr('Salvato nel backup del tuo account Google', 'Saved in your Google account backup')),
                trailing: FilledButton(onPressed: _busy ? null : () => _loginWith(found.$1), child: Text(tr('Entra', 'Sign in'))),
              ),
            ),
          Text(
            tr('Con un codice segreto salvi livello e obiettivi sul server di Easy Lesson e li ritrovi '
            'su un altro telefono. Niente email, niente password: solo il codice. '
            'È facoltativo: senza, tutto resta su questo dispositivo.', 'With a secret code you save level and achievements on the Easy Lesson server and find them on another phone. No email, no password: just the code. It\'s optional: without it, everything stays on this device.'),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy ? null : _create,
            icon: _busy
                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2.2))
                : const Icon(Icons.key_rounded),
            label: Text(tr('Crea il mio codice', 'Create my code')),
          ),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: _busy ? null : _login,
            icon: const Icon(Icons.login_rounded),
            label: Text(tr('Ho già un codice', 'I already have a code')),
          ),
          TextButton(onPressed: _busy ? null : _recover, child: Text(tr('Ho perso il codice', 'I lost my code'))),
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
              title: Text(tr('Salva il codice di recupero', 'Save the recovery code')),
              subtitle: Text(tr('Ne è stato creato uno: senza, se perdi il codice perdi anche i dati', 'One was created: without it, if you lose the code you lose your data too')),
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
                  tooltip: _showCode ? tr('Nascondi', 'Hide') : tr('Mostra', 'Show'),
                  onPressed: () => setState(() => _showCode = !_showCode),
                  icon: Icon(_showCode ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                ),
                IconButton(
                  tooltip: tr('Copia e QR', 'Copy and QR'),
                  onPressed: () => showCodeDialog(context, code, recovery: rec),
                  icon: const Icon(Icons.qr_code_2_rounded),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(tr('Non dare il codice a nessuno: chi ce l\'ha entra nel tuo account.', 'Don\'t give the code to anyone: whoever has it gets into your account.'), style: small),
        ),
        if (!widget.compact) ...[
          SectionLabel(tr('Non perdere il codice', 'Don\'t lose the code')),
          item(Icons.picture_as_pdf_outlined, tr('Foglio di recupero (PDF)', 'Recovery sheet (PDF)'), tr('Codice e codice di recupero con i QR, da stampare', 'Code and recovery code with QRs, to print'),
              () => exportRecoverySheet(context, code: code, recovery: rec, name: store.username)),
          item(
            Icons.health_and_safety_outlined,
            tr('Codice di recupero', 'Recovery code'),
            rec == null ? tr('Non è su questo dispositivo: creane uno nuovo se non hai il foglio', 'It\'s not on this device: create a new one if you don\'t have the sheet') : tr('Toccalo per vederlo', 'Tap to see it'),
            rec == null ? _newRecovery : () => showCodeDialog(context, rec, title: tr('Codice di recupero', 'Recovery code')),
          ),
          if (rec != null) item(Icons.autorenew_rounded, tr('Crea un codice di recupero nuovo', 'Create a new recovery code'), tr('Se quello vecchio è finito in mani sbagliate', 'If the old one ended up in the wrong hands'), _newRecovery),
          item(Icons.password_rounded, tr('Salva nel gestore password', 'Save to password manager'), tr('Google, Samsung, il browser…', 'Google, Samsung, the browser…'),
              () => saveCodeToPasswordManager(context, code)),
          if (CloudVault.supported)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: Icon(Icons.cloud_done_outlined, color: scheme.primary),
              title: Text(tr('Copia nel backup di Google', 'Copy to Google backup')),
              subtitle: Text(tr('Su un telefono nuovo con lo stesso account Google il codice si ritrova da solo', 'On a new phone with the same Google account the code comes back by itself')),
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
          item(Icons.quiz_outlined, tr('Controlla che te lo ricordi', 'Check you remember it'),
              verified == null ? tr('Mai controllato', 'Never checked') : '${tr('Ultima volta', 'Last time')} ${relativeTime(verified)}', () => checkCodeMemory(context, force: true)),
          SectionLabel(tr('Sincronizzazione', 'Sync')),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.cloud_sync_rounded, color: scheme.primary),
            title: Text(tr('Sincronizza adesso', 'Sync now')),
            subtitle: Text(lastSync == null ? tr('Mai sincronizzato', 'Never synced') : '${tr('Ultima volta', 'Last time')} ${relativeTime(lastSync)}'),
            trailing: _busy ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)) : null,
            onTap: _busy ? null : () => _run(() async => _toast(await CloudSync.syncNow(store))),
          ),
          SectionLabel(tr('Backup online', 'Online backup')),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              tr('🔒 Voti, assenze, studio, prof, agenda e nome partono cifrati con il tuo codice: '
              'sul server nessuno può leggerli. Orari, tema e impostazioni vanno in chiaro.', '🔒 Grades, absences, study, teachers, planner and name leave encrypted with your code: nobody on the server can read them. Timetables, theme and settings travel in the clear.'),
              style: small,
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: Icon(Icons.backup_outlined, color: scheme.primary),
            title: Text(tr('Backup automatico', 'Automatic backup')),
            subtitle: Text(backupAt == null
                ? tr('Una volta al giorno, solo se è cambiato qualcosa', 'Once a day, only if something changed')
                : 'Ultimo ${relativeTime(backupAt)} · ${_kb(store.opt('cloud.backupSize', 0))}'),
            value: store.opt('cloud.auto', false) && store.opt('cloud.consent', false),
            onChanged: (v) async {
              if (v && !store.opt('cloud.consent', false) && !await showBackupConsent(context)) return;
              await store.setOpt('cloud.auto', v ? true : null);
            },
          ),
          item(Icons.checklist_rounded, tr('Cosa salvare', 'What to save'), _sectionsSummary(CloudSync.sections(store)),
              () => showBackupConsent(context)),
          item(Icons.cloud_upload_outlined, tr('Carica il backup adesso', 'Upload the backup now'), null, _upload),
          item(Icons.cloud_download_outlined, tr('Ripristina dal server', 'Restore from the server'), tr('Rimette il backup su questo dispositivo', 'Puts the backup back on this device'), _restore),
          item(Icons.cloud_off_outlined, tr('Cancella il backup dal server', 'Delete the backup from the server'), null, () => _run(() async {
                await Cloud.deleteBackup(code);
                await store.setOpt('cloud.backupAt', null);
                await store.setOpt('cloud.backupSign', null);
                await store.setOpt('cloud.auto', null);
                _toast(tr('Backup cancellato dal server', 'Backup deleted from the server'));
              })),
          const SectionLabel('Account'),
          item(Icons.logout_rounded, tr('Scollega questo dispositivo', 'Disconnect this device'), null, _logout),
          item(Icons.delete_forever_outlined, 'Elimina l\'account', tr('Cancella tutto dal server', 'Delete everything from the server'), _deleteAccount,
              color: scheme.error),
        ],
      ],
    );
  }
}

String _kb(int bytes) => bytes < 1024 ? '$bytes byte' : '${(bytes / 1024).toStringAsFixed(bytes < 10240 ? 1 : 0)} KB';

String _sectionsSummary(Set<String> secs) {
  final names = [for (final s in backupSections) if (secs.contains(s.$1)) s.$2];
  return names.isEmpty ? tr('Niente', 'Nothing') : names.join(', ');
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
                      tooltip: tr('Scansiona il QR', 'Scan the QR'),
                      icon: const Icon(Icons.qr_code_scanner_rounded),
                      onPressed: () async {
                        final v = await scanQr(c);
                        if (v != null) ctrl.text = parseCodeText(v).$2;
                      },
                    ),
                  IconButton(
                    tooltip: tr('Incolla', 'Paste'),
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
        TextButton(onPressed: () => Navigator.pop(c), child: Text(tr('Annulla', 'Cancel'))),
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
          ? tr('Questo dispositivo è già collegato con questo codice ✅', 'This device is already connected with this code ✅')
          : tr('Questo dispositivo è già collegato a un account: scollegalo prima dal Profilo', 'This device is already connected to an account: disconnect it from the Profile first')),
    ));
    return;
  }
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      icon: const Icon(Icons.key_rounded),
      title: Text(kind == 'login' ? tr('Entrare con questo codice?', 'Sign in with this code?') : 'Recuperare l\'account?'),
      content: Text(kind == 'login'
          ? tr('Questo codice arriva da un link o da un QR. Usalo solo se è il tuo: se è di un altro, entri nel suo account e quello che salvi finisce lì.\n\nLivello, obiettivi e backup dell\'account arriveranno su questo dispositivo.',
              'This code comes from a link or a QR. Use it only if it\'s yours: if it belongs to someone else, you enter their account and what you save ends up there.\n\nThe account\'s level, achievements and backup will come to this device.')
          : tr('Con il codice di recupero ricevi un codice nuovo; quello vecchio smette di funzionare.', 'With the recovery code you get a new code; the old one stops working.')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('Annulla', 'Cancel'))),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(kind == 'login' ? tr('Entra', 'Sign in') : tr('Recupera', 'Recover'))),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  try {
    if (kind == 'login') {
      final me = await CloudAccount.login(store, value);
      messenger.showSnackBar(SnackBar(
        content: Text(me['backup'] != null
            ? tr('Bentornato! C\'è un backup: lo ripristini da Profilo → Ripristina dal server', 'Welcome back! There\'s a backup: restore it from Profile → Restore from the server')
            : 'Bentornato! Livello ${levelOf(store).level} recuperato'),
      ));
    } else {
      final code = await CloudAccount.recover(store, value);
      if (context.mounted) {
        await showCodeDialog(context, code, recovery: value, fresh: true, title: tr('🔑 Il tuo codice nuovo', '🔑 Your new code'));
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
              if (c.mounted) ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(tr('$label copiato', '$label copied'))));
            },
            icon: const Icon(Icons.copy_rounded),
            label: Text(tr('Copia', 'Copy')),
          ),
        ],
      );
  await showDialog<void>(
    context: context,
    barrierDismissible: !fresh,
    builder: (c) => StatefulBuilder(
      builder: (c, setState) => AlertDialog(
        title: Text(title ?? (fresh ? tr('🔑 I tuoi codici', '🔑 Your codes') : tr('Il tuo codice', 'Your code'))),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (fresh)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    tr('Salvali adesso: sono l\'unico modo per ritrovare i tuoi progressi e aprire i tuoi '
                    'dati cifrati. Se li perdi tutti e due nessuno può recuperarli, nemmeno noi.', 'Save them now: they\'re the only way to find your progress and open your encrypted data. If you lose both nobody can recover them, not even us.'),
                  ),
                ),
              codeBox(c, tr('Codice', 'Code'), code, accountLink(code)),
              if (recovery != null) ...[
                const Divider(height: 24),
                codeBox(c, tr('Codice di recupero', 'Recovery code'), recovery, recoveryLink(recovery)),
                Text(tr('Tienilo separato dal telefono (stampato, a casa).', 'Keep it away from the phone (printed, at home).'), textAlign: TextAlign.center),
              ],
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => exportRecoverySheet(c, code: code, recovery: recovery, name: store.username),
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: Text(tr('Foglio PDF', 'PDF sheet')),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => saveCodeToPasswordManager(c, code),
                    icon: const Icon(Icons.password_rounded),
                    label: Text(tr('Gestore password', 'Password manager')),
                  ),
                ],
              ),
              if (fresh)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: saved,
                  onChanged: (v) => setState(() => saved = v ?? false),
                  title: Text(tr('Li ho salvati in un posto sicuro', 'I saved them somewhere safe')),
                ),
            ],
          ),
        ),
        actions: [
          FilledButton(onPressed: saved ? () => Navigator.pop(c) : null, child: Text(tr('Fatto', 'Done'))),
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
      title: Text(tr('Salva nel gestore password', 'Save to password manager')),
      content: AutofillGroup(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tr('Tocca "Salva": il telefono o il browser dovrebbero proporti di ricordare la password. '
                'Se non succede, usa Copia e incollala tu nel gestore.', 'Tap "Save": the phone or the browser should offer to remember the password. If it doesn\'t, use Copy and paste it into the manager yourself.')),
            const SizedBox(height: 12),
            TextField(
              controller: user,
              autofillHints: const [AutofillHints.username],
              decoration: InputDecoration(labelText: tr('Nome utente', 'Username')),
            ),
            TextField(
              controller: pass,
              autofillHints: const [AutofillHints.password],
              obscureText: true,
              decoration: InputDecoration(labelText: tr('Password (il tuo codice)', 'Password (your code)')),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Clipboard.setData(ClipboardData(text: code)),
          child: Text(tr('Copia', 'Copy')),
        ),
        FilledButton(
          onPressed: () {
            TextInput.finishAutofillContext(shouldSave: true);
            Navigator.pop(c);
          },
          child: Text(tr('Salva', 'Save')),
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
      title: Text(tr('Ti ricordi il tuo codice?', 'Do you remember your code?')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(tr('Scrivi gli ultimi 4 caratteri del tuo codice Easy Lesson (maiuscole e simboli contano). '
              'Serve a controllare che l\'hai salvato davvero.', 'Write the last 4 characters of your Easy Lesson code (capitals and symbols count). It checks that you really saved it.')),
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
        TextButton(onPressed: () => Navigator.pop(c, '?'), child: Text(tr('Non me lo ricordo', 'I don\'t remember it'))),
        TextButton(onPressed: () => Navigator.pop(c), child: Text(tr('Dopo', 'Later'))),
        FilledButton(onPressed: () => Navigator.pop(c, ctrl.text), child: Text(tr('Controlla', 'Check'))),
      ],
    ),
  );
  if (answer == null || !context.mounted) return;
  if (answer.trim() == last4) {
    await store.setOpt('cloud.verifiedAt', now.toIso8601String());
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('✅ Giusto! Il tuo codice è al sicuro', '✅ Correct! Your code is safe'))));
    }
    return;
  }
  await showCodeDialog(context, code,
      recovery: store.recoveryCode,
      fresh: true,
      title: answer == '?' ? tr('Salvalo adesso, finché hai il telefono', 'Save it now, while you have the phone') : tr('Non era giusto: salvalo adesso', 'That wasn\'t right: save it now'));
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
          label: Text(tr('Leggi l\'informativa privacy', 'Read the privacy policy')),
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
        title: Text(tr('Backup online', 'Online backup')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('Le parti che scegli vengono copiate sul server di Easy Lesson (Cloudflare), collegate solo al '
                'tuo codice. Quelle con il lucchetto 🔒 (e il tuo nome) partono cifrate con il tuo codice: '
                'sul server nessuno può leggerle. Le altre vanno in chiaro. Puoi cancellare tutto quando vuoi.', 'The parts you choose are copied to the Easy Lesson server (Cloudflare), linked only to your code. Those with the lock 🔒 (and your name) leave encrypted with your code: nobody on the server can read them. The others travel in the clear. You can delete everything whenever you want.'),
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
                title: Text(
                  tr('Ho capito: uso il backup online a mio rischio, Easy Lesson è un progetto di studenti '
                  'fornito così com\'è, senza garanzie. Se perdo codice e codice di recupero, i dati cifrati '
                  'non si possono recuperare.', 'Got it: I use the online backup at my own risk, Easy Lesson is a student project provided as is, without warranties. If I lose the code and the recovery code, the encrypted data can\'t be recovered.'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('Annulla', 'Cancel'))),
          FilledButton(
            onPressed: accepted && chosen.isNotEmpty ? () => Navigator.pop(c, true) : null,
            child: Text(tr('Salva', 'Save')),
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
      appBar: AppBar(title: Text(tr('Ricompense', 'Rewards'))),
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
                      ? tr('Non riesco a raggiungere il server delle ricompense.', 'Can\'t reach the rewards server.')
                      : tr('Le prime ricompense stanno arrivando!', 'The first rewards are on their way!'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  tr(
                      'Ogni 5 livelli si sblocca qualcosa: skin, disegni, temi speciali. '
                          'Intanto il tuo distintivo cambia colore ogni 5 livelli.',
                      'Every 5 levels something unlocks: skins, drawings, special themes. '
                          'Meanwhile your badge changes color every 5 levels.'),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                if (snap.hasError)
                  Center(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _future = Cloud.rewards()),
                      child: Text(tr('Riprova', 'Try again')),
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
                          subtitle: Text(open ? '${r['description'] ?? ''}' : tr('Si sblocca al livello $need', 'Unlocks at level $need')),
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

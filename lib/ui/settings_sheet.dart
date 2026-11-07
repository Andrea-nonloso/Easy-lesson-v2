import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../cloud.dart';
import '../i18n.dart';
import '../models.dart';
import '../native.dart';
import '../store.dart';
import '../updater.dart';
import 'achievements.dart';
import 'calendar_page.dart';
import 'customize_pages.dart';
import 'dev_page.dart';
import 'fun.dart';
import 'profile_page.dart';
import 'report_pdf.dart';
import 'school_life_pages.dart';
import 'school_shortcuts.dart';
import 'share_qr.dart';
import 'subjects_page.dart';
import 'theme.dart';
import 'themes_page.dart';
import 'widgets.dart';

const _githubUrl = 'https://github.com/dalonzoo';

void _report(ScaffoldMessengerState messenger, AppStore store, Object? error) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(error == null
          ? tr('Orario importato: ${store.classi.length} classi, ${store.docenti.length} docenti', 'Timetable imported: ${store.classi.length} classes, ${store.docenti.length} teachers')
          : '$error'),
    ));
}

/// Sceglie un file .xlsx dal dispositivo e lo importa.
Future<void> pickAndImportExcel(BuildContext context) async {
  final store = StoreScope.read(context);
  final messenger = ScaffoldMessenger.of(context);
  final res = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['xlsx'],
    withData: true,
  );
  if (res == null || res.files.isEmpty || res.files.first.bytes == null) return;
  final file = res.files.first;
  try {
    await store.importExcelBytes(file.bytes!, name: file.name);
    _report(messenger, store, null);
  } catch (e) {
    _report(messenger, store, e is FormatException ? e.message : e);
  }
}

/// Chiede un link al file Excel (es. sul sito della scuola) e lo scarica.
Future<void> askExcelUrl(BuildContext context) async {
  final store = StoreScope.read(context);
  final messenger = ScaffoldMessenger.of(context);
  final ctrl = TextEditingController(text: store.excelUrl ?? 'https://www.isrosselliaprilia.edu.it/');
  final url = await showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text("Link al file dell'orario"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Incolla il link al file .xlsx pubblicato dalla scuola. "
            "L'app lo riscaricherà quando aggiorni gli elenchi.",
          ),
          const SizedBox(height: 16),
          TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(hintText: 'https://…/orario.xlsx'),
            onSubmitted: (v) => Navigator.pop(c, v),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: Text(tr('Annulla', 'Cancel'))),
        FilledButton(onPressed: () => Navigator.pop(c, ctrl.text), child: Text(tr('Scarica', 'Download'))),
      ],
    ),
  );
  if (url == null || url.trim().isEmpty) return;
  try {
    await store.importExcelUrl(url);
    _report(messenger, store, null);
  } catch (e) {
    _report(messenger, store, e is FormatException ? e.message : e);
  }
}

Future<void> showSettingsSheet(BuildContext context) {
  StoreScope.read(context).bump('settingsOpens');
  return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (_) => const SettingsSheet(),
    );
}

/// Una voce delle impostazioni (cercabile).
class _Item {
  const _Item(this.icon, this.title, this.subtitle, this.onTap, {this.keywords = '', this.external = false});
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final String keywords;
  final bool external;
}

/// Un gruppo delle impostazioni: si apre in una pagina sua.
class _Group {
  const _Group(this.id, this.icon, this.title, this.summary, this.items, {this.extra = const [], this.color});
  final String id;
  final IconData icon;
  final String title;
  final String summary;
  final List<_Item> items;

  /// Widget in più in fondo alla pagina del gruppo (non cercabili).
  final List<Widget> extra;
  final Color? color;
}

Future<void> _confirmClear(BuildContext context, AppStore store) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(tr('Cancellare gli orari salvati?', 'Delete the saved timetables?')),
      content: Text(tr('Verranno rimossi tutti gli orari salvati sul dispositivo, compreso il tuo.', 'All timetables saved on the device will be removed, yours included.')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('Annulla', 'Cancel'))),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(tr('Cancella', 'Delete'))),
      ],
    ),
  );
  if (ok == true) await store.clearAll();
}

Future<void> _confirmResetOptions(BuildContext context, AppStore store) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(tr('Ripristinare le opzioni?', 'Reset the options?')),
      content: Text(
        tr('Home, notifiche, lingua, accessibilità e opzioni varie tornano come appena installata. '
        'Orari, agenda, voti, assenze, soprannomi e tema restano.', 'Home, notifications, language, accessibility and various options go back to just installed. Timetables, planner, grades, absences, nicknames and theme stay.'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('Annulla', 'Cancel'))),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(tr('Ripristina', 'Restore'))),
      ],
    ),
  );
  if (ok == true) await store.resetOptions();
}

void _open(BuildContext context, Widget page) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

/// Tutte le impostazioni, divise in categorie (ognuna si apre in una pagina sua).
List<_Group> _settingsGroups(BuildContext context, AppStore store) {
  final theme = Theme.of(context);
  final scheme = theme.colorScheme;
  final android = NativeBridge.supported;
  return [
    _Group(
      'aspetto',
      Icons.palette_outlined,
      tr('Aspetto', 'Appearance'),
      '${themeById(store.themeId).name} · icona · home · soprannomi',
      [
        _Item(Icons.palette_outlined, tr('Tema', 'Theme'), themeById(store.themeId).name, () => openThemesPage(context),
            keywords: 'colori scuro chiaro oled sfondo'),
        _Item(Icons.auto_awesome_rounded, tr('Stile Expressive', 'Expressive style'),
            store.opt('look.expressive', true) ? tr('Attivo: forme più tonde, pulsanti grandi (tocca per lo stile classico)', 'On: rounder shapes, big buttons (tap for the classic style)') : tr('Spento: stile classico', 'Off: classic style'),
            () => store.setOpt('look.expressive', !store.opt('look.expressive', true)),
            keywords: tr('material 3 expressive forme arrotondate stile nuovo', 'material 3 expressive rounded shapes new style')),
        if (android)
          _Item(Icons.apps_rounded, tr('Icona dell\'app', 'App icon'), tr('Verde, blu, viola, rossa, nera…', 'Green, blue, purple, red, black…'),
              () => pickAppIcon(context), keywords: 'launcher colore'),
        _Item(Icons.apps_rounded, tr('Pulsanti della scuola in home', 'School buttons on home'),
            '${chosenSchoolTools(store).map((t) => t.label).join(', ')} · ${tr('Altro', 'More')}', () => editSchoolShortcuts(context),
            keywords: tr('voti assenze agenda timer zaino prof libri foto scorciatoie', 'grades absences planner timer backpack teachers books photos shortcuts')),
        _Item(Icons.dashboard_customize_outlined, tr('Home e pagina iniziale', 'Home and start page'),
            tr('Cosa vedere nella home, emoji dei laboratori, vibrazione', 'What to see on the home screen, lab emoji, vibration'), () => openHomeOptions(context),
            keywords: 'sezioni scorciatoie conto alla rovescia recenti'),
        _Item(
          Icons.emoji_emotions_outlined,
          tr('Soprannomi ed emoji', 'Nicknames and emoji'),
          nicknames.isEmpty && subjectEmojis.isEmpty
              ? tr('Chiama le materie e i prof come vuoi tu', 'Call subjects and teachers whatever you like')
              : '${{...nicknames.keys, ...subjectEmojis.keys}.length} nomi personalizzati',
          () => openNicknames(context),
          keywords: tr('nomi materie prof rinomina', 'names subjects teachers rename'),
        ),
        _Item(Icons.translate_rounded, tr('Lingua', 'Language'), store.opt('lang', 'it') == 'en' ? 'English' : 'Italiano',
            () => openHomeOptions(context), keywords: 'inglese english'),
        _Item(
          Icons.accessibility_new_rounded,
          tr('Accessibilità', 'Accessibility'),
          'Testo ${store.opt('a11y.text', 100)}%'
              '${store.opt('a11y.contrast', false) ? ' · alto contrasto' : ''}'
              '${store.opt('a11y.font', false) ? ' · font leggibile' : ''}'
              '${store.opt('a11y.motion', false) ? ' · animazioni ridotte' : ''}',
          () => openHomeOptions(context),
          keywords: 'testo grande contrasto dislessia font animazioni',
        ),
      ],
      color: scheme.primary,
    ),
    _Group(
      'orario',
      Icons.schedule_rounded,
      tr('Orario', 'Timetable'),
      '${store.usingExcel ? 'File Excel' : 'Server Easy Lesson'} · campanelle · calendario · A/B',
      [
        _Item(
          Icons.schedule_rounded,
          tr('Orari delle campanelle', 'Bell times'),
          store.customBells == null ? tr('Quelli della scuola · ${store.slots.length} ore', 'The school\'s · ${store.slots.length} periods') : tr('Scelti da te · ${store.slots.length} ore', 'Chosen by you · ${store.slots.length} periods'),
          () => openBells(context),
          keywords: tr('ricreazione ore inizio fine', 'break periods start end'),
        ),
        _Item(
          Icons.event_busy_outlined,
          tr('Calendario scolastico', 'School calendar'),
          store.extraClosures.isEmpty
              ? tr('Vacanze e feste, aggiungi i ponti della scuola', 'Holidays and celebrations, add the school\'s long weekends')
              : tr('Vacanze e feste · ${store.extraClosures.length} giorni aggiunti da te', 'Holidays and celebrations · ${store.extraClosures.length} days added by you'),
          () => openSchoolCalendar(context),
          keywords: 'vacanze ponti feste natale pasqua',
        ),
        _Item(
          Icons.swap_vert_circle_outlined,
          tr('Settimana A/B', 'Week A/B'),
          store.altRef == null ? tr('Se l\'orario cambia a settimane alterne', 'If the timetable changes on alternate weeks') : tr('Settimana B: ${store.altRef!.displayName}', 'Week B: ${store.altRef!.displayName}'),
          () => abWeekDialog(context),
          keywords: 'alternata',
        ),
        _Item(
          Icons.badge_outlined,
          tr('Materie e codici docenti', 'Subjects and teacher codes'),
          subjectOverrides.isEmpty && teacherSubjectOverrides.isEmpty
              ? tr('Es. A026 = Matematica', 'E.g. A026 = Maths')
              : '${subjectOverrides.length + teacherSubjectOverrides.length} personalizzazioni',
          () => _open(context, const SubjectsPage()),
          keywords: tr('classe di concorso', 'subject code'),
        ),
        if (!store.usingExcel)
          _Item(Icons.sync_rounded, tr('Aggiorna gli elenchi', 'Update the lists'),
              store.listsUpdatedAt == null ? tr('Mai scaricati', 'Never downloaded') : '${tr('Aggiornati', 'Updated')} ${relativeTime(store.listsUpdatedAt!)}',
              () => store.refreshLists(), keywords: tr('server classi docenti fonte', 'server classes teachers source')),
        _Item(Icons.upload_file_rounded, store.usingExcel ? tr('Importa un altro file Excel', 'Import another Excel file') : tr('Importa file Excel (.xlsx)', 'Import Excel file (.xlsx)'),
            tr('Il file dell\'orario della scuola: poi funziona tutto offline', 'The school\'s timetable file: then everything works offline'), () => pickAndImportExcel(context),
            keywords: 'xlsx offline fonte'),
        _Item(Icons.link_rounded, tr('Scarica Excel da un link', 'Download Excel from a link'), tr('Ideale nelle app (Android, Windows)', 'Best in the apps (Android, Windows)'), () => askExcelUrl(context),
            keywords: 'fonte'),
        if (store.usingExcel)
          _Item(Icons.cloud_outlined, tr('Torna al server Easy Lesson', 'Back to the Easy Lesson server'), null, () => store.removeExcel(), keywords: 'fonte'),
      ],
      extra: [
        if (store.usingExcel)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.table_view_rounded, color: scheme.primary),
            title: Text(store.excelName ?? tr('File Excel', 'Excel file')),
            subtitle: Text(
              '${tr('${store.classi.length} classi · ${store.docenti.length} docenti', '${store.classi.length} classes · ${store.docenti.length} teachers')}'
              '${store.excelAt != null ? ' · ${tr('importato', 'imported')} ${relativeTime(store.excelAt!)}' : ''}'
              '\n${store.excelUrl != null ? tr('Si aggiorna dal link', 'Updates from the link') : tr('Funziona tutto offline', 'Everything works offline')}',
            ),
            isThreeLine: true,
            trailing: store.listsLoading
                ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : (store.excelUrl != null
                    ? IconButton(tooltip: tr('Riscarica', 'Download again'), onPressed: () => store.refreshLists(), icon: const Icon(Icons.sync_rounded))
                    : null),
          ),
        if (!store.usingExcel && store.listsLoading) const LinearProgressIndicator(),
      ],
      color: Colors.teal,
    ),
    _Group(
      'notifiche',
      Icons.notifications_active_outlined,
      tr('Notifiche', 'Notifications'),
      android ? _notifySummary(store) : (store.opt('n.chat', true) ? tr('Messaggi accesi', 'Messages on') : tr('Messaggi spenti', 'Messages off')),
      [
        // 3.8: messaggi in diretta, su tutte le piattaforme (su Android anche nella pagina delle notifiche).
        if (!android)
          _Item(Icons.chat_bubble_outline_rounded, tr('Messaggi', 'Messages'),
              store.opt('n.chat', true) ? tr('Accese: nuovi messaggi delle chat (tocca per spegnere)', 'On: new chat messages (tap to turn off)') : tr('Spente: tocca per accenderle', 'Off: tap to turn them on'),
              () => store.setOpt('n.chat', store.opt('n.chat', true) ? false : null),
              keywords: tr('chat messaggi privati classe grandi', 'chat messages private class adults')),
        if (android) ...[
          _Item(Icons.notifications_active_outlined, tr('Notifiche', 'Notifications'), _notifySummary(store),
              () => openNotifications(context),
              keywords: tr('lezione riepilogo sera buongiorno ricreazione compiti piano studio vacanze', 'lesson summary evening morning break homework study plan holidays')),
          _Item(Icons.timelapse_rounded, tr('Lezione in corso', 'Lesson in progress'),
              store.opt('n.live', false)
                  ? tr('Attiva: materia, aula e tempo che manca in tendina (tocca per spegnere)', 'On: subject, room and time left in the shade (tap to turn off)')
                  : tr('Spenta: tocca per tenere la lezione sempre in tendina (Live Update)', 'Off: tap to always keep the lesson in the shade (Live Update)'), () async {
            final on = !store.opt('n.live', false);
            if (on && !await NativeBridge.notificationsAllowed()) await NativeBridge.requestNotificationPermission();
            await store.setOpt('n.live', on);
            NativeBridge.scheduleSync(store);
          }, keywords: tr('live update notifica fissa barra stato lezione adesso', 'live update pinned notification status bar lesson now')),
          _Item(Icons.do_not_disturb_on_outlined, tr('Silenzioso a scuola', 'Silent at school'),
              store.opt('silence', false) ? tr('Attivo', 'On') : tr('Non disturbare durante le lezioni', 'Do not disturb during lessons'), () => openNotifications(context),
              keywords: tr('non disturbare silenzio', 'do not disturb silence')),
          _Item(Icons.notifications_paused_outlined, tr('Impostazioni di Android', 'Android settings'),
              tr('Suono e importanza di ogni tipo di notifica', 'Sound and importance of each type of notification'), () => NativeBridge.openNotificationSettings(),
              keywords: 'canali suono vibrazione'),
        ],
      ],
      extra: [
        if (!android)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(tr('Le notifiche delle lezioni si impostano dall\'app Android: su Windows e Linux arrivano le stesse '
                'mentre l\'app è aperta o ridotta a icona. Quelle dei messaggi valgono ovunque.', 'Lesson notifications are set from the Android app: on Windows and Linux the same ones arrive while the app is open or minimized. Message notifications work everywhere.')),
          ),
      ],
      color: Colors.orange,
    ),
    _Group(
      'dati',
      Icons.save_alt_rounded,
      tr('Dati e backup', 'Data and backup'),
      tr('Backup, backup online, QR, resoconto PDF', 'Backup, online backup, QR, PDF report'),
      [
        _Item(Icons.save_alt_rounded, tr('Copia di sicurezza', 'Backup'), tr('Copia tutto negli appunti o rimettilo su un altro dispositivo', 'Copy everything to the clipboard or put it back on another device'),
            () => _backupSheet(context, store), keywords: 'backup ripristina'),
        _Item(Icons.cloud_upload_outlined, tr('Backup online', 'Online backup'),
            store.accountCode == null ? tr('Serve il codice Easy Lesson (facoltativo)', 'Needs the Easy Lesson code (optional)') : tr('Scegli cosa salvare sul server', 'Choose what to save on the server'),
            () => openProfile(context), keywords: 'cloud server sincronizza'),
        _Item(Icons.devices_rounded, tr('Sincronizzazione completa', 'Full sync'),
            CloudSync.live(store)
                ? tr('Attiva: telefono, PC e web sempre uguali, cifrati (tocca per spegnere)', 'On: phone, PC and web always the same, encrypted (tap to turn off)')
                : tr('Gli stessi dati su tutti i tuoi dispositivi, cifrati end-to-end', 'The same data on all your devices, end-to-end encrypted'), () => _toggleLiveSync(context, store),
            keywords: 'sincronizza pc telefono dispositivi uguale cloud e2e'),
        _Item(Icons.qr_code_2_rounded, tr('Condividi con un QR', 'Share with a QR'), tr('Il tuo orario, il tema o i soprannomi', 'Your timetable, the theme or the nicknames'),
            () => showShareQr(context), keywords: 'amico'),
        _Item(Icons.qr_code_scanner_rounded, tr('Importa un codice', 'Import a code'), tr('Incolla il codice che ti hanno mandato', 'Paste the code they sent you'),
            () => importCodeDialog(context)),
        _Item(Icons.picture_as_pdf_outlined, tr('Resoconto PDF', 'PDF report'), tr('Voti, medie e assenze per i genitori', 'Grades, averages and absences for parents'),
            () => exportReport(context), keywords: 'genitori stampa'),
        _Item(Icons.delete_outline_rounded, tr('Cancella orari salvati', 'Delete saved timetables'),
            tr('${store.favorites.length} salvati · ${store.recents.length} recenti', '${store.favorites.length} saved · ${store.recents.length} recent'), () => _confirmClear(context, store)),
        _Item(Icons.settings_backup_restore_rounded, tr('Ripristina le opzioni', 'Reset the options'),
            tr('Home, notifiche, lingua e accessibilità come appena installata', 'Home, notifications, language and accessibility as just installed'), () => _confirmResetOptions(context, store),
            keywords: 'reset predefinite'),
      ],
      color: Colors.green,
    ),
    _Group(
      'aggiornamenti',
      Icons.system_update_outlined,
      tr('Aggiornamenti', 'Updates'),
      store.betaUpdates ? tr('Canale Beta 🧪', 'Beta channel 🧪') : tr('Cerca aggiornamenti, novità', 'Check for updates, what\'s new'),
      [
        _Item(Icons.new_releases_outlined, tr('Novità', 'What\'s new'), tr('Le note di ogni versione su GitHub', 'The notes of each version on GitHub'),
            () => launchUrl(Uri.parse('https://github.com/$githubRepo/releases'), mode: LaunchMode.externalApplication),
            external: true, keywords: 'changelog versione'),
      ],
      extra: [
        const _UpdateTile(),
        if (store.betaUpdates)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 4),
            child: Text(
              tr('🧪 Canale Beta attivo: ricevi le versioni di prova. Si cambia dalle opzioni sviluppatore.', '🧪 Beta channel on: you get the test versions. Change it from the developer options.'),
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        if (android)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(tr('Avvisami delle nuove versioni', 'Tell me about new versions')),
            subtitle: Text(tr('Controlla GitHub ogni qualche ora, anche ad app chiusa', 'Check GitHub every few hours, even with the app closed')),
            value: store.opt('n.updates', true),
            onChanged: (v) => store.setOpt('n.updates', v ? null : false),
          ),
        if (kIsWeb)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.install_desktop_rounded),
            title: Text(tr('Installa come app', 'Install as an app')),
            subtitle: Text(
              tr('Chrome/Edge: icona di installazione nella barra degli indirizzi. '
              'iPhone: Condividi → Aggiungi alla schermata Home. Poi funziona anche offline.', 'Chrome/Edge: install icon in the address bar. iPhone: Share → Add to Home Screen. Then it works offline too.'),
            ),
          ),
      ],
      color: Colors.deepPurple,
    ),
    _Group(
      'info',
      Icons.info_outline_rounded,
      'Info',
      tr('Privacy, progetto, segnala un problema', 'Privacy, project, report a problem'),
      [
        _Item(Icons.bug_report_outlined, tr('Segnala un problema', 'Report a problem'), tr('Apre una segnalazione su GitHub', 'Opens an issue on GitHub'),
            () => launchUrl(Uri.parse('https://github.com/$githubRepo/issues/new'), mode: LaunchMode.externalApplication),
            external: true, keywords: 'bug errore idea'),
        _Item(Icons.code_rounded, tr('Easy Lesson 2 su GitHub', 'Easy Lesson 2 on GitHub'), tr('Il codice di questa versione', 'The code of this version'),
            () => launchUrl(Uri.parse('https://github.com/$githubRepo'), mode: LaunchMode.externalApplication), external: true),
        _Item(Icons.history_edu_rounded, tr('Progetto originale su GitHub', 'Original project on GitHub'), "Easy Lesson di Daniele D'Alonzo",
            () => launchUrl(Uri.parse(_githubUrl), mode: LaunchMode.externalApplication), external: true),
        _Item(Icons.privacy_tip_outlined, 'Privacy policy', null,
            () => launchUrl(Uri.parse(privacyUrl), mode: LaunchMode.externalApplication), external: true),
      ],
      color: Colors.grey,
    ),
    if (store.devMode)
      _Group(
        'dev',
        Icons.science_outlined,
        tr('Opzioni sviluppatore', 'Developer options'),
        tr('Canale Beta, log, notifiche, memoria, rete', 'Beta channel, log, notifications, memory, network'),
        [_Item(Icons.science_outlined, tr('Opzioni sviluppatore', 'Developer options'), null, () => openDevPage(context))],
        color: Colors.red,
      ),
  ];
}

Widget _itemTile(BuildContext context, _Item it) => ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(it.icon, color: Theme.of(context).colorScheme.primary),
      title: Text(it.title),
      subtitle: it.subtitle == null || it.subtitle!.isEmpty ? null : Text(it.subtitle!),
      trailing: Icon(it.external ? Icons.open_in_new_rounded : Icons.chevron_right_rounded, size: it.external ? 18 : null),
      onTap: it.onTap,
    );

/// Pagina di un gruppo: si ricostruisce da sola quando cambia qualcosa.
class _GroupPage extends StatelessWidget {
  const _GroupPage(this.id);
  final String id;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final g = _settingsGroups(context, store).where((g) => g.id == id).firstOrNull;
    if (g == null) return const Scaffold();
    return Scaffold(
      appBar: AppBar(title: Text(g.title)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              for (final it in g.items) _itemTile(context, it),
              ...g.extra,
            ],
          ),
        ),
      ),
    );
  }
}

class SettingsSheet extends StatefulWidget {
  const SettingsSheet({super.key});

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final theme = Theme.of(context);
    final groups = _settingsGroups(context, store);
    final q = normalizeSearch(_q);
    final results = q.isEmpty
        ? const <(_Group, _Item)>[]
        : [
            for (final g in groups)
              for (final it in g.items)
                if (normalizeSearch('${it.title} ${it.subtitle ?? ''} ${it.keywords} ${g.title}').contains(q)) (g, it),
          ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const AppLogo(size: 48),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr('Impostazioni', 'Settings'),
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                    Text(
                      tr("L'orario delle lezioni, sempre in tasca", 'Your timetable, always in your pocket'),
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LevelCard(onTap: () => openProfile(context)),
          const SizedBox(height: 12),
          TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: tr('Cerca un\'impostazione…', 'Search settings…'),
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(28)),
            ),
            onChanged: (v) => setState(() => _q = v),
          ),
          const SizedBox(height: 8),
          if (q.isNotEmpty) ...[
            if (results.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(tr('Nessuna impostazione trovata', 'Nothing found'), textAlign: TextAlign.center),
              ),
            for (final r in results)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(r.$2.icon, color: theme.colorScheme.primary),
                title: Text(r.$2.title),
                subtitle: Text(r.$1.title),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: r.$2.onTap,
              ),
          ] else
            for (final g in groups)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(vertical: 2),
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: (g.color ?? theme.colorScheme.primary).withAlpha(36),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(g.icon, color: g.color ?? theme.colorScheme.primary),
                ),
                title: Text(g.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(g.summary, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => g.items.length == 1 && g.extra.isEmpty ? g.items.first.onTap() : _open(context, _GroupPage(g.id)),
              ),
          FutureBuilder<String>(
            future: Updater.currentVersion(),
            builder: (context, snap) => CreditsFooter(version: snap.data ?? ''),
          ),
        ],
      ),
    );
  }
}

String _notifySummary(AppStore store) {
  final on = [
    if (store.notifyMinutes != null) 'lezioni',
    if (store.opt('n.evening', false)) 'sera',
    if (store.opt('n.morning', false)) 'buongiorno',
    if (store.opt('n.break', false)) 'ricreazione',
    if (store.opt('n.end', false)) 'fine scuola',
    if (store.opt('n.holiday', false)) 'vacanze',
    if (store.opt('n.updates', true)) 'aggiornamenti',
  ];
  return on.isEmpty ? tr('Tutte spente', 'All off') : 'Attive: ${on.join(', ')}';
}

/// Backup: copia negli appunti o ripristino da quello che si incolla.
Future<void> _backupSheet(BuildContext context, AppStore store) async {
  final messenger = ScaffoldMessenger.of(context);
  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.copy_rounded),
            title: Text(tr('Copia il backup negli appunti', 'Copy the backup to the clipboard')),
            subtitle: Text(tr('Poi incollalo dove vuoi (note, chat con te stesso…)', 'Then paste it wherever you like (notes, a chat with yourself…)')),
            onTap: () => Navigator.pop(c, 'copy'),
          ),
          ListTile(
            leading: const Icon(Icons.paste_rounded),
            title: Text(tr('Ripristina dagli appunti', 'Restore from the clipboard')),
            subtitle: Text(tr('Sostituisce le impostazioni di questo dispositivo', 'Replaces the settings on this device')),
            onTap: () => Navigator.pop(c, 'paste'),
          ),
        ],
      ),
    ),
  );
  if (choice == 'copy') {
    await Clipboard.setData(ClipboardData(text: store.backup()));
    await store.setOpt('ach.backup', true);
    messenger.showSnackBar(SnackBar(content: Text(tr('Backup copiato negli appunti', 'Backup copied to the clipboard'))));
  } else if (choice == 'paste') {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    try {
      final n = await store.restore(data?.text ?? '');
      messenger.showSnackBar(SnackBar(content: Text(tr('Ripristinate $n impostazioni', 'Restored $n settings'))));
    } on FormatException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

/// "Cerca aggiornamenti" (Android, Windows) o come si aggiorna sulle altre piattaforme.
class _UpdateTile extends StatefulWidget {
  const _UpdateTile();

  @override
  State<_UpdateTile> createState() => _UpdateTileState();
}

class _UpdateTileState extends State<_UpdateTile> {
  bool _checking = false;
  String? _status;
  UpdateInfo? _update;

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _status = null;
    });
    final info = await Updater.check(beta: StoreScope.read(context).betaUpdates);
    if (!mounted) return;
    setState(() {
      _checking = false;
      _update = info;
      _status = info == null
          ? tr('Hai già l\'ultima versione', 'You already have the latest version')
          : '${tr('Disponibile la versione', 'Version available:')} ${info.version}${info.prerelease ? ' (beta)' : ''}';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!Updater.supported) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.system_update_outlined),
        title: Text(tr('Aggiornamenti', 'Updates')),
        subtitle: Text(tr('La versione web si aggiorna da sola: ricarica la pagina', 'The web version updates by itself: reload the page')),
      );
    }
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(_update != null ? Icons.system_update_rounded : Icons.system_update_outlined,
          color: _update != null ? Theme.of(context).colorScheme.primary : null),
      title: Text(_update != null ? tr('Scarica la versione ${_update!.version}', 'Download version ${_update!.version}') : tr('Cerca aggiornamenti', 'Check for updates')),
      subtitle: _status == null ? null : Text(_status!),
      trailing: _checking
          ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : null,
      onTap: _checking ? null : (_update != null ? () => Updater.open(_update!) : _check),
    );
  }
}

/// Accende/spegne la sincronizzazione completa (serve account + consenso al backup online).
Future<void> _toggleLiveSync(BuildContext context, AppStore store) async {
  final messenger = ScaffoldMessenger.of(context);
  if (CloudSync.live(store)) {
    await store.setOpt('cloud.live', null);
    messenger.showSnackBar(SnackBar(content: Text(tr('Sincronizzazione completa spenta', 'Full sync off'))));
    return;
  }
  if (store.accountCode == null) {
    openProfile(context);
    messenger.showSnackBar(SnackBar(content: Text(tr('Prima crea (o inserisci) il codice Easy Lesson', 'First create (or enter) the Easy Lesson code'))));
    return;
  }
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      icon: const Icon(Icons.devices_rounded),
      title: Text(tr('Sincronizzazione completa', 'Full sync')),
      content: Text(
        tr('Orari, agenda, voti e opzioni restano uguali su tutti i dispositivi con il tuo codice '
        '(telefono, PC, web). Le parti personali viaggiano cifrate: il server non le legge.\n\n'
        'La prima volta, se il server ha già dati di un altro dispositivo, quelli vincono sulle differenze.', 'Timetables, planner, grades and options stay the same on all devices with your code (phone, PC, web). The personal parts travel encrypted: the server can\'t read them.\n\nThe first time, if the server already has data from another device, that data wins on the differences.'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('Annulla', 'Cancel'))),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(tr('Attiva', 'Turn on'))),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  if (!store.opt('cloud.consent', false) && !await showBackupConsent(context)) return;
  await store.setOpt('cloud.live', true);
  try {
    messenger.showSnackBar(SnackBar(content: Text(await CloudSync.syncNow(store))));
  } on CloudException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  }
}

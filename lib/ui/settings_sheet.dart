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
import 'agenda_page.dart' show openAgenda;
import 'bag_page.dart';
import 'calendar_page.dart';
import 'class_page.dart' show openClassHub;
import 'customize_pages.dart';
import 'dev_page.dart';
import 'fun.dart';
import 'missions_page.dart';
import 'more_pages.dart';
import 'photos_page.dart';
import 'profile_page.dart';
import 'report_pdf.dart';
import 'school_life_pages.dart';
import 'share_qr.dart';
import 'shop_page.dart' show openShop;
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
          ? 'Orario importato: ${store.classi.length} classi, ${store.docenti.length} docenti'
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
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annulla')),
        FilledButton(onPressed: () => Navigator.pop(c, ctrl.text), child: const Text('Scarica')),
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
      title: const Text('Cancellare gli orari salvati?'),
      content: const Text('Verranno rimossi tutti gli orari salvati sul dispositivo, compreso il tuo.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annulla')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Cancella')),
      ],
    ),
  );
  if (ok == true) await store.clearAll();
}

Future<void> _confirmResetOptions(BuildContext context, AppStore store) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Ripristinare le opzioni?'),
      content: const Text(
        'Home, notifiche, lingua, accessibilità e opzioni varie tornano come appena installata. '
        'Orari, agenda, voti, assenze, soprannomi e tema restano.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annulla')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Ripristina')),
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
  final lv = levelOf(store);
  return [
    _Group(
      'profilo',
      Icons.military_tech_outlined,
      tr('Profilo e progressi', 'Profile and progress'),
      'Livello ${lv.level} · ${unlockedCount(store)}/${visibleCount(store)} obiettivi'
          '${store.accountCode == null ? '' : ' · account ☁️'}',
      [
        _Item(Icons.military_tech_outlined, tr('Livello e statistiche', 'Level and stats'),
            'Livello ${lv.level} · ${lv.title} · ${lv.xp} XP', () => openProfile(context),
            keywords: 'xp livello profilo statistiche'),
        _Item(Icons.emoji_events_outlined, tr('Obiettivi', 'Achievements'),
            '${unlockedCount(store)} su ${visibleCount(store)} sbloccati', () => openAchievements(context),
            keywords: 'medaglie sfide trofei'),
        _Item(Icons.flag_outlined, tr('Missioni', 'Missions'), '3 al giorno e 3 alla settimana, con XP in più',
            () => openMissions(context), keywords: 'sfide giornaliere settimanali eventi'),
        _Item(Icons.redeem_rounded, tr('Ricompense', 'Rewards'), 'Ogni 5 livelli si sblocca qualcosa',
            () => _open(context, const RewardsPage()), keywords: 'skin premi sblocca'),
        _Item(Icons.storefront_rounded, tr('Negozio', 'Shop'), 'Cornici, titoli, avatar e temi con le monete',
            () => openShop(context), keywords: 'monete compra skin cornice titolo avatar temi'),
        _Item(Icons.groups_rounded, tr('Classe e amici', 'Class and friends'),
            store.opt<String?>('social.nick', null) == null ? 'Agenda condivisa, sfide, classifica' : 'Sei ${store.opt('social.nick', '')}',
            () => openClassHub(context), keywords: 'classe amici classifica compagni gruppo sfide condivisa'),
        _Item(Icons.key_rounded, tr('Account e sincronizzazione', 'Account and sync'),
            store.accountCode == null ? 'Facoltativo: salva i progressi con un codice' : 'Collegato · progressi al sicuro',
            () => openProfile(context), keywords: 'codice login accedi cloud server sincronizza'),
      ],
      color: Colors.amber.shade700,
    ),
    _Group(
      'aspetto',
      Icons.palette_outlined,
      tr('Aspetto', 'Appearance'),
      '${themeById(store.themeId).name} · icona · home · soprannomi',
      [
        _Item(Icons.palette_outlined, tr('Tema', 'Theme'), themeById(store.themeId).name, () => openThemesPage(context),
            keywords: 'colori scuro chiaro oled sfondo'),
        _Item(Icons.auto_awesome_rounded, 'Stile Expressive',
            store.opt('look.expressive', true) ? 'Attivo: forme più tonde, pulsanti grandi (tocca per lo stile classico)' : 'Spento: stile classico',
            () => store.setOpt('look.expressive', !store.opt('look.expressive', true)),
            keywords: 'material 3 expressive forme arrotondate stile nuovo'),
        if (android)
          _Item(Icons.apps_rounded, tr('Icona dell\'app', 'App icon'), 'Verde, blu, viola, rossa, nera…',
              () => pickAppIcon(context), keywords: 'launcher colore'),
        _Item(Icons.dashboard_customize_outlined, tr('Home e pagina iniziale', 'Home and start page'),
            'Cosa vedere nella home, emoji dei laboratori, vibrazione', () => openHomeOptions(context),
            keywords: 'sezioni scorciatoie conto alla rovescia recenti'),
        _Item(
          Icons.emoji_emotions_outlined,
          tr('Soprannomi ed emoji', 'Nicknames and emoji'),
          nicknames.isEmpty && subjectEmojis.isEmpty
              ? 'Chiama le materie e i prof come vuoi tu'
              : '${{...nicknames.keys, ...subjectEmojis.keys}.length} nomi personalizzati',
          () => openNicknames(context),
          keywords: 'nomi materie prof rinomina',
        ),
        _Item(Icons.translate_rounded, tr('Lingua', 'Language'), store.opt('lang', 'it') == 'en' ? 'English (beta)' : 'Italiano',
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
      'scuola',
      Icons.school_outlined,
      tr('Scuola', 'School'),
      'Voti, assenze e permessi, timer, prof, zaino',
      [
        _Item(Icons.grade_outlined, tr('Voti e medie', 'Grades'),
            store.grades.isEmpty ? 'E quanto ti serve alla prossima verifica' : '${store.grades.length} voti',
            () => openGrades(context), keywords: 'media pagella trimestre quadrimestre'),
        _Item(Icons.event_busy_outlined, tr('Assenze e permessi', 'Absences'),
            store.absences.isEmpty ? 'Ore perse e limite del 25%' : '${store.absences.length} segnate', () => openAbsences(context),
            keywords: 'entrata uscita ritardo'),
        _Item(Icons.timer_outlined, tr('Timer per studiare', 'Study timer'), 'Pomodoro 25/5', () => openStudyTimer(context),
            keywords: 'pomodoro'),
        _Item(Icons.hourglass_bottom_rounded, tr('Modalità verifica', 'Exam mode'), 'Conto alla rovescia a tutto schermo',
            () => openExamMode(context)),
        _Item(Icons.menu_book_outlined, tr('Piano di studio', 'Study plan'), 'Il ripasso diviso sui giorni prima',
            () => openStudyPlan(context), keywords: 'ripasso verifica'),
        _Item(Icons.show_chart_rounded, tr('Grafici', 'Charts'), 'Andamento dei voti e studio per settimana',
            () => openCharts(context)),
        _Item(Icons.workspace_premium_outlined, tr('Crediti scolastici', 'School credits'), 'Dal 3º anno',
            () => openCredits(context), keywords: 'maturità'),
        if (!kIsWeb)
          _Item(Icons.photo_library_outlined, tr('Foto delle lezioni', 'Lesson photos'),
              store.photos.isEmpty ? 'Lavagna e appunti' : '${store.photos.length} foto', () => openPhotos(context),
              keywords: 'lavagna appunti'),
        _Item(
          Icons.contact_mail_outlined,
          tr('I miei prof', 'My teachers'),
          store.teachers.isEmpty ? 'Ricevimento, email e note' : '${store.teachers.length} con informazioni',
          () => openTeachers(context),
          keywords: 'docenti ricevimento email',
        ),
        _Item(Icons.backpack_outlined, tr('Zaino', 'Backpack'), 'Regole: camice, tuta, calcolatrice…', () => openBag(context),
            keywords: 'portare'),
        _Item(Icons.library_books_outlined, tr('Libri e materiale', 'Books and supplies'),
            'Per materia e "ogni martedì porta…"', () => openMaterials(context), keywords: 'libri quaderni zaino'),
      ],
      color: Colors.indigo,
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
          store.customBells == null ? 'Quelli della scuola · ${store.slots.length} ore' : 'Scelti da te · ${store.slots.length} ore',
          () => openBells(context),
          keywords: 'ricreazione ore inizio fine',
        ),
        _Item(
          Icons.event_busy_outlined,
          tr('Calendario scolastico', 'School calendar'),
          store.extraClosures.isEmpty
              ? 'Vacanze e feste, aggiungi i ponti della scuola'
              : 'Vacanze e feste · ${store.extraClosures.length} giorni aggiunti da te',
          () => openSchoolCalendar(context),
          keywords: 'vacanze ponti feste natale pasqua',
        ),
        _Item(
          Icons.swap_vert_circle_outlined,
          'Settimana A/B',
          store.altRef == null ? 'Se l\'orario cambia a settimane alterne' : 'Settimana B: ${store.altRef!.displayName}',
          () => abWeekDialog(context),
          keywords: 'alternata',
        ),
        _Item(
          Icons.badge_outlined,
          'Materie e codici docenti',
          subjectOverrides.isEmpty && teacherSubjectOverrides.isEmpty
              ? 'Es. A026 = Matematica'
              : '${subjectOverrides.length + teacherSubjectOverrides.length} personalizzazioni',
          () => _open(context, const SubjectsPage()),
          keywords: 'classe di concorso',
        ),
        if (!store.usingExcel)
          _Item(Icons.sync_rounded, 'Aggiorna gli elenchi',
              store.listsUpdatedAt == null ? 'Mai scaricati' : 'Aggiornati ${relativeTime(store.listsUpdatedAt!)}',
              () => store.refreshLists(), keywords: 'server classi docenti fonte'),
        _Item(Icons.upload_file_rounded, store.usingExcel ? 'Importa un altro file Excel' : 'Importa file Excel (.xlsx)',
            'Il file dell\'orario della scuola: poi funziona tutto offline', () => pickAndImportExcel(context),
            keywords: 'xlsx offline fonte'),
        _Item(Icons.link_rounded, 'Scarica Excel da un link', 'Ideale nelle app (Android, Windows)', () => askExcelUrl(context),
            keywords: 'fonte'),
        if (store.usingExcel)
          _Item(Icons.cloud_outlined, 'Torna al server Easy Lesson', null, () => store.removeExcel(), keywords: 'fonte'),
      ],
      extra: [
        if (store.usingExcel)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.table_view_rounded, color: scheme.primary),
            title: Text(store.excelName ?? 'File Excel'),
            subtitle: Text(
              '${store.classi.length} classi · ${store.docenti.length} docenti'
              '${store.excelAt != null ? ' · importato ${relativeTime(store.excelAt!)}' : ''}'
              '${store.excelUrl != null ? '\nSi aggiorna dal link' : '\nFunziona tutto offline'}',
            ),
            isThreeLine: true,
            trailing: store.listsLoading
                ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : (store.excelUrl != null
                    ? IconButton(tooltip: 'Riscarica', onPressed: () => store.refreshLists(), icon: const Icon(Icons.sync_rounded))
                    : null),
          ),
        if (!store.usingExcel && store.listsLoading) const LinearProgressIndicator(),
      ],
      color: Colors.teal,
    ),
    _Group(
      'organizza',
      Icons.event_note_outlined,
      tr('Agenda e calendario', 'Planner and calendar'),
      '${store.agendaFrom(DateTime.now()).length} cose in agenda · ${store.countdowns.length} conti alla rovescia',
      [
        _Item(Icons.event_note_rounded, 'Agenda', 'Compiti, verifiche, interrogazioni', () => openAgenda(context),
            keywords: 'compiti verifiche'),
        _Item(Icons.calendar_month_outlined, tr('Calendario del mese', 'Monthly calendar'), 'Tutto in un colpo d\'occhio',
            () => openMonth(context)),
        _Item(Icons.hourglass_top_rounded, tr('Conti alla rovescia', 'Countdowns'),
            store.countdowns.isEmpty ? 'Gita, compleanno…' : '${store.countdowns.length} in corso', () => openCountdowns(context),
            keywords: 'gita compleanno'),
      ],
      color: Colors.pink,
    ),
    _Group(
      'notifiche',
      Icons.notifications_active_outlined,
      tr('Notifiche', 'Notifications'),
      android ? _notifySummary(store) : 'Sul telefono Android',
      [
        if (android) ...[
          _Item(Icons.notifications_active_outlined, tr('Notifiche', 'Notifications'), _notifySummary(store),
              () => openNotifications(context),
              keywords: 'lezione riepilogo sera buongiorno ricreazione compiti piano studio vacanze'),
          _Item(Icons.timelapse_rounded, 'Lezione in corso',
              store.opt('n.live', false)
                  ? 'Attiva: materia, aula e tempo che manca in tendina (tocca per spegnere)'
                  : 'Spenta: tocca per tenere la lezione sempre in tendina (Live Update)', () async {
            final on = !store.opt('n.live', false);
            if (on && !await NativeBridge.notificationsAllowed()) await NativeBridge.requestNotificationPermission();
            await store.setOpt('n.live', on);
            NativeBridge.scheduleSync(store);
          }, keywords: 'live update notifica fissa barra stato lezione adesso'),
          _Item(Icons.do_not_disturb_on_outlined, 'Silenzioso a scuola',
              store.opt('silence', false) ? 'Attivo' : 'Non disturbare durante le lezioni', () => openNotifications(context),
              keywords: 'non disturbare silenzio'),
          _Item(Icons.notifications_paused_outlined, 'Impostazioni di Android',
              'Suono e importanza di ogni tipo di notifica', () => NativeBridge.openNotificationSettings(),
              keywords: 'canali suono vibrazione'),
        ],
      ],
      extra: [
        if (!android)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text('Le notifiche si impostano dall\'app Android. Su Windows arrivano le stesse mentre l\'app è aperta.'),
          ),
      ],
      color: Colors.orange,
    ),
    _Group(
      'dati',
      Icons.save_alt_rounded,
      tr('Dati e backup', 'Data and backup'),
      'Backup, backup online, QR, resoconto PDF',
      [
        _Item(Icons.save_alt_rounded, tr('Copia di sicurezza', 'Backup'), 'Copia tutto negli appunti o rimettilo su un altro dispositivo',
            () => _backupSheet(context, store), keywords: 'backup ripristina'),
        _Item(Icons.cloud_upload_outlined, tr('Backup online', 'Online backup'),
            store.accountCode == null ? 'Serve il codice Easy Lesson (facoltativo)' : 'Scegli cosa salvare sul server',
            () => openProfile(context), keywords: 'cloud server sincronizza'),
        _Item(Icons.devices_rounded, 'Sincronizzazione completa',
            CloudSync.live(store)
                ? 'Attiva: telefono, PC e web sempre uguali, cifrati (tocca per spegnere)'
                : 'Gli stessi dati su tutti i tuoi dispositivi, cifrati end-to-end', () => _toggleLiveSync(context, store),
            keywords: 'sincronizza pc telefono dispositivi uguale cloud e2e'),
        _Item(Icons.qr_code_2_rounded, tr('Condividi con un QR', 'Share with a QR'), 'Il tuo orario, il tema o i soprannomi',
            () => showShareQr(context), keywords: 'amico'),
        _Item(Icons.qr_code_scanner_rounded, tr('Importa un codice', 'Import a code'), 'Incolla il codice che ti hanno mandato',
            () => importCodeDialog(context)),
        _Item(Icons.picture_as_pdf_outlined, tr('Resoconto PDF', 'PDF report'), 'Voti, medie e assenze per i genitori',
            () => exportReport(context), keywords: 'genitori stampa'),
        _Item(Icons.delete_outline_rounded, 'Cancella orari salvati',
            '${store.favorites.length} salvati · ${store.recents.length} recenti', () => _confirmClear(context, store)),
        _Item(Icons.settings_backup_restore_rounded, 'Ripristina le opzioni',
            'Home, notifiche, lingua e accessibilità come appena installata', () => _confirmResetOptions(context, store),
            keywords: 'reset predefinite'),
      ],
      color: Colors.green,
    ),
    _Group(
      'aggiornamenti',
      Icons.system_update_outlined,
      tr('Aggiornamenti', 'Updates'),
      store.betaUpdates ? 'Canale Beta 🧪' : 'Cerca aggiornamenti, novità',
      [
        _Item(Icons.new_releases_outlined, tr('Novità', 'What\'s new'), 'Le note di ogni versione su GitHub',
            () => launchUrl(Uri.parse('https://github.com/$githubRepo/releases'), mode: LaunchMode.externalApplication),
            external: true, keywords: 'changelog versione'),
      ],
      extra: [
        const _UpdateTile(),
        if (store.betaUpdates)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 4),
            child: Text(
              '🧪 Canale Beta attivo: ricevi le versioni di prova. Si cambia dalle opzioni sviluppatore.',
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        if (android)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Avvisami delle nuove versioni'),
            subtitle: const Text('Controlla GitHub ogni qualche ora, anche ad app chiusa'),
            value: store.opt('n.updates', true),
            onChanged: (v) => store.setOpt('n.updates', v ? null : false),
          ),
        if (kIsWeb)
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.install_desktop_rounded),
            title: Text('Installa come app'),
            subtitle: Text(
              'Chrome/Edge: icona di installazione nella barra degli indirizzi. '
              'iPhone: Condividi → Aggiungi alla schermata Home. Poi funziona anche offline.',
            ),
          ),
      ],
      color: Colors.deepPurple,
    ),
    _Group(
      'info',
      Icons.info_outline_rounded,
      'Info',
      'Privacy, progetto, segnala un problema',
      [
        _Item(Icons.bug_report_outlined, tr('Segnala un problema', 'Report a problem'), 'Apre una segnalazione su GitHub',
            () => launchUrl(Uri.parse('https://github.com/$githubRepo/issues/new'), mode: LaunchMode.externalApplication),
            external: true, keywords: 'bug errore idea'),
        _Item(Icons.code_rounded, 'Easy Lesson 2 su GitHub', 'Il codice di questa versione',
            () => launchUrl(Uri.parse('https://github.com/$githubRepo'), mode: LaunchMode.externalApplication), external: true),
        _Item(Icons.history_edu_rounded, 'Progetto originale su GitHub', "Easy Lesson di Daniele D'Alonzo",
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
        'Canale Beta, log, notifiche, memoria, rete',
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
  return on.isEmpty ? 'Tutte spente' : 'Attive: ${on.join(', ')}';
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
            title: const Text('Copia il backup negli appunti'),
            subtitle: const Text('Poi incollalo dove vuoi (note, chat con te stesso…)'),
            onTap: () => Navigator.pop(c, 'copy'),
          ),
          ListTile(
            leading: const Icon(Icons.paste_rounded),
            title: const Text('Ripristina dagli appunti'),
            subtitle: const Text('Sostituisce le impostazioni di questo dispositivo'),
            onTap: () => Navigator.pop(c, 'paste'),
          ),
        ],
      ),
    ),
  );
  if (choice == 'copy') {
    await Clipboard.setData(ClipboardData(text: store.backup()));
    await store.setOpt('ach.backup', true);
    messenger.showSnackBar(const SnackBar(content: Text('Backup copiato negli appunti')));
  } else if (choice == 'paste') {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    try {
      final n = await store.restore(data?.text ?? '');
      messenger.showSnackBar(SnackBar(content: Text('Ripristinate $n impostazioni')));
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
          ? 'Hai già l\'ultima versione'
          : 'Disponibile la versione ${info.version}${info.prerelease ? ' (beta)' : ''}';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!Updater.supported) {
      return const ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.system_update_outlined),
        title: Text('Aggiornamenti'),
        subtitle: Text('La versione web si aggiorna da sola: ricarica la pagina'),
      );
    }
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(_update != null ? Icons.system_update_rounded : Icons.system_update_outlined,
          color: _update != null ? Theme.of(context).colorScheme.primary : null),
      title: Text(_update != null ? 'Scarica la versione ${_update!.version}' : 'Cerca aggiornamenti'),
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
    messenger.showSnackBar(const SnackBar(content: Text('Sincronizzazione completa spenta')));
    return;
  }
  if (store.accountCode == null) {
    openProfile(context);
    messenger.showSnackBar(const SnackBar(content: Text('Prima crea (o inserisci) il codice Easy Lesson')));
    return;
  }
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      icon: const Icon(Icons.devices_rounded),
      title: const Text('Sincronizzazione completa'),
      content: const Text(
        'Orari, agenda, voti e opzioni restano uguali su tutti i dispositivi con il tuo codice '
        '(telefono, PC, web). Le parti personali viaggiano cifrate: il server non le legge.\n\n'
        'La prima volta, se il server ha già dati di un altro dispositivo, quelli vincono sulle differenze.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annulla')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Attiva')),
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

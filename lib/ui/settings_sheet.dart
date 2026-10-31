import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models.dart';
import '../native.dart';
import '../store.dart';
import '../updater.dart';
import 'bag_page.dart';
import 'calendar_page.dart';
import 'customize_pages.dart';
import 'dev_page.dart';
import 'fun.dart';
import 'subjects_page.dart';
import 'theme.dart';
import 'themes_page.dart';
import 'widgets.dart';

const _privacyUrl = 'https://easy-lesson.web.app/EasyLesson_PrivacyPolicy.html';
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

Future<void> showSettingsSheet(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (_) => const SettingsSheet(),
    );

class SettingsSheet extends StatelessWidget {
  const SettingsSheet({super.key});

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

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final theme = Theme.of(context);

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
                    Text('Easy Lesson', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                    Text(
                      "L'orario delle lezioni, sempre in tasca",
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SectionLabel('Aspetto'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.palette_outlined, color: theme.colorScheme.primary),
            title: const Text('Tema'),
            subtitle: Text(themeById(store.themeId).name),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => openThemesPage(context),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.emoji_emotions_outlined, color: theme.colorScheme.primary),
            title: const Text('Soprannomi ed emoji'),
            subtitle: Text(nicknames.isEmpty && subjectEmojis.isEmpty
                ? 'Chiama le materie e i prof come vuoi tu'
                : '${{...nicknames.keys, ...subjectEmojis.keys}.length} nomi personalizzati'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => openNicknames(context),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.dashboard_customize_outlined, color: theme.colorScheme.primary),
            title: const Text('Home e app'),
            subtitle: const Text('Pagina iniziale, cosa vedere nella home, emoji, vibrazione'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => openHomeOptions(context),
          ),
          if (NativeBridge.supported)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.apps_rounded, color: theme.colorScheme.primary),
              title: const Text("Icona dell'app"),
              subtitle: const Text('Verde, blu, viola, rossa, nera…'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => pickAppIcon(context),
            ),
          const SectionLabel('Scuola'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.schedule_rounded, color: theme.colorScheme.primary),
            title: const Text('Orari delle campanelle'),
            subtitle: Text(store.customBells == null
                ? 'Quelli della scuola · ${store.slots.length} ore'
                : 'Scelti da te · ${store.slots.length} ore'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => openBells(context),
          ),
          if (NativeBridge.supported)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.notifications_active_outlined, color: theme.colorScheme.primary),
              title: const Text('Notifiche'),
              subtitle: Text(_notifySummary(store)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => openNotifications(context),
            ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.backpack_outlined, color: theme.colorScheme.primary),
            title: const Text('Zaino'),
            subtitle: const Text('Cosa portare domani: camice, tuta, calcolatrice…'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => openBag(context),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.event_busy_outlined, color: theme.colorScheme.primary),
            title: const Text('Calendario scolastico'),
            subtitle: Text(store.extraClosures.isEmpty
                ? 'Vacanze e feste, aggiungi i ponti della scuola'
                : 'Vacanze e feste · ${store.extraClosures.length} giorni aggiunti da te'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => openSchoolCalendar(context),
          ),
          const SectionLabel("Fonte dell'orario"),
          if (store.usingExcel) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.table_view_rounded, color: theme.colorScheme.primary),
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
                      ? IconButton(
                          tooltip: 'Riscarica',
                          onPressed: () => store.refreshLists(),
                          icon: const Icon(Icons.sync_rounded),
                        )
                      : null),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.upload_file_rounded),
              title: const Text('Importa un altro file Excel'),
              onTap: () => pickAndImportExcel(context),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.cloud_outlined),
              title: const Text('Torna al server Easy Lesson'),
              onTap: () => store.removeExcel(),
            ),
          ] else ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.cloud_done_outlined, color: theme.colorScheme.primary),
              title: const Text('Server Easy Lesson'),
              subtitle: Text(store.listsUpdatedAt == null
                  ? 'Elenchi mai scaricati'
                  : 'Elenchi aggiornati ${relativeTime(store.listsUpdatedAt!)}'),
              trailing: store.listsLoading
                  ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : IconButton(
                      tooltip: 'Aggiorna elenchi',
                      onPressed: () => store.refreshLists(),
                      icon: const Icon(Icons.sync_rounded),
                    ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.upload_file_rounded),
              title: const Text('Importa file Excel (.xlsx)'),
              subtitle: const Text("Il file dell'orario della scuola: poi funziona tutto offline"),
              onTap: () => pickAndImportExcel(context),
            ),
          ],
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.link_rounded),
            title: const Text('Scarica Excel da un link'),
            subtitle: const Text('Ideale nelle app (Android, Windows); dal browser alcuni siti lo bloccano'),
            onTap: () => askExcelUrl(context),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.badge_outlined),
            title: const Text('Materie e codici docenti'),
            subtitle: Text(
              subjectOverrides.isEmpty && teacherSubjectOverrides.isEmpty
                  ? 'Es. A026 = Matematica'
                  : '${subjectOverrides.length + teacherSubjectOverrides.length} personalizzazioni',
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SubjectsPage()),
            ),
          ),
          const SectionLabel('Dati'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.delete_outline_rounded),
            title: const Text('Cancella orari salvati'),
            subtitle: Text('${store.favorites.length} salvati · ${store.recents.length} recenti'),
            onTap: () => _confirmClear(context, store),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.save_alt_rounded),
            title: const Text('Copia di sicurezza'),
            subtitle: const Text('Copia tutte le impostazioni e i dati, o rimettili su un altro dispositivo'),
            onTap: () => _backupSheet(context, store),
          ),
          const SectionLabel('Info'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy policy'),
            trailing: const Icon(Icons.open_in_new_rounded, size: 18),
            onTap: () => launchUrl(Uri.parse(_privacyUrl), mode: LaunchMode.externalApplication),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.code_rounded),
            title: const Text('Progetto originale su GitHub'),
            subtitle: const Text("Easy Lesson di Daniele D'Alonzo"),
            trailing: const Icon(Icons.open_in_new_rounded, size: 18),
            onTap: () => launchUrl(Uri.parse(_githubUrl), mode: LaunchMode.externalApplication),
          ),
          const _UpdateTile(),
          if (Updater.supported)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Expanded(child: Text('Canale aggiornamenti')),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('Stabile')),
                      ButtonSegment(value: true, label: Text('Beta 🧪')),
                    ],
                    selected: {store.betaUpdates},
                    onSelectionChanged: (sel) => store.setBetaUpdates(sel.first),
                  ),
                ],
              ),
            ),
          if (Updater.supported && store.betaUpdates)
            Text(
              'Con Beta ricevi le versioni di prova prima degli altri: possono avere qualche difetto.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          if (store.devMode)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.science_outlined, color: theme.colorScheme.primary),
              title: const Text('Opzioni sviluppatore'),
              subtitle: const Text('Log, file Excel, esportazioni, laboratorio colori'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => openDevPage(context),
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

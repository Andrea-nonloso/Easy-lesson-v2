import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models.dart';
import '../store.dart';
import '../updater.dart';
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
          const SizedBox(height: 8),
          FutureBuilder<String>(
            future: Updater.currentVersion(),
            builder: (context, snap) => Text(
              'Versione ${snap.data ?? ''}',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
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
    final info = await Updater.check();
    if (!mounted) return;
    setState(() {
      _checking = false;
      _update = info;
      _status = info == null ? 'Hai già l\'ultima versione' : 'Disponibile la versione ${info.version}';
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

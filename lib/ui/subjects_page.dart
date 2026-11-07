import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import 'app_menu.dart';
import 'theme.dart';
import 'widgets.dart';
import '../i18n.dart';

/// Impostazioni: quale materia corrisponde a ogni codice (A026 = Matematica)
/// ed eccezioni per singolo docente.
class SubjectsPage extends StatefulWidget {
  const SubjectsPage({super.key});

  @override
  State<SubjectsPage> createState() => _SubjectsPageState();
}

class _SubjectsPageState extends State<SubjectsPage> {
  String _q = '';

  /// Restituisce null se annullato, '' per tornare al valore predefinito.
  Future<String?> _editName(String title, String initial, {String? hint, String? defaultValue}) {
    final ctrl = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(hintText: hint ?? tr('Nome della materia', 'Subject name')),
              onSubmitted: (v) => Navigator.pop(c, v),
            ),
            if (defaultValue != null) ...[
              const SizedBox(height: 12),
              Text(tr('Predefinito: $defaultValue', 'Default: $defaultValue'), style: Theme.of(c).textTheme.bodySmall),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, ''), child: Text(tr('Ripristina', 'Restore'))),
          TextButton(onPressed: () => Navigator.pop(c), child: Text(tr('Annulla', 'Cancel'))),
          FilledButton(onPressed: () => Navigator.pop(c, ctrl.text), child: Text(tr('Salva', 'Save'))),
        ],
      ),
    );
  }

  Future<void> _editCode(AppStore store, String code) async {
    final v = await _editName(
      tr('Materia del codice $code', 'Subject for code $code'),
      subjectForCode(code),
      defaultValue: subjectNames[code] ?? code,
    );
    if (v != null) await store.setCodeSubject(code, v);
  }

  Future<void> _editTeacher(AppStore store, String teacher) async {
    final code = teacherCode(teacher);
    final v = await _editName(
      tr('Materia di ${teacherLabel(teacher)}', 'Subject of ${teacherLabel(teacher)}'),
      teacherSubject(teacher) ?? '',
      defaultValue: code == null ? tr('nessuna', 'none') : tr('${subjectForCode(code)} (codice $code)', '${subjectForCode(code)} (code $code)'),
    );
    if (v != null) await store.setTeacherSubject(teacher, v);
  }

  Future<void> _addException(AppStore store) async {
    final teacher = await showDialog<String>(
      context: context,
      builder: (_) => _TeacherPicker(teachers: store.docenti),
    );
    if (teacher != null && mounted) await _editTeacher(store, teacher);
  }

  Future<void> _reset(AppStore store) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('Ripristinare tutto?', 'Reset everything?')),
        content: Text(tr('Tutte le materie tornano ai nomi predefiniti e le eccezioni vengono cancellate.', 'All subjects go back to their default names and the exceptions are deleted.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('Annulla', 'Cancel'))),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(tr('Ripristina', 'Restore'))),
        ],
      ),
    );
    if (ok == true) await store.resetSubjects();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final byCode = store.teachersByCode;
    final q = normalizeSearch(_q);

    // Codici nel file prima (con numero di docenti), poi quelli predefiniti non usati.
    final codes = {...byCode.keys, ...subjectNames.keys, ...subjectOverrides.keys}.toList()
      ..sort((a, b) {
        final ua = byCode.containsKey(a), ub = byCode.containsKey(b);
        if (ua != ub) return ua ? -1 : 1;
        return a.compareTo(b);
      });
    bool match(String code) =>
        q.isEmpty ||
        normalizeSearch(code).contains(q) ||
        normalizeSearch(subjectForCode(code)).contains(q) ||
        (byCode[code] ?? const []).any((t) => normalizeSearch(t).contains(q));
    final exceptions = teacherSubjectOverrides.keys.toList()
      ..sort((a, b) => teacherLabel(a).compareTo(teacherLabel(b)));

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Materie e codici', 'Subjects and codes')),
        actions: [
          const AppMenuButton(),
          IconButton(
            tooltip: tr('Ripristina predefiniti', 'Restore defaults'),
            onPressed: subjectOverrides.isEmpty && teacherSubjectOverrides.isEmpty ? null : () => _reset(store),
            icon: const Icon(Icons.restart_alt_rounded),
          ),
        ],
      ),
      floatingActionButton: store.docenti.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _addException(store),
              icon: const Icon(Icons.person_add_alt_rounded),
              label: Text(tr('Eccezione docente', 'Teacher exception')),
            ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
            children: [
              Text(
                tr('Nel file Excel ogni docente ha un codice (es. "A026 Rossi"). '
                'Qui scegli quale materia mostrare per ogni codice, oppure dai a un singolo '
                'docente una materia diversa.', 'In the Excel file each teacher has a code (e.g. "A026 Rossi"). Here you choose which subject to show for each code, or give a single teacher a different subject.'),
                style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              TextField(
                onChanged: (v) => setState(() => _q = v),
                decoration: InputDecoration(
                  hintText: tr('Cerca codice, materia o docente', 'Search code, subject or teacher'),
                  prefixIcon: const Icon(Icons.search_rounded),
                ),
              ),
              if (exceptions.isNotEmpty) ...[
                SectionLabel(tr('Eccezioni per docente', 'Exceptions per teacher')),
                for (final t in exceptions)
                  if (q.isEmpty || normalizeSearch(t).contains(q))
                    _Tile(
                      leading: teacherLabel(t).isEmpty ? '?' : teacherLabel(t)[0].toUpperCase(),
                      colorKey: teacherSubjectOverrides[t]!,
                      title: teacherLabel(t),
                      subtitle: teacherSubjectOverrides[t]!,
                      onTap: () => _editTeacher(store, t),
                      onDelete: () => store.setTeacherSubject(t, null),
                    ),
              ],
              SectionLabel(tr('Codici materia', 'Subject codes')),
              for (final code in codes)
                if (match(code))
                  _Tile(
                    leading: code.replaceAll('_', ''),
                    colorKey: subjectForCode(code),
                    title: subjectForCode(code),
                    subtitle: [
                      code,
                      if (byCode[code] != null)
                        '${byCode[code]!.length} docenti: ${byCode[code]!.take(4).map(teacherLabel).join(', ')}'
                            '${byCode[code]!.length > 4 ? '…' : ''}'
                      else
                        tr('non presente nel file', 'not in the file'),
                    ].join(' · '),
                    modified: subjectOverrides.containsKey(code),
                    onTap: () => _editCode(store, code),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.leading,
    required this.colorKey,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.modified = false,
    this.onDelete,
  });

  final String leading;
  final String colorKey;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool modified;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = SubjectColors.of(colorKey, theme.brightness);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: cardColor(context),
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          leading: Container(
            width: 52,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(12)),
            child: Text(
              leading,
              style: TextStyle(color: c.fg, fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
          title: Row(
            children: [
              Flexible(child: Text(title, overflow: TextOverflow.ellipsis)),
              if (modified) ...[
                const SizedBox(width: 8),
                Icon(Icons.edit_rounded, size: 14, color: theme.colorScheme.primary),
              ],
            ],
          ),
          subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
          trailing: onDelete != null
              ? IconButton(
                  tooltip: tr('Rimuovi eccezione', 'Remove exception'),
                  onPressed: onDelete,
                  icon: const Icon(Icons.close_rounded),
                )
              : const Icon(Icons.chevron_right_rounded),
          onTap: onTap,
        ),
      ),
    );
  }
}

class _TeacherPicker extends StatefulWidget {
  const _TeacherPicker({required this.teachers});

  final List<String> teachers;

  @override
  State<_TeacherPicker> createState() => _TeacherPickerState();
}

class _TeacherPickerState extends State<_TeacherPicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = normalizeSearch(_q);
    final list = widget.teachers.where((t) => q.isEmpty || normalizeSearch(t).contains(q)).toList();
    return AlertDialog(
      title: Text(tr('Scegli il docente', 'Choose the teacher')),
      contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      content: SizedBox(
        width: 420,
        height: 460,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _q = v),
              decoration: InputDecoration(
                hintText: tr('Cerca…', 'Search…'),
                prefixIcon: const Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: list.length,
                itemBuilder: (context, i) => ListTile(
                  dense: true,
                  title: Text(teacherLabel(list[i])),
                  subtitle: Text([teacherCode(list[i]), teacherSubject(list[i])].whereType<String>().join(' · ')),
                  onTap: () => Navigator.pop(context, list[i]),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('Annulla', 'Cancel'))),
      ],
    );
  }
}

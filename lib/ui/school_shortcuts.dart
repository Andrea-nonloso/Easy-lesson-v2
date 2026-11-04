import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../school_life.dart';
import '../store.dart';
import 'agenda_page.dart';
import 'bag_page.dart';
import 'more_pages.dart';
import 'photos_page.dart';
import 'school_life_pages.dart';

// 3.6: gli strumenti della scuola non stanno più nelle impostazioni, ma in una riga di pulsanti tondi
// in home (sotto il saluto). L'utente sceglie quali e in che ordine; "Altro" apre l'elenco completo.

class SchoolTool {
  const SchoolTool(this.id, this.icon, this.label, this.open, {this.badge, this.color});
  final String id;
  final IconData icon;
  final String label;
  final void Function(BuildContext context) open;

  /// Testo piccolo sul pulsante (es. la media), o null.
  final String? Function(AppStore store)? badge;
  final Color? color;
}

/// Opzione con gli id scelti, in ordine.
const kSchoolShortcutsOpt = 'home.school';
const defaultSchoolShortcuts = ['voti', 'assenze'];

String? _gradesBadge(AppStore s) {
  final by = <String, List<Grade>>{};
  for (final g in s.grades) {
    (by[g.subject] ??= []).add(g);
  }
  if (by.isEmpty) return null;
  final avgs = [for (final l in by.values) average(l)!];
  final v = avgs.reduce((a, b) => a + b) / avgs.length;
  return v.toStringAsFixed(v >= 10 ? 0 : 1).replaceAll('.', ',');
}

String? _absencesBadge(AppStore s) {
  final ref = s.myMainRef;
  final week = ref == null ? null : s.cached(ref)?.week;
  if (week == null || s.absences.isEmpty) return null;
  final st = absenceStats(s.absences, week, DateTime.now());
  if (st.yearHours == 0) return null;
  // Quanto del limite del 25% è già usato.
  return '${(st.ratio / absenceLimit * 100).round()}%';
}

/// Tutti gli strumenti, nell'ordine dell'elenco completo.
List<SchoolTool> schoolTools() => [
      const SchoolTool('voti', Icons.grade_rounded, 'Voti', openGrades, badge: _gradesBadge, color: Colors.amber),
      const SchoolTool('assenze', Icons.event_busy_rounded, 'Assenze', openAbsences, badge: _absencesBadge, color: Colors.redAccent),
      SchoolTool('agenda', Icons.event_note_rounded, 'Agenda', openAgenda, badge: (s) {
        final n = s.agendaFrom(DateTime.now()).length;
        return n == 0 ? null : '$n';
      }, color: Colors.teal),
      SchoolTool('timer', Icons.timer_rounded, 'Timer', (c) => openStudyTimer(c), color: Colors.deepOrange),
      const SchoolTool('zaino', Icons.backpack_rounded, 'Zaino', openBag, color: Colors.brown),
      const SchoolTool('prof', Icons.contact_mail_rounded, 'Prof', openTeachers, color: Colors.indigo),
      const SchoolTool('libri', Icons.library_books_rounded, 'Libri', openMaterials, color: Colors.blueGrey),
      if (!kIsWeb) SchoolTool('foto', Icons.photo_library_rounded, 'Foto', (c) => openPhotos(c), color: Colors.purple),
      const SchoolTool('piano', Icons.menu_book_rounded, 'Piano di studio', openStudyPlan, color: Colors.green),
      SchoolTool('verifica', Icons.hourglass_bottom_rounded, 'Modalità verifica', (c) => openExamMode(c), color: Colors.pink),
      const SchoolTool('grafici', Icons.show_chart_rounded, 'Grafici', openCharts, color: Colors.cyan),
      const SchoolTool('crediti', Icons.workspace_premium_rounded, 'Crediti', openCredits, color: Colors.orange),
      const SchoolTool('conti', Icons.hourglass_top_rounded, 'Conti alla rovescia', openCountdowns, color: Colors.lightBlue),
      const SchoolTool('mese', Icons.calendar_month_rounded, 'Calendario', openMonth, color: Colors.lime),
    ];

/// Gli strumenti scelti per la riga (quelli che non esistono più si saltano).
List<SchoolTool> chosenSchoolTools(AppStore store) {
  final all = {for (final t in schoolTools()) t.id: t};
  final raw = store.opt<List<dynamic>?>(kSchoolShortcutsOpt, null);
  final ids = raw == null ? defaultSchoolShortcuts : [for (final x in raw) '$x'];
  return [for (final id in ids) if (all[id] != null) all[id]!];
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.label, required this.onTap, this.onLongPress, this.badge, this.color});
  final IconData icon;
  final String label;
  final String? badge;
  final Color? color;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = color ?? scheme.primary;
    return Semantics(
      button: true,
      label: badge == null ? label : '$label, $badge',
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        onLongPress: onLongPress,
        child: SizedBox(
          width: 74,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Stack(clipBehavior: Clip.none, children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Color.alphaBlend(c.withValues(alpha: 0.18), scheme.surface)),
                  child: Icon(icon, color: c, size: 26),
                ),
                if (badge != null)
                  Positioned(
                    right: -8,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: scheme.inverseSurface, borderRadius: BorderRadius.circular(10)),
                      child: Text(badge!, style: TextStyle(color: scheme.onInverseSurface, fontSize: 11, fontWeight: FontWeight.w800)),
                    ),
                  ),
              ]),
              const SizedBox(height: 4),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// La riga in home. Tenendo premuto un pulsante si sceglie cosa mettere.
class SchoolShortcutsRow extends StatelessWidget {
  const SchoolShortcutsRow({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final tools = chosenSchoolTools(store);
    void edit() => editSchoolShortcuts(context);
    return SizedBox(
      height: 92,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        children: [
          for (final t in tools)
            _RoundButton(icon: t.icon, label: t.label, color: t.color, badge: t.badge?.call(store), onTap: () => t.open(context), onLongPress: edit),
          _RoundButton(icon: Icons.apps_rounded, label: 'Altro', onTap: () => openAllSchoolTools(context), onLongPress: edit),
        ],
      ),
    );
  }
}

void openAllSchoolTools(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AllSchoolToolsPage()));

/// "Altro": tutti gli strumenti della scuola.
class AllSchoolToolsPage extends StatelessWidget {
  const AllSchoolToolsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scuola'),
        actions: [
          TextButton.icon(onPressed: () => editSchoolShortcuts(context), icon: const Icon(Icons.edit_rounded), label: const Text('Riga in home')),
        ],
      ),
      body: GridView.extent(
        maxCrossAxisExtent: 110,
        padding: const EdgeInsets.all(16),
        mainAxisSpacing: 8,
        children: [
          for (final t in schoolTools())
            _RoundButton(icon: t.icon, label: t.label, color: t.color, badge: t.badge?.call(store), onTap: () => t.open(context)),
        ],
      ),
    );
  }
}

/// Scegli e ordina i pulsanti della riga (anche da Impostazioni → Home e app).
Future<void> editSchoolShortcuts(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _ShortcutsEditor(),
    );

class _ShortcutsEditor extends StatefulWidget {
  const _ShortcutsEditor();
  @override
  State<_ShortcutsEditor> createState() => _ShortcutsEditorState();
}

class _ShortcutsEditorState extends State<_ShortcutsEditor> {
  late final AppStore _store = StoreScope.read(context);
  late List<String> _on = [for (final t in chosenSchoolTools(_store)) t.id];
  late final List<SchoolTool> _all = schoolTools();

  /// Prima quelle scelte (nel loro ordine), poi le altre.
  List<SchoolTool> get _ordered => [
        for (final id in _on) _all.firstWhere((t) => t.id == id),
        for (final t in _all) if (!_on.contains(t.id)) t,
      ];

  Future<void> _save() async {
    final same = _on.length == defaultSchoolShortcuts.length && Iterable.generate(_on.length).every((i) => _on[i] == defaultSchoolShortcuts[i]);
    await _store.setOpt(kSchoolShortcutsOpt, same ? null : List<String>.of(_on));
  }

  @override
  Widget build(BuildContext context) {
    final list = _ordered;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Row(children: [
              Expanded(child: Text('Pulsanti in home', style: Theme.of(context).textTheme.titleLarge)),
              TextButton(
                onPressed: () async {
                  setState(() => _on = List.of(defaultSchoolShortcuts));
                  await _save();
                },
                child: const Text('Predefiniti'),
              ),
            ]),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text('Accendi quelli che vuoi e trascinali per cambiare l\'ordine. "Altro" c\'è sempre.'),
          ),
          Expanded(
            child: ReorderableListView.builder(
              buildDefaultDragHandles: false,
              itemCount: list.length,
              onReorderItem: (from, to) async {
                final t = list[from];
                if (!_on.contains(t.id)) return;
                setState(() {
                  _on.remove(t.id);
                  _on.insert(to.clamp(0, _on.length), t.id);
                });
                await _save();
              },
              itemBuilder: (context, i) {
                final t = list[i];
                final on = _on.contains(t.id);
                return ListTile(
                  key: ValueKey(t.id),
                  leading: Icon(t.icon, color: t.color),
                  title: Text(t.label),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    Switch(
                      value: on,
                      onChanged: (v) async {
                        setState(() => v ? _on.add(t.id) : _on.remove(t.id));
                        await _save();
                      },
                    ),
                    if (on) ReorderableDragStartListener(index: i, child: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.drag_handle_rounded))),
                  ]),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

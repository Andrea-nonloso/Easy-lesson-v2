import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../formulary.dart';
import '../i18n.dart';
import '../store.dart';
import 'widgets.dart';

// Formulario offline (3.9): formule, tavola periodica e verbi irregolari, con ricerca e preferiti.

void openFormulary(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const FormularyPage()));

const _kFav = 'form.fav';

List<String> _favs(AppStore s) => [for (final x in s.opt<List<dynamic>?>(_kFav, null) ?? const []) '$x'];

Future<void> _toggleFav(AppStore s, String id) async {
  final f = _favs(s);
  f.contains(id) ? f.remove(id) : f.add(id);
  await s.setOpt(_kFav, f.isEmpty ? null : f);
}

class FormularyPage extends StatefulWidget {
  const FormularyPage({super.key});

  @override
  State<FormularyPage> createState() => _FormularyPageState();
}

class _FormularyPageState extends State<FormularyPage> {
  final _q = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searching = _query.trim().isNotEmpty;
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr('Formulario', 'Formulas')),
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(searching ? 64 : 112),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  controller: _q,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    isDense: true,
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: searching
                        ? IconButton(
                            onPressed: () => setState(() {
                                  _q.clear();
                                  _query = '';
                                }),
                            icon: const Icon(Icons.close_rounded))
                        : null,
                    hintText: tr('Cerca: Pitagora, seno, Fe, went…', 'Search: Pythagoras, sine, Fe, went…'),
                    border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(28))),
                  ),
                ),
              ),
              if (!searching)
                TabBar(isScrollable: true, tabAlignment: TabAlignment.start, tabs: [
                  Tab(text: tr('⭐ Preferiti', '⭐ Favourites')),
                  for (final s in formulaSections) Tab(text: '${s.emoji} ${s.title}'),
                  Tab(text: tr('🧱 Tavola periodica', '🧱 Periodic table')),
                  Tab(text: tr('🇬🇧 Verbi irregolari', '🇬🇧 Irregular verbs')),
                ]),
            ]),
          ),
        ),
        body: searching
            ? _SearchResults(query: _query)
            : TabBarView(children: [
                const _Favourites(),
                for (final s in formulaSections) _SectionList(section: s),
                const _PeriodicTable(),
                const _VerbList(query: ''),
              ]),
      ),
    );
  }
}

Widget _list(List<Widget> children) => Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 48), children: children),
      ),
    );

class _FormulaTile extends StatelessWidget {
  const _FormulaTile(this.f);
  final Formula f;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final fav = _favs(store).contains(f.id);
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onLongPress: () {
          Clipboard.setData(ClipboardData(text: '${f.title}: ${f.text}'));
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Copiata', 'Copied'))));
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 4, 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(f.title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                SelectableText(f.text, style: theme.textTheme.bodyLarge?.copyWith(height: 1.5)),
                if (f.note.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(f.note, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ],
              ]),
            ),
            IconButton(
              tooltip: fav ? tr('Togli dai preferiti', 'Remove from favourites') : tr('Aggiungi ai preferiti', 'Add to favourites'),
              onPressed: () => _toggleFav(store, f.id),
              icon: Icon(fav ? Icons.star_rounded : Icons.star_outline_rounded, color: fav ? Colors.amber : null),
            ),
          ]),
        ),
      ),
    );
  }
}

class _SectionList extends StatelessWidget {
  const _SectionList({required this.section});
  final FormulaSection section;

  @override
  Widget build(BuildContext context) => _list([
        for (final (id, it, en) in section.groups) ...[
          SectionLabel(tr(it, en)),
          for (final f in formulas.where((f) => f.group == id)) _FormulaTile(f),
        ],
      ]);
}

class _Favourites extends StatelessWidget {
  const _Favourites();

  @override
  Widget build(BuildContext context) {
    final favs = _favs(StoreScope.of(context));
    final list = [for (final f in formulas) if (favs.contains(f.id)) f];
    if (list.isEmpty) {
      return EmptyState(
        icon: Icons.star_outline_rounded,
        title: tr('Nessun preferito', 'No favourites'),
        message: tr('Tocca la stellina accanto a una formula per tenerla qui, a portata di verifica.',
            'Tap the star next to a formula to keep it here, ready for your test.'),
      );
    }
    return _list([for (final f in list) _FormulaTile(f)]);
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({required this.query});
  final String query;

  @override
  Widget build(BuildContext context) {
    final fs = searchFormulas(query);
    final es = searchElements(query);
    final vs = searchVerbs(query);
    if (fs.isEmpty && es.isEmpty && vs.isEmpty) {
      return EmptyState(icon: Icons.search_off_rounded, title: tr('Niente', 'Nothing'), message: tr('Prova con un\'altra parola.', 'Try another word.'));
    }
    return _list([
      if (es.isNotEmpty) ...[
        SectionLabel(tr('Elementi', 'Elements')),
        for (final e in es.take(12))
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: _ElementCell(e, size: 44),
            title: Text(e.name),
            subtitle: Text('Z = ${e.z} · ${tr('massa', 'mass')} ${_mass(e.mass)} u · ${elementKindName(e.kind)}'),
          ),
      ],
      if (fs.isNotEmpty) ...[
        SectionLabel(tr('Formule', 'Formulas')),
        for (final f in fs) _FormulaTile(f),
      ],
      if (vs.isNotEmpty) ...[
        SectionLabel(tr('Verbi irregolari', 'Irregular verbs')),
        for (final v in vs.take(30)) _verbTile(context, v),
      ],
    ]);
  }
}

String _mass(double m) => m == m.roundToDouble() && m > 96 ? '(${m.toInt()})' : m.toStringAsFixed(m < 100 ? 3 : 2);

Color _kindColor(String k, Brightness b) {
  final c = switch (k) {
    'am' => Colors.red,
    'at' => Colors.orange,
    'tr' => Colors.amber,
    'pt' => Colors.teal,
    'sm' => Colors.lightGreen,
    'nm' => Colors.green,
    'al' => Colors.cyan,
    'ng' => Colors.indigo,
    'la' => Colors.pink,
    'ac' => Colors.purple,
    _ => Colors.grey,
  };
  return b == Brightness.dark ? c.withAlpha(110) : c.withAlpha(70);
}

class _ElementCell extends StatelessWidget {
  const _ElementCell(this.e, {this.size = 46, this.onTap});
  final ChemElement e;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: _kindColor(e.kind, theme.brightness),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('${e.z}', style: const TextStyle(fontSize: 9)),
            Text(e.symbol, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ]),
        ),
      ),
    );
  }
}

class _PeriodicTable extends StatelessWidget {
  const _PeriodicTable();

  void _show(BuildContext context, ChemElement e) => showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          icon: _ElementCell(e, size: 72),
          title: Text(e.name),
          content: Text([
            '${tr('Numero atomico', 'Atomic number')}: ${e.z}',
            '${tr('Massa atomica', 'Atomic mass')}: ${_mass(e.mass)} u',
            '${tr('Gruppo', 'Group')}: ${e.row >= 8 ? '3' : '${e.col}'} · ${tr('Periodo', 'Period')}: ${e.row == 8 ? 6 : e.row == 9 ? 7 : e.row}',
            elementKindName(e.kind),
          ].join('\n')),
          actions: [TextButton(onPressed: () => Navigator.pop(c), child: Text(tr('Chiudi', 'Close')))],
        ),
      );

  @override
  Widget build(BuildContext context) {
    const cell = 46.0;
    const gap = 2.0;
    final byPos = {for (final e in elements) (e.row, e.col): e};
    Widget row(int r) => Row(mainAxisSize: MainAxisSize.min, children: [
          for (var c = 1; c <= 18; c++)
            Padding(
              padding: const EdgeInsets.all(gap / 2),
              child: byPos[(r, c)] == null
                  ? const SizedBox(width: cell, height: cell)
                  : _ElementCell(byPos[(r, c)]!, size: cell, onTap: () => _show(context, byPos[(r, c)]!)),
            ),
        ]);
    final kinds = ['am', 'at', 'tr', 'pt', 'sm', 'nm', 'al', 'ng', 'la', 'ac'];
    final b = Theme.of(context).brightness;
    return ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 48), children: [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (var r = 1; r <= 7; r++) row(r),
          const SizedBox(height: 12),
          row(8),
          row(9),
        ]),
      ),
      const SizedBox(height: 16),
      Wrap(spacing: 8, runSpacing: 6, children: [
        for (final k in kinds)
          Chip(
            visualDensity: VisualDensity.compact,
            avatar: CircleAvatar(backgroundColor: _kindColor(k, b)),
            label: Text(elementKindName(k)),
          ),
      ]),
      const SizedBox(height: 8),
      Text(tr('Tocca un elemento per i dettagli. Le masse tra parentesi sono degli isotopi più stabili.',
          'Tap an element for details. Masses in brackets are of the most stable isotopes.')),
    ]);
  }
}

Widget _verbTile(BuildContext context, (String, String, String, String) v) {
  final theme = Theme.of(context);
  return ListTile(
    contentPadding: EdgeInsets.zero,
    dense: true,
    title: Text.rich(TextSpan(children: [
      TextSpan(text: v.$1, style: const TextStyle(fontWeight: FontWeight.w800)),
      TextSpan(text: '   ${v.$2}   ${v.$3}'),
    ])),
    subtitle: Text(v.$4, style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
  );
}

class _VerbList extends StatelessWidget {
  const _VerbList({required this.query});
  final String query;

  @override
  Widget build(BuildContext context) => _list([
        Text(tr('Base · Past simple · Past participle', 'Base · Past simple · Past participle'),
            style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 4),
        for (final v in searchVerbs(query)) _verbTile(context, v),
      ]);
}

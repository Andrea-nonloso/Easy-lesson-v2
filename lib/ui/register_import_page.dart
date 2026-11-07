import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../register_import.dart';
import '../store.dart';
import '../i18n.dart';

/// Importa assenze, ritardi e uscite dal registro elettronico incollando il testo degli screenshot.
/// Funzione in beta: pulsante "Incolla dal registro (beta)" in Assenze e permessi.
class RegisterImportPage extends StatefulWidget {
  const RegisterImportPage({super.key});
  @override
  State<RegisterImportPage> createState() => _RegisterImportPageState();
}

class _RegisterImportPageState extends State<RegisterImportPage> {
  final _text = TextEditingController();
  List<RegisterEntry> _found = const [];
  final Set<String> _chosen = {};
  bool _onlyCounting = true;

  void _parse() {
    final store = StoreScope.read(context);
    final l = parseRegisterText(_text.text);
    setState(() {
      _found = l;
      _chosen
        ..clear()
        ..addAll([
          for (final e in l)
            if (!alreadyThere(e, store.absences) && (e.counts || !_onlyCounting)) e.key,
        ]);
    });
  }

  Future<void> _paste() async {
    final d = await Clipboard.getData(Clipboard.kTextPlain);
    final t = d?.text ?? '';
    if (t.isEmpty) return;
    // Più screenshot: si aggiunge in fondo, i doppioni si tolgono da soli.
    _text.text = _text.text.isEmpty ? t : '${_text.text}\n$t';
    _parse();
  }

  Future<void> _import() async {
    final store = StoreScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    var n = 0;
    for (final e in _found.where((e) => _chosen.contains(e.key))) {
      await store.addAbsence(date: e.date, kind: e.kind, hour: e.hour, note: e.note);
      n++;
    }
    messenger.showSnackBar(SnackBar(content: Text(tr('Aggiunte $n voci dal registro', 'Added $n entries from the register'))));
    nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    const months = ['gen', 'feb', 'mar', 'apr', 'mag', 'giu', 'lug', 'ago', 'set', 'ott', 'nov', 'dic'];
    return Scaffold(
      appBar: AppBar(title: Text(tr('Importa dal registro', 'Import from the register'))),
      floatingActionButton: _chosen.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _import,
              icon: const Icon(Icons.download_done_rounded),
              label: Text(tr('Aggiungi ${_chosen.length}', 'Add ${_chosen.length}')),
            ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                tr('1. Fai lo screenshot della pagina Assenze del registro (anche più di uno, scorrendo).\n'
                '2. Aprilo in Foto → Lens → "Copia testo" (oppure, nella schermata delle app recenti, "Seleziona").\n'
                '3. Torna qui e premi "Incolla". Ripeti per ogni screenshot: i doppioni si tolgono da soli.', '1. Take a screenshot of the Absences page of the register (more than one too, scrolling).\n2. Open it in Photos → Lens → "Copy text" (or, in the recent apps screen, "Select").\n3. Come back here and press "Paste". Repeat for each screenshot: duplicates are removed automatically.'),
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            FilledButton.icon(onPressed: _paste, icon: const Icon(Icons.content_paste_rounded), label: Text(tr('Incolla', 'Paste'))),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {
                _text.clear();
                _parse();
              },
              child: Text(tr('Svuota', 'Clear')),
            ),
          ]),
          const SizedBox(height: 8),
          TextField(
            controller: _text,
            minLines: 3,
            maxLines: 8,
            onChanged: (_) => _parse(),
            decoration: InputDecoration(labelText: tr('Testo del registro', 'Register text'), border: const OutlineInputBorder()),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(tr('Solo quelle che "concorrono al calcolo"', 'Only those that "count towards the total"')),
            subtitle: Text(tr('Le altre (es. ritardi giustificati) restano fuori, come nel registro', 'The others (e.g. justified late arrivals) stay out, as in the register')),
            value: _onlyCounting,
            onChanged: (v) {
              _onlyCounting = v;
              _parse();
            },
          ),
          if (_found.isNotEmpty) ...[
            Text(tr('Trovate ${_found.length}', 'Found ${_found.length}'), style: Theme.of(context).textTheme.titleMedium),
            for (final e in _found)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _chosen.contains(e.key),
                onChanged: (v) => setState(() => v == true ? _chosen.add(e.key) : _chosen.remove(e.key)),
                title: Text('${e.date.day} ${months[e.date.month - 1]} · ${e.label}'),
                subtitle: Text([
                  if (!e.counts) tr('non concorre al calcolo', 'doesn\'t count towards the total'),
                  if (alreadyThere(e, store.absences)) tr('c\'è già in Easy Lesson', 'already in Easy Lesson'),
                ].join(' · ')),
              ),
          ],
        ],
      ),
    );
  }
}

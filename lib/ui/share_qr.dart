import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models.dart';
import '../store.dart';
import 'code_scanner.dart';
import 'color_lab.dart' show applyThemeCode, themeCodeOf;

/// Condivisione con il QR: il codice è un link easylesson://import?d=...
/// La fotocamera del telefono lo riconosce e apre l'app (Android);
/// altrimenti si copia il testo e lo si incolla in "Importa un codice".

const _prefix = 'easylesson://import?d=';

String _encode(Map<String, Object?> data) => '$_prefix${base64Url.encode(utf8.encode(jsonEncode(data)))}';

Map<String, dynamic>? decodeShare(String text) {
  try {
    var t = text.trim();
    final i = t.indexOf('d=');
    if (t.startsWith('easylesson://') && i >= 0) t = t.substring(i + 2);
    t = Uri.decodeComponent(t);
    final pad = (4 - t.length % 4) % 4;
    return Map<String, dynamic>.from(jsonDecode(utf8.decode(base64Url.decode(t + '=' * pad))) as Map);
  } catch (_) {
    return null;
  }
}

/// Cosa si può condividere: (chiave, titolo, contenuto).
List<(String, String, String)> shareOptions(AppStore store) {
  final mine = store.myMainRef;
  final backup = store.backup();
  return [
    if (mine != null) ('orario', 'Il mio orario (${mine.displayName})', _encode({'k': 'orario', 'r': mine.key})),
    ('tema', 'Il mio tema', _encode({'k': 'tema', 'c': themeCodeOf(store)})),
    if (nicknames.isNotEmpty || subjectEmojis.isNotEmpty)
      ('nick', 'Soprannomi ed emoji', _encode({'k': 'nick', 'n': nicknames, 'e': subjectEmojis})),
    if (backup.length < 2200) ('backup', 'Tutto (backup)', _encode({'k': 'backup', 'b': backup})),
  ];
}

Future<void> showShareQr(BuildContext context) async {
  final store = StoreScope.read(context);
  final options = shareOptions(store);
  await store.setOpt('ach.qr', true);
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 520),
    builder: (c) => _ShareSheet(options: options),
  );
}

class _ShareSheet extends StatefulWidget {
  const _ShareSheet({required this.options});
  final List<(String, String, String)> options;

  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  int _i = 0;

  @override
  Widget build(BuildContext context) {
    final o = widget.options[_i];
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        children: [
          Text('Condividi con un QR', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              for (var i = 0; i < widget.options.length; i++)
                ChoiceChip(
                  label: Text(widget.options[i].$2),
                  selected: _i == i,
                  onSelected: (_) => setState(() => _i = i),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: QrImageView(data: o.$3, size: 260, backgroundColor: Colors.white),
          ),
          const SizedBox(height: 12),
          const Text(
            'Il tuo amico lo inquadra con la fotocamera del telefono (con Easy Lesson installata) '
            'oppure copia il codice e lo incolla in Impostazioni → Importa un codice.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: o.$3));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Codice copiato')));
            },
            icon: const Icon(Icons.copy_rounded),
            label: const Text('Copia il codice'),
          ),
        ],
      ),
    );
  }
}

/// Cosa farebbe un codice condiviso, detto all'utente prima di applicarlo (null = non valido).
/// [risky] = cambia molte cose (un backup): si chiede sempre conferma.
({String title, String text, bool risky})? describeShared(String text) {
  final m = decodeShare(text);
  if (m == null) return null;
  switch (m['k']) {
    case 'orario':
      final ref = ScheduleRef.fromKey('${m['r']}');
      if (ref == null) return null;
      return (title: 'Salvare un orario?', text: 'Verrà salvato l\'orario di ${ref.displayName}.', risky: false);
    case 'tema':
      return (title: 'Applicare un tema?', text: 'Il tema dell\'app cambierà con quello condiviso.', risky: false);
    case 'nick':
      final n = (m['n'] as Map?)?.length ?? 0;
      final e = (m['e'] as Map?)?.length ?? 0;
      return (title: 'Importare i soprannomi?', text: 'Soprannomi ed emoji delle materie ($n + $e) verranno sostituiti.', risky: false);
    case 'backup':
      return (
        title: 'Ripristinare un backup?',
        text: 'Orari, agenda, voti, assenze e impostazioni di questo dispositivo verranno sostituiti con quelli '
            'del backup. Fallo solo se il backup è tuo. Account, server e opzioni del dispositivo non cambiano.',
        risky: true,
      );
  }
  return (title: 'Codice sconosciuto', text: 'Codice di una versione più nuova: aggiorna l\'app.', risky: false);
}

/// Mostra cosa farà il codice e lo applica solo dopo "Importa" (sicurezza EL-01: un link
/// esterno non cambia niente da solo). [onlyRisky] = chiede solo per i backup (codice incollato a mano).
Future<void> confirmAndImport(BuildContext context, String text, {bool onlyRisky = false}) async {
  final store = StoreScope.read(context);
  final messenger = ScaffoldMessenger.of(context);
  final d = describeShared(text);
  if (d == null) {
    messenger.showSnackBar(const SnackBar(content: Text('Codice non valido')));
    return;
  }
  if (!onlyRisky || d.risky) {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        icon: Icon(d.risky ? Icons.warning_amber_rounded : Icons.download_rounded),
        title: Text(d.title),
        content: Text(d.text),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annulla')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Importa')),
        ],
      ),
    );
    if (ok != true) return;
  }
  try {
    messenger.showSnackBar(SnackBar(content: Text(await importShared(store, text))));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e is FormatException ? e.message : '$e')));
  }
}

/// Applica un codice condiviso (dal QR o incollato). Restituisce cosa è stato importato.
/// L'interfaccia passa da [confirmAndImport]: qui non si chiede niente.
Future<String> importShared(AppStore store, String text) async {
  final m = decodeShare(text);
  if (m == null) throw const FormatException('Codice non valido');
  switch (m['k']) {
    case 'orario':
      final ref = ScheduleRef.fromKey('${m['r']}');
      if (ref == null) throw const FormatException('Codice non valido');
      await store.fetchSchedule(ref);
      if (!(store.cached(ref)?.favorite ?? true)) await store.toggleFavorite(ref);
      return 'Orario di ${ref.displayName} salvato';
    case 'tema':
      if (!await applyThemeCode(store, '${m['c']}')) throw const FormatException('Tema non valido');
      return 'Tema applicato 🎨';
    case 'nick':
      final n = Map<String, String>.from(m['n'] as Map? ?? const {});
      final e = Map<String, String>.from(m['e'] as Map? ?? const {});
      for (final k in {...n.keys, ...e.keys}) {
        await store.setNickname(k, name: n[k] ?? '', emoji: e[k] ?? '');
      }
      return '${{...n.keys, ...e.keys}.length} soprannomi importati';
    case 'backup':
      final c = await store.restore('${m['b']}');
      return 'Backup ripristinato ($c impostazioni)';
  }
  throw const FormatException('Codice di una versione più nuova: aggiorna l\'app');
}

/// Dialogo "Importa un codice" (per chi non può inquadrare il QR).
Future<void> importCodeDialog(BuildContext context) async {
  final clip = await Clipboard.getData(Clipboard.kTextPlain);
  final ctrl = TextEditingController(text: (clip?.text ?? '').startsWith('easylesson://') ? clip!.text : '');
  if (!context.mounted) return;
  final v = await showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Importa un codice'),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        maxLines: 3,
        decoration: InputDecoration(
          hintText: 'easylesson://import?d=…',
          suffixIcon: qrScannerSupported
              ? IconButton(
                  tooltip: 'Scansiona il QR',
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  onPressed: () async {
                    final v = await scanQr(c);
                    if (v != null) ctrl.text = v;
                  },
                )
              : null,
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annulla')),
        FilledButton(onPressed: () => Navigator.pop(c, ctrl.text), child: const Text('Importa')),
      ],
    ),
  );
  if (v == null || v.trim().isEmpty || !context.mounted) return;
  await confirmAndImport(context, v, onlyRisky: true);
}

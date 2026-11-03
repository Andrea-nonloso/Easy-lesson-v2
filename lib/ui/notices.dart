import 'package:flutter/material.dart';

import '../cloud.dart';
import '../log.dart';
import '../social.dart';
import '../store.dart';

/// Avvisi della moderazione (3.0): li manda Andrea dall'app "Easy Lesson Moderazione".
/// Si mostrano uno alla volta, finché non si preme "Ho capito". Si può contestare solo con motivi fissi.
class ModNotices {
  ModNotices._();
  static bool _showing = false;
  static DateTime? _lastCheck;

  /// All'avvio e quando si torna nell'app (al massimo ogni 10 minuti), solo con account e soprannome.
  static Future<void> check(BuildContext context, {bool force = false}) async {
    final store = StoreScope.read(context);
    if (_showing || store.accountCode == null || store.opt<String?>('social.nick', null) == null) return;
    if (!force && _lastCheck != null && DateTime.now().difference(_lastCheck!) < const Duration(minutes: 10)) return;
    _lastCheck = DateTime.now();
    try {
      final (list, reasons) = await Social.notices(store);
      for (final n in list.reversed.where((n) => !n.read)) {
        if (!context.mounted) return;
        _showing = true;
        await _show(context, store, n, reasons);
        _showing = false;
      }
    } on CloudException catch (e) {
      AppLog.w('moderazione', 'Avvisi non scaricati: ${e.message}');
    } finally {
      _showing = false;
    }
  }

  static (IconData, String) style(String level) => switch (level) {
        'warning' => (Icons.warning_amber_rounded, 'Avviso'),
        'final' => (Icons.report_gmailerrorred_rounded, 'Ultimo avviso'),
        'suspension' => (Icons.block_rounded, 'Sospensione'),
        _ => (Icons.info_outline_rounded, 'Messaggio della moderazione'),
      };

  static Future<void> _show(BuildContext context, AppStore store, ModNotice n, Map<String, String> reasons) async {
    final scheme = Theme.of(context).colorScheme;
    final (icon, label) = style(n.level);
    final answered = n.appeal == 'accepted' || n.appeal == 'rejected';
    final action = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        icon: Icon(icon, size: 36, color: n.level == 'info' ? scheme.primary : scheme.error),
        title: Text(answered ? 'Risposta alla tua contestazione' : n.title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              const SizedBox(height: 8),
              if (answered) ...[
                Text(n.reply ?? ''),
                const SizedBox(height: 12),
                Text('Avviso: ${n.title}', style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant)),
              ] else
                Text(n.body),
            ],
          ),
        ),
        actions: [
          if (n.canAppeal && !answered) TextButton(onPressed: () => Navigator.pop(c, 'appeal'), child: const Text('Non è giusto')),
          FilledButton(onPressed: () => Navigator.pop(c, 'ok'), child: const Text('Ho capito')),
        ],
      ),
    );
    if (!context.mounted) return;
    if (action == 'appeal') {
      final reason = await showDialog<String>(
        context: context,
        builder: (c) => SimpleDialog(
          title: const Text('Perché non è giusto?'),
          children: [
            for (final e in reasons.entries)
              SimpleDialogOption(onPressed: () => Navigator.pop(c, e.key), child: Text(e.value)),
            SimpleDialogOption(onPressed: () => Navigator.pop(c), child: const Text('Annulla')),
          ],
        ),
      );
      if (reason == null) {
        // Non ha scelto: si rimostra la prossima volta.
        return;
      }
      try {
        await Social.appealNotice(store, n.id, reason);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contestazione mandata: ti arriverà una risposta qui')));
        }
      } on CloudException catch (e) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
      return;
    }
    try {
      await Social.readNotice(store, n.id);
    } on CloudException catch (_) {}
  }
}

/// Elenco di tutti gli avvisi ricevuti (Classe e amici → Avvisi della moderazione).
class NoticesPage extends StatefulWidget {
  const NoticesPage({super.key});
  @override
  State<NoticesPage> createState() => _NoticesPageState();
}

class _NoticesPageState extends State<NoticesPage> {
  late Future<(List<ModNotice>, Map<String, String>)> _f = Social.notices(StoreScope.read(context));

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Avvisi della moderazione')),
      body: FutureBuilder<(List<ModNotice>, Map<String, String>)>(
        future: _f,
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('${snap.error}'));
          final list = snap.data?.$1;
          if (list == null) return const Center(child: CircularProgressIndicator());
          if (list.isEmpty) return const Center(child: Text('Nessun avviso 👍'));
          return RefreshIndicator(
            onRefresh: () async {
              setState(() => _f = Social.notices(StoreScope.read(context)));
              await _f;
            },
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                for (final n in list)
                  Card(
                    child: ListTile(
                      leading: Icon(ModNotices.style(n.level).$1, color: n.level == 'info' ? scheme.primary : scheme.error),
                      title: Text(n.title),
                      subtitle: Text([
                        n.body,
                        if (n.appeal == 'open') '⏳ Contestazione in attesa di risposta',
                        if (n.appeal == 'accepted') '✅ Contestazione accettata: ${n.reply ?? ''}',
                        if (n.appeal == 'rejected') '❌ Contestazione respinta: ${n.reply ?? ''}',
                      ].join('\n')),
                      isThreeLine: true,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

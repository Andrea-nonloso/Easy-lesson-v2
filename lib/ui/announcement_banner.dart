import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../announcements.dart';
import '../store.dart';
import '../i18n.dart';

/// Avviso dal server in cima alla home (sciopero, aggiornamento importante…).
class AnnouncementBanner extends StatelessWidget {
  const AnnouncementBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final list = Announcements.current(store);
    if (list.isEmpty) return const SizedBox.shrink();
    final a = list.first;
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg, icon) = switch (a.level) {
      'urgent' => (scheme.errorContainer, scheme.onErrorContainer, Icons.priority_high_rounded),
      'warning' => (scheme.tertiaryContainer, scheme.onTertiaryContainer, Icons.warning_amber_rounded),
      _ => (scheme.secondaryContainer, scheme.onSecondaryContainer, Icons.campaign_outlined),
    };
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _open(context, a),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
            child: Row(
              children: [
                Icon(icon, color: fg),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.title, style: TextStyle(color: fg, fontWeight: FontWeight.w700)),
                      if (a.body.isNotEmpty)
                        Text(a.body, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: fg)),
                      if (list.length > 1)
                        Text(tr('+ altri ${list.length - 1}', '+ ${list.length - 1} more'), style: TextStyle(color: fg.withValues(alpha: 0.75), fontSize: 12)),
                    ],
                  ),
                ),
                if (!a.urgent)
                  IconButton(
                    tooltip: tr('Chiudi', 'Close'),
                    icon: Icon(Icons.close_rounded, color: fg),
                    onPressed: () => Announcements.dismiss(store, a.id),
                  )
                else
                  const SizedBox(width: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Future<void> _open(BuildContext context, Announcement a) => showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(a.title),
          content: SingleChildScrollView(child: Text(a.body.isEmpty ? a.title : a.body)),
          actions: [
            if (a.link != null)
              TextButton.icon(
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: Text(tr('Apri', 'Open')),
                onPressed: () => launchUrl(Uri.parse(a.link!), mode: LaunchMode.externalApplication),
              ),
            FilledButton(onPressed: () => Navigator.pop(c), child: const Text('OK')),
          ],
        ),
      );
}

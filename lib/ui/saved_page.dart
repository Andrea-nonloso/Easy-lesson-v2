import 'package:flutter/material.dart';

import '../store.dart';
import 'app_menu.dart';
import 'search_page.dart';
import 'theme.dart';
import 'widgets.dart';
import '../i18n.dart';

class SavedPage extends StatelessWidget {
  const SavedPage({super.key, required this.onSearch});

  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final favs = store.favorites;
    final recents = store.recents;

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Salvati', 'Saved')),
        actions: [
          AppMenuButton(items: [
            AppMenuItem(Icons.search_rounded, tr('Cerca un orario', 'Search for a timetable'), onSearch),
          ]),
          const SizedBox(width: 4),
        ],
      ),
      body: favs.isEmpty && recents.isEmpty
          ? EmptyState(
              icon: Icons.bookmark_border_rounded,
              title: tr('Nessun orario salvato', 'No saved timetables'),
              message:
                  tr('Apri un orario e tocca il segnalibro: lo avrai sempre a portata di mano, anche senza connessione.', 'Open a timetable and tap the bookmark: you\'ll always have it at hand, even offline.'),
              action: FilledButton.icon(
                onPressed: onSearch,
                icon: const Icon(Icons.search_rounded),
                label: Text(tr('Cerca un orario', 'Search for a timetable')),
              ),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    if (favs.isNotEmpty) ...[
                      SectionLabel(tr('Disponibili offline', 'Available offline')),
                      for (final s in favs) _SavedTile(s, mine: store.isMine(s.ref)),
                    ],
                    if (recents.isNotEmpty) ...[
                      SectionLabel(tr('Visti di recente', 'Recently viewed')),
                      for (final s in recents) _SavedTile(s, mine: false),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}

class _SavedTile extends StatelessWidget {
  const _SavedTile(this.s, {required this.mine});

  final CachedSchedule s;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.read(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final c = SubjectColors.of(s.ref.name, theme.brightness);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: cardColor(context),
        borderRadius: BorderRadius.circular(20),
        child: ListTile(
          contentPadding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(14)),
            child: Icon(s.ref.prof ? Icons.person_rounded : Icons.groups_rounded, color: c.fg),
          ),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  s.ref.displayName,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (mine) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tr('IL MIO', 'MINE'),
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: scheme.onPrimaryContainer,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ],
            ],
          ),
          subtitle: Text(tr('${s.ref.kindLabel} · aggiornato ${relativeTime(s.updatedAt)}', '${s.ref.kindLabel} · updated ${relativeTime(s.updatedAt)}')),
          onTap: () => openSchedule(context, s.ref),
          trailing: PopupMenuButton<String>(
            onSelected: (v) {
              switch (v) {
                case 'fav':
                  store.toggleFavorite(s.ref);
                case 'mine':
                  store.setMine(mine ? null : s.ref);
                case 'del':
                  store.remove(s.ref);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'mine',
                child: Text(mine ? tr('Non è il mio orario', 'It\'s not my timetable') : tr('Imposta come mio orario', 'Set as my timetable')),
              ),
              PopupMenuItem(
                value: 'fav',
                child: Text(s.favorite ? tr('Togli dagli offline', 'Remove from offline') : tr('Salva offline', 'Save offline')),
              ),
              PopupMenuItem(value: 'del', child: Text(tr('Elimina dal dispositivo', 'Delete from the device'))),
            ],
          ),
        ),
      ),
    );
  }
}

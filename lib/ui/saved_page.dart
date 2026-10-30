import 'package:flutter/material.dart';

import '../store.dart';
import 'app_menu.dart';
import 'search_page.dart';
import 'theme.dart';
import 'widgets.dart';

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
        title: const Text('Salvati'),
        actions: [
          AppMenuButton(items: [
            AppMenuItem(Icons.search_rounded, 'Cerca un orario', onSearch),
          ]),
          const SizedBox(width: 4),
        ],
      ),
      body: favs.isEmpty && recents.isEmpty
          ? EmptyState(
              icon: Icons.bookmark_border_rounded,
              title: 'Nessun orario salvato',
              message:
                  'Apri un orario e tocca il segnalibro: lo avrai sempre a portata di mano, anche senza connessione.',
              action: FilledButton.icon(
                onPressed: onSearch,
                icon: const Icon(Icons.search_rounded),
                label: const Text('Cerca un orario'),
              ),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    if (favs.isNotEmpty) ...[
                      const SectionLabel('Disponibili offline'),
                      for (final s in favs) _SavedTile(s, mine: store.isMine(s.ref)),
                    ],
                    if (recents.isNotEmpty) ...[
                      const SectionLabel('Visti di recente'),
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
                    'IL MIO',
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
          subtitle: Text('${s.ref.kindLabel} · aggiornato ${relativeTime(s.updatedAt)}'),
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
                child: Text(mine ? 'Non è il mio orario' : 'Imposta come mio orario'),
              ),
              PopupMenuItem(
                value: 'fav',
                child: Text(s.favorite ? 'Togli dagli offline' : 'Salva offline'),
              ),
              const PopupMenuItem(value: 'del', child: Text('Elimina dal dispositivo')),
            ],
          ),
        ),
      ),
    );
  }
}

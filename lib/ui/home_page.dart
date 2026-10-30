import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import 'fun.dart';
import 'search_page.dart';
import 'settings_sheet.dart';
import 'theme.dart';
import 'widgets.dart';

/// Prima schermata dell'app: data, saluto, ricerca rapida, la lezione di
/// adesso e le scorciatoie. Stile chiaro e semplice, senza fronzoli.
class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.onSearch,
    required this.onOpenMine,
    required this.onOpenSaved,
  });

  final VoidCallback onSearch;
  final VoidCallback onOpenMine;
  final VoidCallback onOpenSaved;

  static const _months = [
    'gen', 'feb', 'mar', 'apr', 'mag', 'giu',
    'lug', 'ago', 'set', 'ott', 'nov', 'dic',
  ];

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final now = DateTime.now();

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: LayoutBuilder(
              builder: (context, box) {
                // Schermi bassi (es. portatile 1280x720): spazi piu' stretti e niente titolo "Per te".
                final tight = box.maxHeight < 620;
                final header = <Widget>[
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${dayShort[now.weekday - 1]} ${now.day} ${_months[now.month - 1]}',
                            style: theme.textTheme.labelMedium
                                ?.copyWith(color: scheme.onSurfaceVariant, letterSpacing: 0.6),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            store.username != null ? 'Ciao, ${store.username}!' : 'Ciao!',
                            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Impostazioni',
                      onPressed: () => showSettingsSheet(context),
                      icon: const Icon(Icons.tune_rounded),
                    ),
                    const SizedBox(width: 2),
                    const AppLogo(size: 38),
                  ],
                ),
                  SizedBox(height: tight ? 8 : 14),
                Material(
                  color: cardColor(context),
                  borderRadius: BorderRadius.circular(28),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(28),
                    onTap: onSearch,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      child: Row(
                        children: [
                          Icon(Icons.search_rounded, size: 20, color: scheme.onSurfaceVariant),
                          const SizedBox(width: 10),
                          Text(
                            'Cerca classe o docente…',
                            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                  _QuickSwitch(store: store, onOpenMine: onOpenMine, onSearch: onSearch),
                  SizedBox(height: tight ? 10 : 16),
                  _TodayCard(store: store, now: now, onOpenMine: onOpenMine, onSearch: onSearch),
                  SizedBox(height: tight ? 12 : 18),
                  if (!tight) ...[
                    Text('Per te', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                  ],
                ];
                Widget shortcuts(double height) {
                  // Poco spazio: i tre riquadri in fila su una riga, piu' bassi.
                  if (height < 150) {
                    return SizedBox(
                      height: height,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _ShortcutCard(
                              icon: Icons.today_rounded,
                              title: 'Il mio orario',
                              subtitle: store.myRef?.displayName ?? 'Da impostare',
                              filled: true,
                              compact: true,
                              onTap: store.myRef != null ? onOpenMine : onSearch,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ShortcutCard(
                              icon: Icons.search_rounded,
                              title: 'Cerca',
                              subtitle: 'Classi e docenti',
                              compact: true,
                              onTap: onSearch,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ShortcutCard(
                              icon: Icons.bookmark_rounded,
                              title: 'Salvati',
                              subtitle: '${store.favorites.length} offline',
                              compact: true,
                              onTap: onOpenSaved,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return SizedBox(height: height, child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 11,
                        child: _ShortcutCard(
                          icon: Icons.today_rounded,
                          title: 'Il mio orario',
                          subtitle: store.myRef?.displayName ?? 'Da impostare',
                          filled: true,
                          onTap: store.myRef != null ? onOpenMine : onSearch,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 10,
                        child: Column(
                          children: [
                            Expanded(
                              child: _ShortcutCard(
                                icon: Icons.search_rounded,
                                title: 'Cerca',
                                subtitle: 'Classi e docenti',
                                onTap: onSearch,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: _ShortcutCard(
                                icon: Icons.bookmark_rounded,
                                title: 'Salvati',
                                subtitle: '${store.favorites.length} offline',
                                onTap: onOpenSaved,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ));
                }

                // Schermo basso (es. telefono in orizzontale): si scorre come prima.
                if (box.maxHeight < 440) {
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                    children: [...header, shortcuts(168)],
                  );
                }
                // Altrimenti tutto sta in una schermata: le scorciatoie si allungano
                // fino a riempire lo spazio (max 300), e se avanza spazio
                // compaiono gli ultimi orari aperti, quanti ne entrano.
                return Padding(
                  padding: EdgeInsets.fromLTRB(20, tight ? 10 : 18, 20, tight ? 10 : 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ...header,
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, rest) {
                            // Spazio troppo poco anche cosi': le scorciatoie scorrono da sole.
                            if (rest.maxHeight < 88) {
                              return SingleChildScrollView(child: shortcuts(96));
                            }
                            // Da 150 in su: riquadri grandi (max 300); sotto: riga compatta (max 120).
                            final h = rest.maxHeight >= 150
                                ? (rest.maxHeight < 300 ? rest.maxHeight : 300.0)
                                : (rest.maxHeight < 120 ? rest.maxHeight : 120.0);
                            final spare = rest.maxHeight - h - 16;
                            final fit = spare > 60 ? ((spare - 36) / 58).floor() : 0;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                shortcuts(h),
                                if (fit > 0) ...[
                                  const SizedBox(height: 16),
                                  // Se la stima e' un po' larga, l'ultimo elemento viene tagliato
                                  // invece di uscire dallo schermo.
                                  Flexible(
                                    child: ClipRect(
                                      child: SingleChildScrollView(
                                        physics: const NeverScrollableScrollPhysics(),
                                        child: _Recents(store: store, max: fit),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// La card principale: cosa c'e' adesso (o dopo) nell'orario personale.
class _TodayCard extends StatelessWidget {
  const _TodayCard({
    required this.store,
    required this.now,
    required this.onOpenMine,
    required this.onSearch,
  });

  final AppStore store;
  final DateTime now;
  final VoidCallback onOpenMine;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ref = store.myRef;

    String overline;
    String title;
    String? subtitle;
    double? progress;
    String? place; // laboratorio della lezione di adesso / prossima
    VoidCallback onTap = onOpenMine;

    if (ref == null) {
      overline = 'INIZIA DA QUI';
      title = 'Imposta il tuo orario';
      subtitle = 'Scegli la tua classe o il tuo nome: lo troverai sempre in apertura.';
      onTap = onSearch;
    } else {
      final cached = store.cached(ref);
      if (cached == null) {
        overline = ref.displayName.toUpperCase();
        title = 'Scarica l\'orario';
        subtitle = 'Tocca qui per scaricarlo e averlo sempre con te.';
      } else {
        final days = cached.week.days;
        final ti = todayIndex(now, days.length);
        if (ti < 0 || days[ti].isEmpty) {
          overline = 'OGGI';
          title = 'Nessuna lezione oggi';
          subtitle = 'Goditi la giornata.';
        } else {
          final day = days[ti];
          final slots = store.slots;
          final n = day.lessons.length < slots.length ? day.lessons.length : slots.length;
          final m = now.hour * 60 + now.minute;
          final idx = currentSlot(slots, now);
          if (idx != null && idx < n) {
            final l = day.lessons[idx];
            final s = slots[idx];
            overline = 'ADESSO · fino alle ${s.endText}';
            title = l.isEmpty ? 'Ora libera' : l.title;
            if (l.lab.isNotEmpty) place = l.lab;
            progress = ((m - s.start!) / (s.end! - s.start!)).clamp(0.0, 1.0).toDouble();
            if (!l.isEmpty && l.details.isNotEmpty) subtitle = l.details.join(' · ');
          } else {
            int? nextIdx;
            for (var k = 0; k < n; k++) {
              if (!day.lessons[k].isEmpty && slots[k].start != null && slots[k].start! > m) {
                nextIdx = k;
                break;
              }
            }
            final lastEnd = n > 0 ? slots[n - 1].end : null;
            if (nextIdx != null) {
              overline = 'PROSSIMA · ore ${slots[nextIdx].startText}';
              title = day.lessons[nextIdx].title;
              if (day.lessons[nextIdx].lab.isNotEmpty) place = day.lessons[nextIdx].lab;
              final mins = slots[nextIdx].start! - m;
              subtitle = mins < 60 ? 'Tra $mins min' : 'Tra ${mins ~/ 60} h ${mins % 60} min';
            } else if (lastEnd != null && m >= lastEnd) {
              overline = 'OGGI';
              title = 'Lezioni finite!';
              subtitle = 'Goditi il resto della giornata.';
            } else {
              overline = 'OGGI';
              title = ref.displayName;
              subtitle = 'Tocca per vedere l\'orario di oggi.';
            }
          }
        }
      }
    }

    final onCard = scheme.onPrimary;
    return Material(
      color: scheme.primary,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                overline,
                style: TextStyle(
                  color: onCard.withAlpha(215),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(color: onCard, fontSize: 22, fontWeight: FontWeight.w700, height: 1.15),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: onCard.withAlpha(225), fontSize: 14.5),
                ),
              ],
              if (place != null) ...[
                const SizedBox(height: 10),
                PlacePill(place, color: onCard),
              ],
              if (progress != null) ...[
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    color: onCard,
                    backgroundColor: onCard.withAlpha(60),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Scorciatoia quadrata nella sezione "Per te".
class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.filled = false,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  /// true = card piena colorata (quella grande a sinistra).
  final bool filled;

  /// true = versione bassa per schermi piccoli (meno margine, icona piu' piccola).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bg = filled ? scheme.tertiaryContainer : cardColor(context);
    final fg = filled ? scheme.onTertiaryContainer : scheme.onSurface;
    final sub = filled ? scheme.onTertiaryContainer.withAlpha(190) : scheme.onSurfaceVariant;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(compact ? 12 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: fg, size: compact ? 22 : 26),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: fg),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: sub),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ultimi orari aperti, in fondo alla home.
class _Recents extends StatelessWidget {
  const _Recents({required this.store, this.max = 5});

  final AppStore store;

  /// Quanti orari mostrare (in base allo spazio libero sotto le scorciatoie).
  final int max;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final items = [...store.favorites, ...store.recents];
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('I tuoi orari', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        for (final s in items.take(max))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: cardColor(context),
              borderRadius: BorderRadius.circular(18),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: SubjectColors.of(s.ref.name, theme.brightness).bg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    s.ref.prof ? Icons.person_rounded : Icons.groups_rounded,
                    size: 22,
                    color: SubjectColors.of(s.ref.name, theme.brightness).fg,
                  ),
                ),
                title: Text(
                  s.ref.displayName,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  s.ref.kindLabel,
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
                trailing: Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
                onTap: () => openSchedule(context, s.ref),
              ),
            ),
          ),
      ],
    );
  }
}

/// Cambio rapido tra il proprio orario, quelli salvati (classi o docenti) e la ricerca.
class _QuickSwitch extends StatelessWidget {
  const _QuickSwitch({required this.store, required this.onOpenMine, required this.onSearch});

  final AppStore store;
  final VoidCallback onOpenMine;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final mine = store.myRef;
    final others = store.favorites.where((s) => mine == null || s.ref.key != mine.key).take(6).toList();
    if (mine == null && others.isEmpty) return const SizedBox.shrink();

    Widget chip(String label, IconData icon, VoidCallback onTap, {bool selected = false}) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ActionChip(
            avatar: Icon(icon, size: 18),
            label: Text(label),
            onPressed: onTap,
            side: selected ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5) : null,
          ),
        );

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SizedBox(
        height: 40,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            if (mine != null) chip(mine.displayName, Icons.home_rounded, onOpenMine, selected: true),
            for (final s in others)
              chip(
                s.ref.displayName,
                s.ref.prof ? Icons.person_rounded : Icons.groups_rounded,
                () => openSchedule(context, s.ref),
              ),
            chip('Docenti e classi', Icons.swap_horiz_rounded, onSearch),
          ],
        ),
      ),
    );
  }
}

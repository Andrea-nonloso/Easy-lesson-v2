import 'package:flutter/material.dart';

import '../store.dart';
import '../updater.dart';
import 'app_menu.dart';
import 'saved_page.dart';
import 'schedule_screen.dart';
import 'search_page.dart';
import 'settings_sheet.dart';
import 'themes_page.dart';
import 'widgets.dart';

/// Struttura principale: barra in basso su telefono, barra laterale su tablet.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _destinations = [
    (icon: Icons.today_outlined, selected: Icons.today_rounded, label: 'Il mio orario'),
    (icon: Icons.search_rounded, selected: Icons.search_rounded, label: 'Cerca'),
    (icon: Icons.bookmark_border_rounded, selected: Icons.bookmark_rounded, label: 'Salvati'),
  ];

  @override
  void initState() {
    super.initState();
    // Senza "mio orario" si parte direttamente dalla ricerca.
    if (StoreScope.read(context).myRef == null) _index = 1;
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkUpdates());
  }

  /// Android e Windows: se su GitHub c'e' una versione piu' recente, la propone.
  Future<void> _checkUpdates() async {
    if (!Updater.supported) return;
    final info = await Updater.check();
    if (info == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      duration: const Duration(seconds: 15),
      content: Text('È disponibile Easy Lesson ${info.version}'),
      action: SnackBarAction(label: 'Aggiorna', onPressed: () => Updater.open(info)),
    ));
  }

  void _go(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final body = IndexedStack(
      index: _index,
      children: [
        _MyScheduleTab(onSearch: () => _go(1)),
        const SearchPage(),
        SavedPage(onSearch: () => _go(1)),
      ],
    );

    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth >= kGridBreakpoint) {
        return Scaffold(
          body: Row(
            children: [
              SafeArea(
                right: false,
                child: NavigationRail(
                  selectedIndex: _index,
                  onDestinationSelected: _go,
                  labelType: NavigationRailLabelType.all,
                  groupAlignment: -0.9,
                  leading: const Padding(
                    padding: EdgeInsets.only(top: 8, bottom: 16),
                    child: AppLogo(size: 44),
                  ),
                  trailing: Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Column(
                      children: [
                        IconButton(
                          tooltip: 'Temi',
                          onPressed: () => openThemesPage(context),
                          icon: const Icon(Icons.palette_outlined),
                        ),
                        IconButton(
                          tooltip: 'Impostazioni',
                          onPressed: () => showSettingsSheet(context),
                          icon: const Icon(Icons.settings_outlined),
                        ),
                      ],
                    ),
                  ),
                  destinations: [
                    for (final d in _destinations)
                      NavigationRailDestination(
                        icon: Icon(d.icon),
                        selectedIcon: Icon(d.selected),
                        label: Text(d.label),
                      ),
                  ],
                ),
              ),
              Expanded(child: body),
            ],
          ),
        );
      }
      return Scaffold(
        body: body,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _go,
          destinations: [
            for (final d in _destinations)
              NavigationDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selected), label: d.label),
          ],
        ),
      );
    });
  }
}

class _MyScheduleTab extends StatelessWidget {
  const _MyScheduleTab({required this.onSearch});

  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final ref = StoreScope.of(context).myRef;
    if (ref != null) return ScheduleScreen(key: ValueKey(ref.key), ref: ref, isHome: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Easy Lesson'),
        actions: const [AppMenuButton(), SizedBox(width: 4)],
      ),
      body: EmptyState(
        icon: Icons.school_outlined,
        title: 'Ciao!',
        message:
            'Scegli la tua classe o il tuo nome e imposta "il mio orario": lo troverai sempre qui, anche senza connessione.',
        action: FilledButton.icon(
          onPressed: onSearch,
          icon: const Icon(Icons.search_rounded),
          label: const Text('Trova il tuo orario'),
        ),
      ),
    );
  }
}

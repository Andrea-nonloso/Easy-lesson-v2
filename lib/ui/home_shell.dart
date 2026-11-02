import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show timeDilation;
import 'package:flutter/services.dart';

import '../cloud.dart';
import '../i18n.dart';
import '../native.dart';
import '../store.dart';
import '../updater.dart';
import 'achievements.dart';
import 'agenda_page.dart';
import 'desktop.dart';
import 'app_menu.dart';
import 'home_page.dart';
import 'now_page.dart';
import 'profile_page.dart' show checkCodeMemory;
import 'saved_page.dart';
import 'schedule_screen.dart';
import 'school_life_pages.dart';
import 'search_page.dart';
import 'settings_sheet.dart';
import 'share_qr.dart';
import 'themes_page.dart';
import 'widgets.dart';

/// Struttura principale: barra in basso su telefono, barra laterale su tablet.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _index = 0;
  AppStore? _store;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // Pagina iniziale e opzioni sviluppatore scelte nelle impostazioni.
    final store = StoreScope.read(context);
    _index = store.opt('start.tab', 0).clamp(0, 3);
    Updater.pretendOld = store.opt('dev.fakeOld', false);
    timeDilation = store.opt('dev.slow', false) ? 5.0 : 1.0;
  }

  static List<({IconData icon, IconData selected, String label})> get _destinations => [
        (icon: Icons.home_outlined, selected: Icons.home_rounded, label: 'Home'),
        (icon: Icons.today_outlined, selected: Icons.today_rounded, label: tr('Orario', 'Timetable')),
        (icon: Icons.search_rounded, selected: Icons.search_rounded, label: tr('Cerca', 'Search')),
        (icon: Icons.bookmark_border_rounded, selected: Icons.bookmark_rounded, label: tr('Salvati', 'Saved')),
      ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _checkUpdates();
      // Android: notifiche e widget sempre allineati all'orario, scorciatoie dell'icona.
      final store = StoreScope.read(context);
      _store = store;
      store.addListener(_onStoreChanged);
      Cloud.overrideUrl = store.opt<String?>('dev.cloudUrl', null);
      CloudSync.maybeSync(store);
      // Ogni tanto: "ti ricordi il tuo codice?" (solo con l'account, vedi profile_page.dart).
      Timer(const Duration(seconds: 8), () {
        if (mounted) checkCodeMemory(context);
      });
      NativeBridge.scheduleSync(store);
      DesktopBridge.init(store);
      _checkScheduleChanges();
      _achTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) checkAchievements(context);
      });
      NativeBridge.listen(_openShortcut);
      final s = await NativeBridge.takeShortcut();
      if (s != null && mounted) _openShortcut(s);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _store?.removeListener(_onStoreChanged);
    _achTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _store != null) {
      _store!.markActive();
      CloudSync.maybeSync(_store!);
      NativeBridge.scheduleSync(_store!);
      _checkScheduleChanges();
      // Si ricontrolla GitHub quando si torna nell'app (al massimo ogni 3 ore).
      final last = Updater.lastCheck;
      if (last == null || DateTime.now().difference(last) > const Duration(hours: 3)) _checkUpdates();
    }
  }

  Timer? _achTimer;

  void _onStoreChanged() {
    if (_store != null) NativeBridge.scheduleSync(_store!);
    // Obiettivi: si controllano un attimo dopo l'ultimo cambiamento.
    _achTimer?.cancel();
    _achTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) checkAchievements(context);
    });
  }

  Future<void> _openShortcut(String s) async {
    if (!mounted) return;
    // Codice condiviso con il QR (la fotocamera apre easylesson://import?d=...).
    if (s.startsWith('easylesson://import')) {
      final messenger = ScaffoldMessenger.of(context);
      try {
        messenger.showSnackBar(SnackBar(content: Text(await importShared(StoreScope.read(context), s))));
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text(e is FormatException ? e.message : '$e')));
      }
      return;
    }
    switch (s) {
      case 'mine':
        _go(1);
      case 'prof':
        openNowAtSchool(context);
      case 'agenda':
        openAgenda(context);
      case 'grades':
        openGrades(context);
    }
  }

  /// Android e Windows: se su GitHub c'e' una versione piu' recente, la propone.
  Future<void> _checkUpdates() async {
    if (!Updater.supported) return;
    final info = await Updater.check(beta: StoreScope.read(context).betaUpdates);
    if (info == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      duration: const Duration(seconds: 15),
      content: Text('È disponibile Easy Lesson ${info.version}${info.prerelease ? ' (beta)' : ''}'),
      action: SnackBarAction(label: 'Aggiorna', onPressed: () => Updater.open(info)),
    ));
  }

  /// Riscarica il mio orario (se vecchio di 6 ore) e avvisa se è cambiato.
  Future<void> _checkScheduleChanges() async {
    final store = _store;
    if (store == null) return;
    if (await store.refreshMine()) {
      final list = store.scheduleChanges ?? const [];
      await NativeBridge.notifyNow(
        'L\'orario è cambiato! 🔄',
        list.length == 1 ? list.first : '${list.length} modifiche: ${list.take(3).join(' · ')}',
      );
      DesktopBridge.notify('L\'orario è cambiato! 🔄', list.take(3).join('\n'));
    }
  }

  void _go(int i) {
    if (i != _index && StoreScope.read(context).opt('ui.haptic', false)) HapticFeedback.selectionClick();
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    final body = IndexedStack(
      index: _index,
      children: [
        HomePage(
          onSearch: () => _go(2),
          onOpenMine: () => _go(1),
          onOpenSaved: () => _go(3),
        ),
        _MyScheduleTab(onSearch: () => _go(2)),
        const SearchPage(),
        SavedPage(onSearch: () => _go(2)),
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

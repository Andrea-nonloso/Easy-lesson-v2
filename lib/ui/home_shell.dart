import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show timeDilation;
import 'package:flutter/services.dart';

import '../announcements.dart';
import '../cloud.dart';
import '../i18n.dart';
import '../mission_engine.dart';
import '../native.dart';
import '../social.dart';
import '../store.dart';
import '../updater.dart';
import 'achievements.dart';
import 'agenda_page.dart';
import 'class_page.dart' show ClassHubPage, openSocialLink;
import 'desktop.dart';
import 'app_menu.dart';
import 'home_page.dart';
import 'notices.dart';
import 'now_page.dart';
import 'profile_page.dart' show ProfilePage, checkCodeMemory, openAccountLink;
import 'saved_page.dart';
import 'schedule_screen.dart';
import 'school_life_pages.dart';
import 'search_page.dart';
import 'share_qr.dart';
import 'themes_page.dart';
import 'widgets.dart';

/// Struttura principale (3.6): Home · Orario · Amici · Profilo.
/// Telefono: barra in basso con 4 voci; Cerca e Salvati si aprono dai pulsanti della home.
/// Schermi grandi: barra laterale con le 4 voci e, sotto un separatore, Cerca e Salvati più chiari.
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
    // 0 = Home, 1 = Il mio orario, 2 = Cerca (si apre sopra la home sul telefono).
    final start = store.opt('start.tab', 0);
    _index = start == 1 ? 1 : 0;
    if (start == 2) WidgetsBinding.instance.addPostFrameCallback((_) => _openSearch());
    Updater.pretendOld = store.opt('dev.fakeOld', false);
    timeDilation = store.opt('dev.slow', false) ? 5.0 : 1.0;
  }

  static List<({IconData icon, IconData selected, String label})> get _destinations => [
        (icon: Icons.home_outlined, selected: Icons.home_rounded, label: 'Home'),
        (icon: Icons.today_outlined, selected: Icons.today_rounded, label: tr('Orario', 'Timetable')),
        (icon: Icons.people_outline_rounded, selected: Icons.people_rounded, label: tr('Amici', 'Friends')),
        (icon: Icons.account_circle_outlined, selected: Icons.account_circle_rounded, label: tr('Profilo', 'Profile')),
      ];

  // Indici delle pagine: 0-3 le voci della barra, 4 Cerca, 5 Salvati (solo nella barra laterale).
  static const _search = 4;
  static const _saved = 5;
  bool _wide = false;

  /// Cerca: nella barra laterale è una pagina accanto; sul telefono si apre sopra.
  void _openSearch() {
    if (!mounted) return;
    if (_wide) return _go(_search);
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SearchPage()));
  }

  void _openSaved() {
    if (!mounted) return;
    if (_wide) return _go(_saved);
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SavedPage(onSearch: _openSearch)));
  }

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
      CloudSync.maybeSync(store);
      Missions.refreshEvents(store);
      Announcements.refresh(store);
      final lv = levelOf(store);
      Social.sync(store, xp: lv.xp, level: lv.level);
      // Ogni tanto: "ti ricordi il tuo codice?" (solo con l'account, vedi profile_page.dart).
      Timer(const Duration(seconds: 8), () {
        if (mounted) checkCodeMemory(context);
      });
      // Avvisi della moderazione (classe e amici).
      Timer(const Duration(seconds: 12), () {
        if (mounted) ModNotices.check(context);
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
      Announcements.refresh(_store!);
      final lv = levelOf(_store!);
      Social.sync(_store!, xp: lv.xp, level: lv.level);
      NativeBridge.scheduleSync(_store!);
      _checkScheduleChanges();
      ModNotices.check(context);
      // Si ricontrolla GitHub quando si torna nell'app (al massimo ogni 3 ore).
      final last = Updater.lastCheck;
      if (last == null || DateTime.now().difference(last) > const Duration(hours: 3)) _checkUpdates();
    }
  }

  Timer? _achTimer;

  void _onStoreChanged() {
    if (_store != null) NativeBridge.scheduleSync(_store!);
    // Sincronizzazione completa: un minuto dopo l'ultimo cambiamento.
    if (_store != null && CloudSync.live(_store!)) CloudSync.schedule(_store!, delay: const Duration(seconds: 60));
    // Obiettivi: si controllano un attimo dopo l'ultimo cambiamento.
    _achTimer?.cancel();
    _achTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) checkAchievements(context);
    });
  }

  Future<void> _openShortcut(String s) async {
    if (!mounted) return;
    // Codice condiviso con il QR (la fotocamera apre easylesson://import?d=...).
    // Sempre con conferma: il link può arrivare da chiunque (sicurezza EL-01).
    if (s.startsWith('easylesson://import')) {
      await confirmAndImport(context, s);
      return;
    }
    // QR del codice dell'account (easylesson://login?c=... / recover?r=...).
    if (s.startsWith('easylesson://login') || s.startsWith('easylesson://recover')) {
      await openAccountLink(context, s);
      return;
    }
    // 3.0: QR di una classe o di un amico.
    if (s.startsWith('easylesson://class') || s.startsWith('easylesson://friend')) {
      await openSocialLink(context, s);
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
        HomePage(onSearch: _openSearch, onOpenMine: () => _go(1), onOpenSaved: _openSaved),
        _MyScheduleTab(onSearch: _openSearch),
        const ClassHubPage(asTab: true),
        const ProfilePage(asTab: true),
        // Solo nella barra laterale (sul telefono si aprono sopra): costruite solo se servono.
        if (_wide) const SearchPage() else const SizedBox.shrink(),
        if (_wide) SavedPage(onSearch: _openSearch) else const SizedBox.shrink(),
      ],
    );

    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= kGridBreakpoint;
      if (wide != _wide) {
        _wide = wide;
        // Da largo a stretto con Cerca/Salvati aperti: si torna alla home.
        if (!wide && _index > 3) WidgetsBinding.instance.addPostFrameCallback((_) => _go(0));
      }
      if (wide) {
        final scheme = Theme.of(context).colorScheme;
        Widget faint(int i, IconData icon, IconData selected, String label) {
          final on = _index == i;
          return Opacity(
            opacity: on ? 1 : 0.55,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _go(i),
                child: SizedBox(
                  width: 72,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(color: on ? scheme.secondaryContainer : null, borderRadius: BorderRadius.circular(16)),
                        child: Icon(on ? selected : icon, size: 22),
                      ),
                      const SizedBox(height: 4),
                      Text(label, style: Theme.of(context).textTheme.labelMedium),
                    ]),
                  ),
                ),
              ),
            ),
          );
        }

        return Scaffold(
          body: Row(
            children: [
              SafeArea(
                right: false,
                child: NavigationRail(
                  selectedIndex: _index <= 3 ? _index : null,
                  onDestinationSelected: _go,
                  labelType: NavigationRailLabelType.all,
                  groupAlignment: -0.9,
                  leading: const Padding(
                    padding: EdgeInsets.only(top: 8, bottom: 16),
                    child: AppLogo(size: 44),
                  ),
                  trailing: Column(
                    children: [
                      const SizedBox(width: 48, child: Divider(height: 24)),
                      faint(_search, Icons.search_rounded, Icons.search_rounded, tr('Cerca', 'Search')),
                      faint(_saved, Icons.bookmark_border_rounded, Icons.bookmark_rounded, tr('Salvati', 'Saved')),
                      const SizedBox(height: 8),
                      Opacity(
                        opacity: 0.55,
                        child: IconButton(
                          tooltip: 'Temi',
                          onPressed: () => openThemesPage(context),
                          icon: const Icon(Icons.palette_outlined),
                        ),
                      ),
                    ],
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
          selectedIndex: _index.clamp(0, 3),
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

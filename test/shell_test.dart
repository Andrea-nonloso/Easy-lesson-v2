// 3.6: barra Home · Orario · Amici · Profilo; Cerca e Salvati solo nella barra laterale;
// riga dei pulsanti della scuola; Impostazioni senza Profilo/Scuola/Agenda.
// Con SCREENS=1 salva anche le immagini delle schermate (per guardarle).
import 'dart:convert';
import 'dart:io';

import 'package:easy_lesson/api.dart';
import 'package:easy_lesson/store.dart';
import 'package:easy_lesson/ui/class_page.dart' show ModLockBanner;
import 'package:easy_lesson/ui/home_shell.dart';
import 'package:easy_lesson/ui/school_shortcuts.dart';
import 'package:easy_lesson/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fonts.dart';

final _screens = Platform.environment['SCREENS'] == '1';

Future<AppStore> _store() async {
  SharedPreferences.setMockInitialValues({'el.username': 'Andrea', 'el.setupDone': true});
  return AppStore.create(api: EasyLessonApi(client: MockClient((_) async => http.Response('[]', 200))));
}

Future<void> _pumpShell(WidgetTester t, AppStore store, Size size) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(StoreScope(
    store: store,
    child: MaterialApp(theme: buildTheme(Brightness.light), debugShowCheckedModeBanner: false, home: const HomeShell()),
  ));
  await t.pump(const Duration(milliseconds: 300));
}

Future<void> _shot(WidgetTester t, String name) async {
  if (!_screens) return;
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('screens/$name.png'));
}

/// Lascia scadere i timer dell'avvio (aggiornamenti, avvisi, obiettivi).
Future<void> _settle(WidgetTester t) async {
  await t.pump(const Duration(seconds: 20));
  await t.pumpWidget(const SizedBox());
}

void main() {
  setUpAll(loadTestFonts);

  testWidgets('telefono: 4 voci, niente Cerca/Salvati nella barra; pulsanti della scuola in home', (t) async {
    final store = await _store();
    await _pumpShell(t, store, const Size(390, 844));
    final bar = find.byType(NavigationBar);
    expect(bar, findsOneWidget);
    for (final l in ['Home', 'Orario', 'Amici', 'Profilo']) {
      expect(find.descendant(of: bar, matching: find.text(l)), findsOneWidget, reason: l);
    }
    expect(find.descendant(of: bar, matching: find.text('Cerca')), findsNothing);
    expect(find.text('Voti'), findsOneWidget);
    expect(find.text('Assenze'), findsOneWidget);
    expect(find.text('Altro'), findsOneWidget);
    await _shot(t, 'telefono_home');

    await t.tap(find.descendant(of: bar, matching: find.text('Profilo')));
    await t.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
    expect(find.byTooltip('Impostazioni'), findsWidgets);
    await _shot(t, 'telefono_profilo');

    await t.tap(find.descendant(of: bar, matching: find.text('Amici')));
    await t.pump(const Duration(milliseconds: 500));
    await t.pump(const Duration(seconds: 1));
    expect(t.widget<NavigationBar>(bar).selectedIndex, 2);
    await _shot(t, 'telefono_amici');
    await _settle(t);
  });

  testWidgets('schermo largo: barra laterale con Cerca e Salvati sotto il separatore', (t) async {
    final store = await _store();
    await _pumpShell(t, store, const Size(1280, 800));
    final rail = find.byType(NavigationRail);
    expect(rail, findsOneWidget);
    expect(find.descendant(of: rail, matching: find.text('Cerca')), findsOneWidget);
    expect(find.descendant(of: rail, matching: find.text('Salvati')), findsOneWidget);
    await _shot(t, 'largo_home');
    await t.tap(find.descendant(of: rail, matching: find.text('Cerca')));
    await t.pump(const Duration(milliseconds: 500));
    await _shot(t, 'largo_cerca');
    await _settle(t);
  });

  testWidgets('home minimal con il proprio orario: card, lezioni del giorno, tre riquadri (3.8)', (t) async {
    Map<String, dynamic> day(List<String> l) => {for (var i = 0; i < l.length; i++) 'ora${i + 1}': l[i], 'lab3': 'W Info 1'};
    final raw = {
      for (var d = 0; d < 6; d++)
        'giorno$d': day(['Matematica\nRossi', 'Matematica\nRossi', 'Informatica\nBianchi', 'Inglese\nVerdi', 'Storia\nNeri', 'Italiano\nNeri']),
    };
    final now = DateTime.now().toIso8601String();
    SharedPreferences.setMockInitialValues({
      'el.username': 'Andrea',
      'el.setupDone': true,
      'el.mine': 'c:1A IT',
      'el.schedules': jsonEncode([
        {'name': '1A IT', 'prof': false, 'raw': raw, 'updatedAt': now, 'lastOpened': now, 'favorite': true},
      ]),
    });
    final store = await AppStore.create(api: EasyLessonApi(client: MockClient((_) async => http.Response('[]', 200))));
    await _pumpShell(t, store, const Size(390, 844));
    expect(find.text('Voti'), findsOneWidget);
    expect(find.text('Agenda'), findsOneWidget);
    expect(find.text('Imposta il tuo orario'), findsNothing);
    await _shot(t, 'telefono_home_orario');
    await _settle(t);
  });

  testWidgets('pulsanti della scuola: scelta e ordine salvati', (t) async {
    final store = await _store();
    expect(chosenSchoolTools(store).map((x) => x.id), ['voti', 'assenze', 'agenda']);
    await store.setOpt(kSchoolShortcutsOpt, ['agenda', 'boh', 'voti']);
    expect(chosenSchoolTools(store).map((x) => x.id), ['agenda', 'voti']);
    expect(schoolTools().map((x) => x.id).toSet().length, schoolTools().length);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('avviso da leggere: il riquadro rosso con "Leggi l\'avviso"', (t) async {
    t.view.physicalSize = const Size(390, 400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    var opened = false;
    await t.pumpWidget(MaterialApp(
      theme: buildTheme(Brightness.light),
      home: Scaffold(body: ModLockBanner(count: 1, onOpen: () => opened = true)),
    ));
    expect(find.text('Hai un avviso della moderazione da leggere'), findsOneWidget);
    await t.tap(find.text('Leggi l\'avviso'));
    expect(opened, isTrue);
    await _shot(t, 'avviso_blocco');
  });
}

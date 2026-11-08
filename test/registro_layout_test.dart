// 3.8: Voti e Assenze con le card come sul registro (bollino colorato, menu a tendina, contatori).
// Dati di prova inventati.
import 'dart:io';

import 'package:easy_lesson/api.dart';
import 'package:easy_lesson/store.dart';
import 'package:easy_lesson/ui/school_life_pages.dart';
import 'package:easy_lesson/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fonts.dart';

Future<AppStore> _store() async {
  SharedPreferences.setMockInitialValues({'el.username': 'Prova', 'el.setupDone': true});
  final store = await AppStore.create(api: EasyLessonApi(client: MockClient((_) async => http.Response('[]', 200))));
  final y = DateTime.now().month >= 9 ? DateTime.now().year : DateTime.now().year - 1;
  await store.addGrade(date: DateTime(y, 10, 20), subject: 'Matematica', value: 7.5, kind: 'scritto', note: 'Equazioni');
  await store.addGrade(date: DateTime(y, 10, 27), subject: 'Storia', value: 6.5, kind: 'orale');
  await store.addGrade(date: DateTime(y, 11, 3), subject: 'Matematica', value: 4.75, kind: 'orale');
  await store.addAbsence(date: DateTime(y, 10, 15), kind: 'assenza');
  await store.addAbsence(date: DateTime(y, 10, 22), kind: 'entrata', hour: 2);
  await store.addAbsence(date: DateTime(y, 11, 4), kind: 'uscita', hour: 5, note: 'Visita');
  return store;
}

Future<void> _show(WidgetTester t, AppStore store, Widget page) async {
  t.view.physicalSize = const Size(420, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(StoreScope(store: store, child: MaterialApp(theme: buildTheme(Brightness.dark), home: page)));
  await t.pump(const Duration(milliseconds: 300));
}

void main() {
  setUpAll(loadTestFonts);

  testWidgets('voti: una card per voto, dal più recente, e filtro per materia', (t) async {
    final store = await _store();
    await _show(t, store, const GradesPage());
    expect(find.text('MATEMATICA'), findsNWidgets(2));
    expect(find.text('STORIA'), findsOneWidget);
    expect(find.text('6½'), findsOneWidget);
    final dates = t.widgetList<Text>(find.textContaining(RegExp(r'^\d\d/\d\d/\d{4}$'))).map((w) => w.data!).toList();
    expect(dates.first.startsWith('03/11'), isTrue, reason: '$dates');
    if (Platform.environment['SCREENS'] == '1') {
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('screens/registro_voti.png'));
    }
    await store.setOpt('grades.subject', 'Matematica');
    await t.pump();
    expect(find.text('STORIA'), findsNothing);
    expect(find.textContaining('Media 6.13'), findsOneWidget);
    await store.setOpt('grades.layout', 'subjects');
    await t.pump();
    expect(find.text('Storia'), findsWidgets);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('assenze: percentuale, contatori e card con la lettera', (t) async {
    final store = await _store();
    await _show(t, store, const AbsencesPage());
    expect(find.text('Percentuale assenze totali'), findsOneWidget);
    for (final l in ['A', 'E', 'U']) {
      expect(find.text(l), findsOneWidget);
    }
    expect(find.text('Esce dopo la 5ª ora'), findsOneWidget);
    if (Platform.environment['SCREENS'] == '1') {
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('screens/registro_assenze.png'));
    }
    await t.tap(find.text('Uscite'));
    await t.pump();
    expect(find.text('A'), findsNothing);
    expect(find.text('U'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });
}

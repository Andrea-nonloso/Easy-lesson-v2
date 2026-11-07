// 3.8: inglese completo. Nessun Text('…') italiano nuovo senza tr(), ogni obiettivo ha la sua traduzione e le
// schermate principali in inglese non mostrano parole italiane.
import 'dart:convert';
import 'dart:io';

import 'package:easy_lesson/api.dart';
import 'package:easy_lesson/i18n.dart';
import 'package:easy_lesson/store.dart';
import 'package:easy_lesson/ui/achievements.dart';
import 'package:easy_lesson/ui/achievements_en.dart';
import 'package:easy_lesson/ui/home_shell.dart';
import 'package:easy_lesson/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fonts.dart';

/// Pagine solo per gli sviluppatori: restano in italiano.
const _devOnly = {'dev_page.dart', 'deep_dev_page.dart', 'dev_tools.dart'};

/// Testi uguali nelle due lingue.
const _same = {'Easy Lesson', 'OK', 'HEX', 'Emoji', 'Email', '5 min', '10 min', '15 min', '30 min', '🇮🇹 Italiano', '🇬🇧 English'};

void main() {
  setUpAll(loadTestFonts);

  test('nessun Text(\'…\') con parole senza tr() nelle pagine', () {
    final start = RegExp(r"(?<![\w.])(?:Text\(|tooltip: |hintText: |labelText: |helperText: )(?:const )?'");
    final bad = <String>[];
    for (final f in Directory('lib/ui').listSync().whereType<File>()) {
      final name = f.uri.pathSegments.last;
      if (!name.endsWith('.dart') || _devOnly.contains(name)) continue;
      final src = f.readAsStringSync();
      for (final m in start.allMatches(src)) {
        final text = _plainText(src, m.end - 1);
        if (text == null || _same.contains(text.trim()) || RegExp(r'@|://|^Ab3').hasMatch(text)) continue;
        if (!RegExp(r'[A-Za-zÀ-ÿ]{2,}').hasMatch(text.replaceAll('XP', ''))) continue;
        final line = '\n'.allMatches(src.substring(0, m.start)).length + 1;
        bad.add('$name:$line: $text');
      }
    }
    expect(bad, isEmpty, reason: 'Testi da passare a tr(\'italiano\', \'english\'):\n${bad.join('\n')}');
  });

  test('ogni obiettivo ha titolo e descrizione in inglese', () {
    final missing = [for (final a in achievements) if (!achievementsEn.containsKey(a.id)) a.id];
    expect(missing, isEmpty, reason: 'Aggiungili in lib/ui/achievements_en.dart');
    appEnglish = true;
    addTearDown(() => appEnglish = false);
    final first = achievements.firstWhere((a) => a.id == 'first');
    expect(first.title, 'Welcome!');
    expect(first.how, 'Open Easy Lesson');
    appEnglish = false;
    expect(first.title, 'Benvenuto!');
  });

  testWidgets('home in inglese: niente parole italiane in vista', (t) async {
    // Con il proprio orario: card della lezione, lezioni del giorno, pulsanti della scuola.
    Map<String, dynamic> day(List<String> l) => {for (var i = 0; i < l.length; i++) 'ora${i + 1}': l[i], 'lab3': 'W Info 1'};
    final raw = {
      for (var d = 0; d < 6; d++) 'giorno$d': day(['Matematica\nRossi', 'Informatica\nBianchi', 'Inglese\nVerdi', 'Storia\nNeri']),
    };
    final now = DateTime.now().toIso8601String();
    SharedPreferences.setMockInitialValues({
      'el.username': 'Andrea',
      'el.setupDone': true,
      'el.extras': '{"lang":"en"}',
      'el.mine': 'c:1A IT',
      'el.schedules': jsonEncode([
        {'name': '1A IT', 'prof': false, 'raw': raw, 'updatedAt': now, 'lastOpened': now, 'favorite': true},
      ]),
    });
    final store = await AppStore.create(api: EasyLessonApi(client: MockClient((_) async => http.Response('[]', 200))));
    addTearDown(() => appEnglish = false);
    expect(appEnglish, isTrue);
    t.view.physicalSize = const Size(420, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(StoreScope(
      store: store,
      child: MaterialApp(theme: buildTheme(Brightness.light), home: const HomeShell()),
    ));
    await t.pump(const Duration(milliseconds: 300));
    final italian = RegExp(r'\b(Orario|Oggi|Domani|Imposta|Impostazioni|Lezioni|Nessun\w*|Profilo|Amici|Scuola|Voti|Assenze|Agenda|Altro)\b');
    final shown = [
      for (final w in t.widgetList<Text>(find.byType(Text)))
        if ((w.data ?? w.textSpan?.toPlainText() ?? '').isNotEmpty) w.data ?? w.textSpan!.toPlainText(),
    ];
    expect(shown.where(italian.hasMatch).toList(), isEmpty, reason: 'In vista: $shown');
    expect(shown, contains('Timetable'));
    expect(shown, contains('Grades'));
    if (Platform.environment['SCREENS'] == '1') {
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('screens/en_home.png'));
      await t.tap(find.text('Profile').last);
      await t.pump(const Duration(milliseconds: 500));
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('screens/en_profile.png'));
      await t.tap(find.text('Friends').last);
      await t.pump(const Duration(milliseconds: 500));
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('screens/en_friends.png'));
    }
    await t.pump(const Duration(seconds: 20));
    await t.pumpWidget(const SizedBox());
  });
}

/// Il testo "fisso" di un letterale Dart che inizia in [i] (con l'apice), senza le parti ${…} (anche annidate).
/// Unisce i letterali vicini ('a' 'b'). null = non è un letterale semplice.
String? _plainText(String src, int i) {
  final out = StringBuffer();
  while (i < src.length && src[i] == "'") {
    i++;
    while (i < src.length && src[i] != "'") {
      if (src[i] == '\\') {
        i += 2;
        continue;
      }
      if (src.startsWith(r'${', i)) {
        var depth = 1;
        i += 2;
        while (i < src.length && depth > 0) {
          if (src[i] == "'") {
            i++;
            while (i < src.length && src[i] != "'") {
              i += src[i] == '\\' ? 2 : 1;
            }
          } else if (src[i] == '{') {
            depth++;
          } else if (src[i] == '}') {
            depth--;
          }
          i++;
        }
        out.write(' ');
        continue;
      }
      if (src[i] == r'$') {
        i++;
        while (i < src.length && RegExp(r'\w').hasMatch(src[i])) {
          i++;
        }
        out.write(' ');
        continue;
      }
      out.write(src[i]);
      i++;
    }
    i++;
    while (i < src.length && ' \n\t'.contains(src[i])) {
      i++;
    }
  }
  return out.toString();
}

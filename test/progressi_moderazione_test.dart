// 3.8: la moderazione modifica livello, monete, oggetti e obiettivi. Il telefono prende la versione del server
// così com'è, ma tiene le cose che il server non conosce (serie di oggi, statistiche locali, oggetto indossato).
import 'package:easy_lesson/api.dart';
import 'package:easy_lesson/progress.dart';
import 'package:easy_lesson/shop.dart';
import 'package:easy_lesson/store.dart';
import 'package:easy_lesson/ui/achievements.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppStore> _store(Map<String, Object> extras) async {
  SharedPreferences.setMockInitialValues({'el.username': 'Prova', 'el.setupDone': true});
  final s = await AppStore.create(api: EasyLessonApi(client: MockClient((_) async => http.Response('[]', 200))));
  for (final e in extras.entries) {
    await s.setOpt(e.key, e.value);
  }
  return s;
}

void main() {
  test('modifica della moderazione: XP, monete, oggetti e serie', () async {
    final s = await _store({
      'stat.days': 10,
      'stat.streak': 4,
      'stat.lastDay': '2026-11-08',
      'stat.own.cap': 1,
      'stat.own.crown': 1,
      'shop.eq.hat': 'cap',
      'shop.eq.top': 'crown',
      'egg.early': true,
      'ach.done': 'first',
    });
    final before = totalXp(s);
    final changed = await s.applyProgress(
      ProgressData(achievements: {'first'}, counters: {'days': 10, 'xpBonus': 100, 'xpPenalty': 20, 'coinBonus': 7, 'own.cap': 1}),
      resetAt: 1000,
    );
    expect(changed, isTrue);
    expect(totalXp(s), before + 80);
    expect(Shop.earned(totalXp(s), s), totalXp(s) ~/ xpPerCoin + 7);
    expect(s.stat('streak'), 4, reason: 'la serie di oggi resta');
    expect(s.opt('egg.early', false), isTrue);
    expect(s.opt('shop.eq.hat', ''), 'cap', reason: 'ancora suo: resta indossato');
    expect(s.opt<String?>('shop.eq.top', null), isNull, reason: 'tolto dalla moderazione');
    expect(s.stat('own.crown'), 0);
  });

  test('la serie la cambia solo una modifica, non un\'unione normale', () async {
    final s = await _store({'stat.streak': 4, 'stat.days': 3, 'cloud.resetSeen': 1000});
    await s.applyProgress(ProgressData(counters: {'days': 3, 'streak': 50}));
    expect(s.stat('streak'), 4);
    await s.applyProgress(ProgressData(counters: {'days': 3, 'streak': 50}), resetAt: 2000);
    expect(s.stat('streak'), 50);
  });

  test('azzeramento: via tutto, anche la serie', () async {
    final s = await _store({'stat.streak': 4, 'stat.days': 3, 'egg.early': true, 'ach.done': 'first'});
    await s.applyProgress(ProgressData(), resetAt: 1000);
    expect(s.stat('streak'), 0);
    expect(s.opt('egg.early', false), isFalse);
    expect(totalXp(s), 0);
  });
}

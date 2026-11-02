import 'package:easy_lesson/mission_engine.dart';
import 'package:easy_lesson/missions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hash stabile (uguale a FNV-1a calcolato con Node)', () {
    expect(stableHash('2026-11-02'), 1948132917);
  });

  test('settimana = lunedì', () {
    expect(weekKey(DateTime(2026, 11, 2)), '2026-11-02'); // lunedì
    expect(weekKey(DateTime(2026, 11, 8, 23)), '2026-11-02'); // domenica
    expect(weekKey(DateTime(2026, 11, 9)), '2026-11-09');
    expect(weekKey(DateTime(2027, 1, 1)), '2026-12-28'); // a cavallo dell'anno
  });

  test('scelta: 3 missioni, sempre le stesse per lo stesso giorno, metriche diverse', () {
    final a = pickMissions(dailyMissions, '2026-11-02', 3);
    final b = pickMissions(dailyMissions, '2026-11-02', 3);
    expect(a.map((m) => m.id), b.map((m) => m.id));
    expect(a.length, 3);
    expect(a.map((m) => m.metric).toSet().length, 3);
    // Giorni diversi: di solito missioni diverse.
    final days = {for (var d = 1; d <= 20; d++) pickMissions(dailyMissions, '2026-11-$d', 3).map((m) => m.id).join()};
    expect(days.length, greaterThan(10));
  });

  test('filtri ed eventi', () {
    for (var d = 1; d <= 30; d++) {
      final l = pickMissions(dailyMissions, 'd$d', 3, allowed: (m) => !m.schoolDay);
      expect(l.any((m) => m.schoolDay), isFalse);
    }
    final f = pickMissions(dailyMissions, 'x', 3, forced: const ['d_study25', 'nessuna']);
    expect(f.first.id, 'd_study25');
    expect(f.length, 3);
  });

  test('id unici e sensati', () {
    final ids = [...dailyMissions, ...weeklyMissions].map((m) => m.id).toList();
    expect(ids.toSet().length, ids.length);
    for (final m in [...dailyMissions, ...weeklyMissions]) {
      expect(m.goal, greaterThan(0));
      expect(m.xp, greaterThan(0));
    }
  });

  test('evento dal JSON del server', () {
    final e = MissionEvent.fromJson({
      'id': 'natale',
      'title': 'Natale',
      'starts': DateTime(2026, 12, 20).millisecondsSinceEpoch,
      'ends': DateTime(2026, 12, 27).millisecondsSinceEpoch,
      'multiplier': 9,
      'daily': ['d_done', 3],
    })!;
    expect(e.multiplier, 5);
    expect(e.daily, ['d_done']);
    expect(e.activeAt(DateTime(2026, 12, 24)), isTrue);
    expect(e.activeAt(DateTime(2026, 12, 28)), isFalse);
    expect(MissionEvent.fromJson({'id': 'x'}), isNull);
  });

  test('tempo alle missioni nuove', () {
    final now = DateTime(2026, 11, 4, 22, 30); // mercoledì
    expect(Missions.untilNext(now, weekly: false), const Duration(hours: 1, minutes: 30));
    expect(Missions.untilNext(now, weekly: true), const Duration(days: 4, hours: 1, minutes: 30));
  });
}

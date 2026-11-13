import 'package:easy_lesson/wellbeing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime(2026, 11, 12);

  test('serie di giorni: conta fino a oggi o fino a ieri', () {
    final h = Habit(id: 'h', name: 'Acqua', emoji: '💧', days: {'2026-11-10', '2026-11-11', '2026-11-12', '2026-11-05'});
    expect(h.streak(today), 3);
    h.days.remove('2026-11-12');
    expect(h.streak(today), 2);
    h.days.remove('2026-11-11');
    expect(h.streak(today), 0);
  });

  test('record di sempre', () {
    final h = Habit(id: 'h', name: 'x', emoji: 'x', days: {'2026-10-01', '2026-10-02', '2026-10-03', '2026-10-10', '2026-10-11'});
    expect(h.bestStreak, 3);
    expect(Habit(id: 'h', name: 'x', emoji: 'x').bestStreak, 0);
  });

  test('abitudine: JSON andata e ritorno, dati rovinati saltati', () {
    final h = Habit(id: 'h', name: 'Leggere', emoji: '📖', days: {'2026-11-12'});
    final back = Habit.fromJson(h.toJson())!;
    expect((back.name, back.emoji), ('Leggere', '📖'));
    expect(back.days, {'2026-11-12'});
    expect(Habit.fromJson({'id': 'h', 'n': 'x', 'd': [1, 'no', '2026-11-12']})!.days, {'2026-11-12'});
    expect(Habit.fromJson(3), isNull);
  });

  test('umore: parse scarta valori fuori scala', () {
    final m = Mood.parse({'2026-11-12': [4, 2], '2026-11-11': [9, 1], 'x': [1, 1], '2026-11-10': 'no'});
    expect(m.keys, ['2026-11-12']);
    expect(m['2026-11-12']!.mood, 4);
  });

  test('stress vicino alle verifiche', () {
    final m = Mood.parse({'2026-11-11': [3, 5], '2026-11-12': [2, 4], '2026-11-05': [4, 1], '2026-11-06': [4, 2]});
    final r = stressNearTests(m, [DateTime(2026, 11, 12)])!;
    expect(r.nearTests, 4.5);
    expect(r.other, 1.5);
    expect(stressNearTests(m, const []), isNull);
  });
}

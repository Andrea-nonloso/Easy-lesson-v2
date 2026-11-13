import 'package:easy_lesson/models.dart';
import 'package:easy_lesson/school_life.dart';
import 'package:flutter_test/flutter_test.dart';

Lesson _l(int i, String t) => Lesson(index: i, text: t.isEmpty ? '' : '$t\nDocente', lab: '', sostegno: const []);

void main() {
  // Lunedì 6 ore, martedì 5.
  final week = WeekSchedule([
    DaySchedule([for (var i = 0; i < 6; i++) _l(i, i < 2 ? 'Matematica' : 'Italiano')]),
    DaySchedule([for (var i = 0; i < 5; i++) _l(i, 'Inglese')]),
  ]);
  final monday = DateTime(2026, 11, 2);
  final tuesday = DateTime(2026, 11, 3);

  test('ore perse e limite del 25%', () {
    final entries = [
      AbsenceEntry(id: '1', date: monday, kind: 'entrata', hour: 3), // perse 2 ore di matematica
      AbsenceEntry(id: '2', date: tuesday, kind: 'assenza'), // perse 5 di inglese
    ];
    final s = absenceStats(entries, week, DateTime(2026, 11, 4));
    expect(s.lost, 7);
    expect(s.bySubject['Matematica'], 2);
    expect(s.bySubject['Inglese'], 5);
    expect(s.yearHours, 11 * schoolWeeks);
    expect(s.limitHours, (11 * schoolWeeks * 0.25).floor());
    expect(s.days, 1);
  });

  test('entrate e uscite: ore in cui si è a scuola', () {
    final entries = [
      AbsenceEntry(id: '1', date: monday, kind: 'entrata', hour: 2),
      AbsenceEntry(id: '2', date: monday, kind: 'uscita', hour: 4),
    ];
    expect(attendedRange(entries, monday, 6), (1, 3));
    expect(attendedRange(entries, tuesday, 5), (0, 4));
    expect(attendedRange([AbsenceEntry(id: '3', date: tuesday, kind: 'assenza')], tuesday, 5), isNull);
  });

  test('voti: lettura, media e quanto serve', () {
    expect(Grade.parse('7'), 7);
    expect(Grade.parse('6½'), 6.5);
    expect(Grade.parse('6+'), 6.25);
    expect(Grade.parse('8-'), 7.75);
    expect(Grade.parse('6/7'), 6.5);
    expect(Grade.parse('7,5'), 7.5);
    expect(Grade.parse('11'), isNull);
    expect(Grade.format(6.5), '6½');
    expect(Grade.format(7.75), '8-');
    final g = [
      Grade(id: '1', date: monday, subject: 'Mate', value: 5),
      Grade(id: '2', date: monday, subject: 'Mate', value: 6),
    ];
    expect(average(g), 5.5);
    expect(neededFor(g, 6), 7); // (6*3 - 11) / 1
    expect(neededFor(g, 6, weight: 0.5), closeTo(8, 0.001)); // (6*2.5 - 11) / 0.5
  });

  test('quanto mi serve: una prova, più prove, già fatto, impossibile (3.8)', () {
    Grade v(double x) => Grade(id: '$x', date: monday, subject: 'Mate', value: x);
    // 5 e 6: per il 6 serve un 7 nella prossima
    expect(planToReach([v(5), v(6)], 6), (count: 1, grade: 7.0));
    expect(planText(planToReach([v(5), v(6)], 6), 6), 'Ti serve almeno 7 nella prossima prova');
    // 3, 3, 4: per il 6 un 10 non basta (servirebbe 14); con due prove: (6*5 - 10) / 2 = 10
    expect(neededForMany([v(3), v(3), v(4)], 6, count: 2), 10);
    expect(planToReach([v(3), v(3), v(4)], 6), (count: 2, grade: 10.0));
    expect(planText(planToReach([v(3), v(3), v(4)], 6), 6), 'Con una prova sola non basta neanche un 10. Con 2 prove: almeno 10 in tutte e due');
    // arrotondamento per eccesso al quarto: 6,1 -> 6+
    expect(roundUpGrade(6.1), 6.25);
    expect(roundUpGrade(6.5), 6.5);
    // già fatto
    expect(planToReach([v(9), v(8)], 6), (count: 0, grade: 0.0));
    expect(planText((count: 0, grade: 0.0), 6), contains('ce l\'hai già'));
    // impossibile anche con 5 prove
    expect(planToReach([for (var i = 0; i < 20; i++) v(2)], 8), isNull);
    expect(planText(null, 8), contains('troppo lontano'));
    // nessun voto: basta il voto obiettivo
    expect(planToReach(const [], 6), (count: 1, grade: 6.0));
  });

  test('settimana A/B', () {
    final anchorB = DateTime(2026, 11, 2); // questa è B
    expect(isWeekB(DateTime(2026, 11, 4), anchorB), isTrue);
    expect(isWeekB(DateTime(2026, 11, 9), anchorB), isFalse);
    expect(isWeekB(DateTime(2026, 11, 16), anchorB), isTrue);
    expect(isWeekB(DateTime(2026, 10, 28), anchorB), isFalse);
  });

  test('raiseOverall: alza prima le materie più basse', () {
    final r = raiseOverall({'MAT': 5, 'ITA': 7, 'ING': 8}, 7);
    expect(r, [('MAT', 5.0, 6.0)]);
    expect(raiseOverall({'MAT': 9, 'ITA': 9.5}, 9), isEmpty);
    expect(raiseOverall({'MAT': 9, 'ITA': 9}, 10), [('MAT', 9.0, 10.0), ('ITA', 9.0, 10.0)]);
    expect(raiseOverall({'MAT': 3}, 10.5), isNull);
    expect(raiseOverall({}, 7), isNull);
  });

  test('gradeTargets salta i valori rovinati', () {
    expect(gradeTargets({'MAT': 7, 'ITA': 'x', 'ING': 12, 'FIS': 6.5}), {'MAT': 7.0, 'FIS': 6.5});
    expect(gradeTargets(null), isEmpty);
  });
}

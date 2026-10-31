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

  test('settimana A/B', () {
    final anchorB = DateTime(2026, 11, 2); // questa è B
    expect(isWeekB(DateTime(2026, 11, 4), anchorB), isTrue);
    expect(isWeekB(DateTime(2026, 11, 9), anchorB), isFalse);
    expect(isWeekB(DateTime(2026, 11, 16), anchorB), isTrue);
    expect(isWeekB(DateTime(2026, 10, 28), anchorB), isFalse);
  });
}

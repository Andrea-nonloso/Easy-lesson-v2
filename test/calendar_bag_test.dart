import 'package:easy_lesson/bag.dart';
import 'package:easy_lesson/models.dart';
import 'package:easy_lesson/school_calendar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final cal = SchoolCalendar();

  test('vacanze e giorni di scuola 2026/27', () {
    expect(cal.closureOn(DateTime(2026, 12, 28))?.name, 'Vacanze di Natale');
    expect(cal.closureOn(DateTime(2027, 1, 7)), isNull);
    expect(cal.isSchoolDay(DateTime(2027, 1, 7)), true); // giovedì
    expect(cal.isSchoolDay(DateTime(2026, 11, 7)), false); // sabato (5 giorni)
    expect(cal.closureOn(DateTime(2027, 7, 15))?.name, 'Vacanze estive');
    expect(cal.closureOn(DateTime(2026, 12, 23))!.backOn, DateTime(2027, 1, 7));
  });

  test('conti alla rovescia', () {
    final c = cal.countdowns(DateTime(2026, 10, 31, 10), max: 3);
    expect(c.first.name, 'Ognissanti');
    expect(c.first.days, 1);
    expect(c.map((e) => e.name), contains('Immacolata'));
    expect(daysBetween(DateTime(2026, 10, 24), DateTime(2026, 10, 26)), 2); // cambio ora legale
  });

  test('giorni aggiunti a mano', () {
    final extra = SchoolCalendar([Closure(DateTime(2026, 11, 2), DateTime(2026, 11, 2), 'Ponte')]);
    expect(extra.isSchoolDay(DateTime(2026, 11, 2)), false);
    final back = Closure.fromJson(Closure(DateTime(2026, 11, 2), DateTime(2026, 11, 3), 'Ponte').toJson())!;
    expect(back.to, DateTime(2026, 11, 3));
  });

  test('zaino dalle regole', () {
    final day = DaySchedule([
      Lesson(index: 0, text: 'Chimica\nDocente 1', lab: 'W Chim biennio', sostegno: const []),
      Lesson(index: 1, text: 'Matematica\nDocente 2', lab: '', sostegno: const []),
      Lesson(index: 2, text: 'Matematica\nDocente 2', lab: '', sostegno: const []),
      Lesson(index: 3, text: 'Scienze motorie\nDocente 3', lab: '', sostegno: const []),
    ]);
    expect(subjectsOfDay(day), ['Chimica', 'Matematica', 'Scienze motorie']);
    expect(bagItems(day, defaultBagRules), ['Camice 🥼', 'Calcolatrice 🧮', 'Tuta e scarpe da ginnastica 👟']);
  });
}

import 'package:easy_lesson/agenda.dart';
import 'package:easy_lesson/models.dart';
import 'package:easy_lesson/school_extra.dart';
import 'package:easy_lesson/school_life.dart';
import 'package:flutter_test/flutter_test.dart';

Lesson _l(int i, String t, {String lab = ''}) =>
    Lesson(index: i, text: t.isEmpty ? '' : '$t\nDocente ${t.length}', lab: lab, sostegno: const []);

void main() {
  test('orario cambiato', () {
    final a = WeekSchedule([DaySchedule([_l(0, 'Fisica'), _l(1, 'Matematica')])]);
    final b = WeekSchedule([DaySchedule([_l(0, 'Chimica', lab: 'W Chim'), _l(1, 'Matematica')])]);
    final d = scheduleDiff(a, b);
    expect(d, ['Lunedì 1ª ora: Fisica → Chimica (W Chim)']);
    expect(scheduleDiff(a, a), isEmpty);
  });

  test('piano di studio: i giorni prima della verifica', () {
    final now = DateTime(2026, 11, 2, 15);
    final v = AgendaItem(id: '1', date: DateTime(2026, 11, 5), kind: 'verifica', subject: 'Mate', text: '');
    final c = AgendaItem(id: '2', date: DateTime(2026, 11, 3), kind: 'compito', subject: 'Ita', text: '');
    final plan = studyPlan([v, c], now, days: 3);
    expect(plan.length, 3);
    expect(plan.first.day, DateTime(2026, 11, 2));
    expect(plan.last.day, DateTime(2026, 11, 4));
    expect(plan.last.part, 3);
    // Verifica domani: un solo giorno (oggi).
    final soon = AgendaItem(id: '3', date: DateTime(2026, 11, 3), kind: 'interrogazione', subject: 'Sto', text: '');
    expect(studyPlan([soon], now).length, 1);
  });

  test('periodi e pagella', () {
    expect(gradePeriod(DateTime(2026, 10, 1)), 1);
    expect(gradePeriod(DateTime(2027, 1, 20)), 2);
    expect(gradePeriod(DateTime(2027, 1, 20), mode: 'quad'), 1);
    expect(gradePeriod(DateTime(2027, 3, 1), mode: 'quad'), 2);
    expect(reportCardMark(6.5), 7);
    expect(reportCardMark(6.49), 6);
  });

  test('crediti scolastici', () {
    expect(creditBand(6, 3), (7, 8));
    expect(creditBand(7.5, 4), (10, 11));
    expect(creditBand(9.2, 5), (14, 15));
    expect(creditBand(5.5, 5), (7, 8));
    expect(creditBand(5.5, 3), isNull);
  });

  test('zaino: materiale e cose settimanali', () {
    final day = DaySchedule([_l(0, 'Storia')]);
    final items = extraBagItems(day, 2, {'Storia': ['📕 Libro di storia']}, [WeeklyItem(2, '💶 Soldi'), WeeklyItem(3, 'No')]);
    expect(items, ['📕 Libro di storia', '💶 Soldi']);
  });

  test('grafici', () {
    final g = [
      Grade(id: '1', date: DateTime(2026, 10, 1), subject: 'M', value: 6),
      Grade(id: '2', date: DateTime(2026, 10, 5), subject: 'M', value: 8),
    ];
    expect(runningAverage(g).map((p) => p.$2), [6, 7]);
    final w = weeklyStudy({isoDay(DateTime(2026, 11, 2)): 30, isoDay(DateTime(2026, 11, 4)): 20}, DateTime(2026, 11, 5));
    expect(w.last.$2, 50);
    expect(w.length, 8);
  });
}

import 'package:easy_lesson/agenda.dart';
import 'package:easy_lesson/recap.dart';
import 'package:easy_lesson/school_life.dart';
import 'package:easy_lesson/ui/recap_page.dart';
import 'package:easy_lesson/wellbeing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 11, 12);

  test('periodi: ultima settimana e anno scolastico', () {
    expect(lastWeek(now), (DateTime(2026, 11, 6), DateTime(2026, 11, 12)));
    expect(schoolYear(now).$1, DateTime(2026, 9, 1));
    expect(schoolYear(DateTime(2027, 3, 1)).$1, DateTime(2026, 9, 1));
    expect(schoolYear(DateTime(2027, 7, 20)), (DateTime(2026, 9, 1), DateTime(2027, 6, 30)));
  });

  test('riepilogo conta solo il periodo', () {
    final (from, to) = lastWeek(now);
    final r = computeRecap(
      from: from,
      to: to,
      studyLog: {'2026-11-10': 30, '2026-11-11': 50, '2026-10-01': 500},
      grades: [
        Grade(id: '1', date: DateTime(2026, 11, 9), subject: 'MAT', value: 8),
        Grade(id: '2', date: DateTime(2026, 11, 10), subject: 'MAT', value: 6),
        Grade(id: '3', date: DateTime(2026, 10, 1), subject: 'ITA', value: 10),
      ],
      agenda: [
        AgendaItem(id: 'a', date: DateTime(2026, 11, 11), kind: 'compito', subject: 'MAT', text: 'es', done: true),
        AgendaItem(id: 'b', date: DateTime(2026, 11, 12), kind: 'verifica', subject: 'ING', text: 'test'),
      ],
      habits: [Habit(id: 'h', name: 'Acqua', emoji: '💧', days: {'2026-11-10', '2026-11-11', '2026-11-12', '2026-11-01'})],
      moods: Mood.parse({'2026-11-11': [4, 2], '2026-11-12': [2, 4]}),
    );
    expect(r.studyMinutes, 80);
    expect(r.studyDays, 2);
    expect(r.bestStudyDay, (DateTime(2026, 11, 11), 50));
    expect(r.grades, 2);
    expect(r.gradesAvg, 7);
    expect(r.bestGrade!.value, 8);
    expect(r.topSubject, 'MAT');
    expect(r.homeworkDone, 1);
    expect(r.tests, 1);
    expect(r.habitTicks, 3);
    expect(r.bestHabit, ('💧 Acqua', 3));
    expect(r.moodAvg, 3);
    expect(r.isEmpty, isFalse);
  });

  test('formatMinutes', () {
    expect(formatMinutes(45), '45 min');
    expect(formatMinutes(120), '2 h');
    expect(formatMinutes(200), '3 h 20 min');
  });

  testWidgets('la card del riepilogo diventa un PNG', (t) async {
    final png = await t.runAsync(() => renderRecapImage(title: 'La mia settimana', subtitle: '6/11 – 12/11', tiles: [
          ('⏱️', '1 h 20 min', 'di studio'),
          ('📊', '7.00', 'di media'),
          ('✅', '3', 'compiti fatti'),
        ]));
    expect(png!.sublist(1, 4), 'PNG'.codeUnits);
  });
}

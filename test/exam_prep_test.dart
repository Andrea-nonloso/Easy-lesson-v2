import 'package:easy_lesson/exam_prep.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('data predefinita: 18 giugno di quest\'anno o del prossimo', () {
    expect(defaultExamDate(DateTime(2026, 11, 12)), DateTime(2027, 6, 18));
    expect(defaultExamDate(DateTime(2027, 3, 1)), DateTime(2027, 6, 18));
  });

  test('avanzamento e argomenti al giorno', () {
    final p = ExamPlan(date: DateTime(2027, 6, 18), subjects: [
      ExamSubject(id: 's', name: 'Storia', topics: [
        ExamTopic(id: 'a', text: 'Prima guerra mondiale', done: true),
        ExamTopic(id: 'b', text: 'Fascismo'),
      ]),
    ], checks: {'p1'});
    expect(p.topicsDone, 1);
    expect(p.progress, closeTo(2 / (2 + examChecklist.length), 1e-9));
    expect(p.daysLeft(DateTime(2027, 6, 1)), 17);
    expect(p.topicsPerDay(DateTime(2027, 6, 1)), closeTo(1 / 10, 1e-9));
    expect(p.topicsPerDay(DateTime(2027, 6, 15)), 1);
  });

  test('JSON andata e ritorno, voci sconosciute scartate', () {
    final p = ExamPlan(date: DateTime(2027, 6, 18), subjects: [ExamSubject(id: 's', name: 'Fisica', topics: [ExamTopic(id: 't', text: 'Onde', done: true)])], checks: {'p2'});
    final j = p.toJson();
    (j['c'] as List).add('hack');
    final back = ExamPlan.fromJson(j);
    expect(back.date, DateTime(2027, 6, 18));
    expect(back.subjects.single.topics.single.done, isTrue);
    expect(back.checks, {'p2'});
    expect(ExamPlan.fromJson('x').isEmpty, isTrue);
  });
}

import 'package:easy_lesson/social.dart';
import 'package:easy_lesson/ui/quiz_page.dart' show quizXp;
import 'package:flutter_test/flutter_test.dart';

/// 3.9: studio insieme, sfide a quiz, sondaggi di classe (risposte del server: server/src/together.js).
void main() {
  test('sfida a quiz: chi vince (a pari punti il più veloce) e a chi tocca', () {
    QuizMatch m(Map<String, dynamic> j) => QuizMatch({'id': 'a1', 'total': 5, ...j});
    expect(m({'status': 'done', 'myScore': 4, 'theirScore': 3}).outcome, 1);
    expect(m({'status': 'done', 'myScore': 2, 'theirScore': 3}).outcome, -1);
    expect(m({'status': 'done', 'myScore': 3, 'theirScore': 3, 'myMs': 20000, 'theirMs': 25000}).outcome, 1);
    expect(m({'status': 'done', 'myScore': 3, 'theirScore': 3, 'myMs': 30000, 'theirMs': 25000}).outcome, -1);
    expect(m({'status': 'done', 'myScore': 3, 'theirScore': 3}).outcome, 0);
    expect(m({'status': 'open', 'myScore': 5}).outcome, isNull);
    expect(m({'status': 'open', 'played': false}).myTurn, isTrue);
    expect(m({'status': 'open', 'played': true}).myTurn, isFalse);
    expect(m({'status': 'expired', 'played': false}).myTurn, isFalse);
    final o = m({'opponent': {'code': 'ABCD2345', 'nickname': 'Anna', 'avatar': '🦊', 'level': 4}}).opponent;
    expect((o.code, o.nickname, o.level), ('ABCD2345', 'Anna', 4));
    expect(quizXp(0), 5);
    expect(quizXp(5), 15);
  });

  test('partita: la risposta giusta arriva solo dopo aver giocato; dati rotti non rompono', () {
    final g = QuizGame({
      'id': 'a1',
      'status': 'open',
      'played': false,
      'questions': [
        {'subject': 'Storia', 'question': 'Q?', 'options': ['a', 'b', 'c', 'd']},
        'rotto',
      ],
      'mine': null,
    });
    expect(g.questions.single.correct, isNull);
    expect(g.questions.single.options.length, 4);
    expect(g.mine, isNull);
    final done = QuizGame({'questions': [{'correct': 2}], 'mine': [2], 'theirs': [1, 'x']});
    expect(done.questions.single.correct, 2);
    expect(done.theirs, [1, -1]);
  });

  test('sondaggi: voti, il mio voto, modelli con etichette', () {
    final p = ClassPoll({'id': 'p', 'question': 'Pizza?', 'options': ['Sì', 'No'], 'counts': [3, 1], 'myChoice': 0, 'open': true, 'endsAt': 0});
    expect(p.votes, 4);
    expect(p.myChoice, 0);
    expect(ClassPoll({'counts': null}).votes, 0);
    final t = PollTemplates({
      'templates': [
        {'id': 's01', 'text': 'Quando studiamo?', 'source': 'days', 'options': []},
      ],
      'subjects': ['Matematica'],
      'days': ['lunedì'],
      'dayLabels': ['Monday'],
    });
    expect(t.templates.single.source, 'days');
    expect(t.dayLabels, ['Monday']);
    expect(t.subjectLabels, isEmpty);
  });

  test('studio insieme', () {
    final b = StudyBuddy({'code': 'X', 'nickname': 'Leo', 'subject': 'Fisica', 'until': 1000, 'withMe': true});
    expect(b.withMe, isTrue);
    expect(b.until.millisecondsSinceEpoch, 1000);
    expect(StudyBuddy({}).avatar, '🙂');
  });
}

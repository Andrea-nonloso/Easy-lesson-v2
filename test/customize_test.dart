import 'package:easy_lesson/agenda.dart';
import 'package:easy_lesson/bag.dart';
import 'package:easy_lesson/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    nicknames.clear();
    subjectEmojis.clear();
  });

  test('soprannomi ed emoji nelle lezioni', () {
    nicknames['Matematica'] = 'Mate';
    subjectEmojis['Matematica'] = '🧮';
    nicknames['Docente 2'] = 'Il Prof';
    final l = Lesson(index: 0, text: 'Matematica\nDocente 2 · Docente 3', lab: '', sostegno: const []);
    expect(l.title, '🧮 Mate');
    expect(l.rawTitle, 'Matematica');
    expect(l.details.first, 'Il Prof · Docente 3');
  });

  test('lo zaino guarda la materia originale anche con il soprannome', () {
    nicknames['Matematica'] = 'Mate';
    final day = DaySchedule([Lesson(index: 0, text: 'Matematica\nDocente 2', lab: '', sostegno: const [])]);
    expect(bagItems(day, defaultBagRules), contains('Calcolatrice 🧮'));
  });

  test('agenda: stessa materia con o senza emoji', () {
    final a = AgendaItem(id: '1', date: DateTime(2026, 11, 2), kind: 'verifica', subject: 'Mate', text: '');
    expect(a.sameSubject('🧮 Mate'), isTrue);
    expect(a.sameSubject('mate'), isTrue);
    expect(a.sameSubject('Fisica'), isFalse);
  });

  test('campanelle scelte a mano', () {
    final labels = bellLabels([(470, 520), (520, 570), (580, 630)]);
    expect(labels.first, '07:50 - 08:40');
    final slots = TimeSlot.parseAll(labels);
    final pauses = breaksOf(slots);
    expect(pauses.length, 1);
    expect(pauses.first.afterIndex, 1);
    expect(pauses.first.label, 'Ricreazione 09:30 – 09:40');
  });
}

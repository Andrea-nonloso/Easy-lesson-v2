import 'dart:io';

import 'package:easy_lesson/agenda.dart';
import 'package:easy_lesson/models.dart';
import 'package:easy_lesson/timetable.dart';
import 'package:easy_lesson/xlsx.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Timetable tt;

  setUpAll(() {
    tt = Timetable.parse(readXlsx(File('test/fixtures/orario_esempio.xlsx').readAsBytesSync()));
  });

  test('dov\'è il prof', () {
    final t = tt.docenti.firstWhere((d) => teacherLabel(d) == 'Docente 001');
    final at = tt.teacherAt(t, 0, 0); // lunedì, 1ª ora
    expect(at.classes, contains('3B BS'));
    expect(tt.teacherHours(t, 0), contains(0));
  });

  test('laboratori: elenco e occupazione', () {
    expect(tt.labs, contains('W Microb'));
    expect(tt.labUse('W Microb', 0, 1), contains('3B BS')); // lunedì, 2ª ora
  });

  test('prossima data di un giorno della settimana', () {
    final ven = DateTime(2026, 10, 30, 9, 0); // venerdì
    expect(nextDateFor(4, ven), DateTime(2026, 10, 30));
    expect(nextDateFor(4, ven, endMinutes: 8 * 60), DateTime(2026, 11, 6)); // lezione già finita
    expect(nextDateFor(0, ven), DateTime(2026, 11, 2)); // lunedì dopo
    expect(friendlyDate(DateTime(2026, 10, 31), ven), 'Domani');
  });

  test('agenda: salvataggio e lettura', () {
    final a = AgendaItem(id: '1', date: DateTime(2026, 11, 2), kind: 'verifica', subject: 'Matematica', text: 'equazioni');
    final b = AgendaItem.fromJson(a.toJson())!;
    expect(b.date, DateTime(2026, 11, 2));
    expect(b.summary, '📝 Verifica · Matematica: equazioni');
    expect(b.sameSubject(' matematica '), true);
  });
}

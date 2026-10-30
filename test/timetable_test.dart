import 'dart:io';

import 'package:easy_lesson/models.dart';
import 'package:easy_lesson/timetable.dart';
import 'package:easy_lesson/xlsx.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Timetable tt;

  setUpAll(() {
    final bytes = File('test/fixtures/orario_esempio.xlsx').readAsBytesSync();
    tt = Timetable.parse(readXlsx(bytes));
  });

  test('legge giorni, ore ed elenchi', () {
    expect(tt.days, 5);
    expect(tt.hours, 7);
    expect(tt.classi.length, 83);
    expect(tt.docenti.length, 275);
    expect(tt.classi, contains('3B BS'));
    expect(tt.classi, isNot(contains('POT')));
  });

  test('orario di una classe', () {
    const ref = ScheduleRef('3B BS', prof: false);
    expect(tt.has(ref), true);
    final week = WeekSchedule.fromJson(tt.scheduleJson(ref), prof: false);
    final lun = week.days[0];
    expect(lun.lessons.length, 6); // lunedì 6 ore
    expect(week.days[2].lessons.length, 7); // mercoledì 7 ore
    expect(lun.lessons[0].title, 'Discipline sanitarie');
    expect(lun.lessons[0].details, ['Docente 001']);
    expect(lun.lessons[1].title, 'Scienze naturali');
    expect(lun.lessons[1].details, ['Docente 103 · Docente 157']);
    expect(lun.lessons[1].lab, 'W Microb');
    expect(lun.lessons[1].sostegno, ['Sostegno 054']);
  });

  test('la classe si trova anche con maiuscole diverse', () {
    expect(tt.has(const ScheduleRef('5a inf', prof: false)), true);
  });

  test('orario di un docente', () {
    const ref = ScheduleRef('A015 Docente 001', prof: true);
    expect(ref.displayName, 'Docente 001');
    expect(ref.kindLabel, 'Docente · Discipline sanitarie');
    final week = WeekSchedule.fromJson(tt.scheduleJson(ref), prof: true);
    expect(week.days[0].lessons.map((l) => l.title).toList(), ['3B BS', '4B BS', '4B BS']);
  });

  test('materie personalizzate per codice e per docente', () {
    const ref = ScheduleRef('3B BS', prof: false);
    subjectOverrides['A015'] = 'Igiene';
    teacherSubjectOverrides['A050 Docente 103'] = 'Biologia';
    final lun = WeekSchedule.fromJson(tt.scheduleJson(ref), prof: false).days[0];
    expect(lun.lessons[0].title, 'Igiene');
    expect(lun.lessons[1].title, 'Biologia');
    subjectOverrides.clear();
    teacherSubjectOverrides.clear();
    expect(WeekSchedule.fromJson(tt.scheduleJson(ref), prof: false).days[0].lessons[0].title, 'Discipline sanitarie');
  });
}

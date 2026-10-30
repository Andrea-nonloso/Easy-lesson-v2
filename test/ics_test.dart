import 'package:easy_lesson/ics.dart';
import 'package:easy_lesson/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('esporta le lezioni in formato .ics, unendo le ore consecutive', () {
    final raw = {
      'giorno0': {
        'ora1': 'Matematica\nRossi',
        'ora2': 'Matematica\nRossi',
        'ora3': 'Chimica\nBianchi',
        'lab3': 'W Chim biennio',
        'oreGiorno': 3,
      },
    };
    final week = WeekSchedule.fromJson(raw, prof: false);
    final ics = buildIcs(
      ref: const ScheduleRef('3B BS', prof: false),
      week: week,
      slots: slotsFrom(const []),
      now: DateTime(2026, 10, 28),
    );
    expect(ics, startsWith('BEGIN:VCALENDAR'));
    expect('BEGIN:VEVENT'.allMatches(ics).length, 2); // Matematica (2 ore unite) + Chimica
    expect(ics, contains('DTSTART:20261026T075000')); // lunedì 7:50
    expect(ics, contains('DTEND:20261026T093000')); // fine 2ª ora
    expect(ics, contains('RRULE:FREQ=WEEKLY;UNTIL=20270610T235959'));
    expect(ics, contains('LOCATION:W Chim biennio'));
    expect(ics.split('\r\n').every((l) => l.length <= 75), true);
  });
}

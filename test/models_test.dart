import 'package:easy_lesson/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('decodeOrario gestisce il JSON dentro una stringa', () {
    const body = r'"{\"giorno0\":{\"ora1\":\"MATEMATICA\\nROSSI\",\"oreGiorno\":\"2\",\"lab1\":\"LAB 1\",\"sostegno\":[\"BIANCHI, VERDI\"]}}"';
    final m = decodeOrario(body);
    final w = WeekSchedule.fromJson(m, prof: false);
    expect(w.days.length, 1);
    final day = w.days.first;
    expect(day.lessons.length, 2); // oreGiorno = 2
    expect(day.lessons.first.title, 'MATEMATICA');
    expect(day.lessons.first.details, ['ROSSI']);
    expect(day.lessons.first.lab, 'LAB 1');
    expect(day.lessons.first.sostegno, ['BIANCHI', 'VERDI']);
    expect(day.lessons[1].isEmpty, true);
  });

  test('decodeOrario accetta anche JSON normale', () {
    final m = decodeOrario('{"giorno0":{"ora1":"A"},"giorno1":{"ora1":"B"}}');
    expect(WeekSchedule.fromJson(m, prof: true).days.length, 2);
  });

  test('fasce orarie', () {
    const xml = '<ore><ora>08:00 - 09:00</ora><ora>9.00-10.00</ora><ora>10:00</ora></ore>';
    final slots = TimeSlot.parseAll(parseOreXml(xml));
    expect(slots.length, 3);
    expect(slots[0].start, 8 * 60);
    expect(slots[0].end, 9 * 60);
    expect(slots[1].startText, '09:00');
    expect(slots[2].end, 11 * 60);
  });

  test('campanelle predefinite e ricreazioni', () {
    final slots = slotsFrom(const []); // server non disponibile
    expect(slots.length, 7);
    expect(slots.first.startText, '07:50');
    expect(slots[3].startText, '10:30');
    final breaks = breaksOf(slots);
    expect(breaks.length, 2);
    expect(breaks[0].afterIndex, 2); // dopo la 3ª ora
    expect(breaks[0].label, 'Ricreazione 10:20 – 10:30');
    expect(breaks[1].afterIndex, 4); // dopo la 5ª ora
    expect(currentSlot(slots, DateTime(2026, 10, 28, 10, 25)), null);
    expect(currentSlot(slots, DateTime(2026, 10, 28, 12, 30)), 5);
  });

  test('ricerca senza accenti e spazi', () {
    expect(normalizeSearch("D'Alonzo Niccolò"), 'dalonzoniccolo');
    expect(normalizeSearch('3 A').contains(normalizeSearch('3a')), true);
  });

  test('weekend mostra la settimana successiva', () {
    final sabato = DateTime(2026, 10, 31); // sabato
    expect(todayIndex(sabato, 5), -1);
    expect(weekStart(sabato, 5), DateTime(2026, 11, 2));
    final mercoledi = DateTime(2026, 10, 28);
    expect(todayIndex(mercoledi, 5), 2);
    expect(weekStart(mercoledi, 5), DateTime(2026, 10, 26));
  });

  test('testo del server "A041 Rossi con B016 Bianchi" diventa materia + docenti', () {
    final l = Lesson(index: 0, text: 'A041 Fieramonti con B016 Russo', lab: '', sostegno: const []);
    expect(l.title, 'Informatica');
    expect(l.details, ['Fieramonti · Russo']);
    final irc = Lesson(index: 0, text: '_IRC Fiorella', lab: '', sostegno: const []);
    expect(irc.title, 'Religione');
    expect(irc.details, ['Fiorella']);
    // Testo libero (es. classe nell'orario di un docente): invariato
    expect(Lesson(index: 0, text: '3B BS', lab: '', sostegno: const []).title, '3B BS');
  });
}

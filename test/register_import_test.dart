import 'package:easy_lesson/register_import.dart';
import 'package:easy_lesson/school_life.dart';
import 'package:flutter_test/flutter_test.dart';

// Testo come esce da "Copia testo" su uno screenshot del registro (con le lettere dei pallini e gli a capo a caso).
const sample = '''
Andrea Assenze
Percentuale assenze totali 3.1%
1^ QUADRIMESTRE
Giustificate
Assenze Ritardi Uscite Rientri
4 5 4 0
30/10/2026
R Ritardi
Entra alle 08:40:00 - Ora di
lezione: 2
Non concorre al calcolo
28/10/2026
U Uscite
Entra alle 12:00:00 - Ora di
lezione: 5
Concorre al calcolo
26/10/2026
R Ritardi
Entra alle 08:00:00 - Ora di
lezione: 2
Concorre al calcolo
22/10/2026
A Assenze
Concorre al calcolo
16/10/2026
A
Assenze
Concorre al calcolo
15/10/2026
Uscite
Entra alle 12:20:00 - Ora di lezione: 6
Non concorre al calcolo
05/10/2026
Uscite
Entra alle 13:30:00 - Ora di lezione:
6
Concorre al calcolo
22/10/2026
A Assenze
Concorre al calcolo
''';

void main() {
  test('legge le schede del registro', () {
    final l = parseRegisterText(sample);
    expect(l.length, 7); // il 22/10 doppio conta una volta
    final r = l.firstWhere((e) => e.date == DateTime(2026, 10, 30));
    expect(r.kind, 'entrata');
    expect(r.hour, 2);
    expect(r.time, '08:40');
    expect(r.counts, isFalse);
    final u = l.firstWhere((e) => e.date == DateTime(2026, 10, 28));
    expect(u.kind, 'uscita');
    expect(u.hour, 4); // esce durante la 5ª = dopo la 4ª
    expect(u.counts, isTrue);
    final u2 = l.firstWhere((e) => e.date == DateTime(2026, 10, 5));
    expect(u2.hour, 5);
    expect(l.where((e) => e.kind == 'assenza').length, 2);
    expect(l.first.date, DateTime(2026, 10, 30)); // dal più recente
  });

  test('doppioni con quello che c è già e testo strano', () {
    final l = parseRegisterText(sample);
    final existing = [AbsenceEntry(id: '1', date: DateTime(2026, 10, 22), kind: 'assenza')];
    expect(l.where((e) => alreadyThere(e, existing)).length, 1);
    expect(parseRegisterText('ciao 31/02/2026 Assenze'), isEmpty);
    expect(parseRegisterText(''), isEmpty);
  });
}

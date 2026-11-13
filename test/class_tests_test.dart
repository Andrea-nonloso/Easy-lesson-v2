import 'package:easy_lesson/agenda.dart';
import 'package:easy_lesson/class_tests.dart';
import 'package:easy_lesson/social.dart';
import 'package:flutter_test/flutter_test.dart';

ClassItem _i(String id, String kind, String subject, String day, int confirms) =>
    ClassItem({'id': id, 'kind': kind, 'subject': subject, 'title': 'Cap. 3', 'day': day, 'confirms': confirms});

void main() {
  final now = DateTime(2026, 11, 12, 10);

  test('entrano solo le verifiche future con almeno 3 conferme, una volta sola', () {
    final items = [
      _i('a', 'test', 'MATEMATICA', '2026-11-20', 3),
      _i('b', 'test', 'STORIA', '2026-11-20', 2),
      _i('c', 'homework', 'ITALIANO', '2026-11-20', 9),
      _i('d', 'test', 'FISICA', '2026-11-01', 5),
      _i('e', 'test', 'INGLESE', '2026-11-12', 4),
      _i('f', 'test', 'CHIMICA', '2026-11-21', 6),
    ];
    final r = classTestsToImport(items, const [], {'f'}, now);
    expect(r.map((i) => i.id), ['a', 'e']);
  });

  test('niente doppioni se in agenda c\'è già una verifica di quella materia quel giorno', () {
    final agenda = [AgendaItem(id: 'x', date: DateTime(2026, 11, 20), kind: 'verifica', subject: 'Matematica', text: '')];
    expect(classTestsToImport([_i('a', 'test', 'MATEMATICA', '2026-11-20', 4)], agenda, {}, now), isEmpty);
  });
}

import 'package:easy_lesson/formulary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('118 elementi, numeri atomici in ordine e posizioni uniche', () {
    expect(elements.length, 118);
    for (var i = 0; i < elements.length; i++) {
      expect(elements[i].z, i + 1);
    }
    final pos = {for (final e in elements) (e.row, e.col)};
    expect(pos.length, 118);
  });

  test('id delle formule unici e gruppi esistenti', () {
    expect({for (final f in formulas) f.id}.length, formulas.length);
    final groups = {for (final s in formulaSections) for (final g in s.groups) g.$1};
    for (final f in formulas) {
      expect(groups, contains(f.group), reason: f.id);
    }
  });

  test('ricerca senza accenti e per simbolo', () {
    expect(searchFormulas('pitagora').map((f) => f.id), contains('m20'));
    expect(searchFormulas('velocita').isNotEmpty, isTrue);
    expect(searchElements('fe').first.it, 'Ferro');
    expect(searchElements('26').first.symbol, 'Fe');
    expect(searchVerbs('went').single.$1, 'go');
    expect(searchVerbs('').length, irregularVerbs.length);
  });
}

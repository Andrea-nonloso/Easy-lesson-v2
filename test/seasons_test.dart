import 'package:easy_lesson/missions.dart';
import 'package:easy_lesson/seasons.dart';
import 'package:easy_lesson/shop.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('eventi attivi per data, anche a cavallo di capodanno', () {
    expect(activeSeason(DateTime(2026, 10, 31))?.id, 'halloween');
    expect(activeSeason(DateTime(2026, 11, 6)), isNull);
    expect(activeSeason(DateTime(2026, 12, 25))?.id, 'natale');
    expect(activeSeason(DateTime(2027, 1, 6))?.id, 'natale');
    expect(activeSeason(DateTime(2027, 1, 7)), isNull);
    expect(activeSeason(DateTime(2027, 2, 14))?.id, 'sanvalentino');
    expect(activeSeason(DateTime(2027, 6, 1))?.id, 'finescuola');
  });

  test('fine dell\'evento', () {
    expect(seasonById('natale')!.endFor(DateTime(2026, 12, 20)), DateTime(2027, 1, 6));
    expect(seasonById('natale')!.endFor(DateTime(2027, 1, 2)), DateTime(2027, 1, 6));
    expect(seasonById('halloween')!.endFor(DateTime(2026, 10, 25)), DateTime(2026, 11, 5));
  });

  test('ogni oggetto e missione a tempo punta a un evento che esiste, e ogni evento ha la sua missione', () {
    for (final i in shopItems.where((i) => i.season != null)) {
      expect(seasonById(i.season), isNotNull, reason: i.id);
    }
    for (final s in seasons) {
      expect(dailyMissions.where((m) => m.id == 's_${s.id}' && m.season == s.id), hasLength(1));
      expect(shopItems.where((i) => i.season == s.id), isNotEmpty);
    }
  });
}

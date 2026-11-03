import 'package:easy_lesson/cloud.dart';
import 'package:easy_lesson/progress.dart';
import 'package:easy_lesson/store.dart' show backupSectionOf, backupSections, defaultBackupSections, isSensitiveKey;
import 'package:easy_lesson/ui/achievements.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('livelli', () {
    test('XP per livello: 0, 50, 125, 225…', () {
      expect(xpForLevel(1), 0);
      expect(xpForLevel(2), 50);
      expect(xpForLevel(3), 125);
      expect(xpForLevel(4), 225);
      for (var l = 1; l < 60; l++) {
        expect(xpForLevel(l + 1) - xpForLevel(l), xpToNext(l));
      }
    });

    test('livello dalle XP', () {
      expect(levelForXp(0), 1);
      expect(levelForXp(49), 1);
      expect(levelForXp(50), 2);
      expect(levelForXp(124), 2);
      expect(levelForXp(125), 3);
      for (var l = 1; l < 60; l++) {
        expect(levelForXp(xpForLevel(l)), l);
        expect(levelForXp(xpForLevel(l + 1) - 1), l);
      }
    });

    test('LevelInfo', () {
      final i = LevelInfo(100);
      expect(i.level, 2);
      expect(i.inLevel, 50);
      expect(i.needed, 75);
      expect(i.fraction, closeTo(50 / 75, 1e-9));
      expect(i.nextReward, 5);
      expect(LevelInfo(xpForLevel(5)).nextReward, 10);
      expect(levelTitle(1), 'Matricola');
      expect(levelTitle(12), 'Rappresentante');
      expect(levelRank(4), 0);
      expect(levelRank(5), 1);
      expect(levelRank(99), 6);
    });
  });

  group('progressi', () {
    test('unione: tutti gli obiettivi, contatori al massimo', () {
      final a = ProgressData(achievements: {'first', 'ten'}, counters: {'days': 3, 'views': 10});
      final b = ProgressData(achievements: {'mine'}, counters: {'days': 2, 'views': 50, 'x': 1});
      final m = a.merge(b);
      expect(m.achievements, {'first', 'ten', 'mine'});
      expect(m.counters, {'days': 3, 'views': 50, 'x': 1});
      expect(m.sameAs(b.merge(a)), isTrue);
      expect(m.sameAs(a), isFalse);
    });

    test('JSON andata e ritorno, roba strana scartata', () {
      final p = ProgressData.fromJson({
        'achievements': ['ok', 3, '<x>', 'a' * 50],
        'counters': {'a': -1, 'b': 'x', 'c': 2.7, 'd': '4', 'e f': 1},
      });
      expect(p.achievements, {'ok'});
      expect(p.counters, {'c': 2, 'd': 4});
      expect(ProgressData.fromJson(p.toJson()).sameAs(p), isTrue);
      expect(ProgressData.fromJson('boh').achievements, isEmpty);
    });

    test('serie di giorni', () {
      final now = DateTime(2026, 11, 2, 10);
      expect(dayKey(now), '2026-11-02');
      expect(nextStreak(null, 0, now), 1);
      expect(nextStreak('2026-11-02', 4, now), 4);
      expect(nextStreak('2026-11-01', 4, now), 5);
      expect(nextStreak('2026-10-30', 4, now), 1);
      // Cambio mese e anno.
      expect(nextStreak('2026-10-31', 2, DateTime(2026, 11, 1)), 3);
      expect(nextStreak('2025-12-31', 2, DateTime(2026, 1, 1)), 3);
    });
  });

  group('codice account', () {
    test('spazi e trattini non contano', () {
      expect(normalizeAccountCode(' Ab3\$k-9€xQ#-zz '), 'Ab3\$k9€xQ#zz');
      expect(looksLikeAccountCode('Ab3\$k-9€xQ#-zzzz-aaaa'), isTrue);
      expect(looksLikeAccountCode('corto'), isFalse);
    });
  });

  group('obiettivi', () {
    test('più di 50, id unici e validi per il server', () {
      expect(achievements.length, greaterThan(50));
      final ids = achievements.map((a) => a.id).toList();
      expect(ids.toSet().length, ids.length);
      final re = RegExp(r'^[\w.\-]{1,40}$');
      for (final a in achievements) {
        expect(re.hasMatch(a.id), isTrue, reason: a.id);
        expect(achievementCategories.any((c) => c.$1 == a.category), isTrue, reason: a.id);
        if (a.goal != null) expect(a.progress, isNotNull, reason: a.id);
      }
    });
  });

  group('backup', () {
    test('ogni chiave ha la sua sezione', () {
      expect(backupSectionOf('el.grades'), 'scuola');
      expect(backupSectionOf('el.schedules'), 'orari');
      expect(backupSectionOf('el.xlsx'), 'excel');
      expect(backupSectionOf('el.themeId'), 'aspetto');
      expect(backupSectionOf('el.agenda'), 'agenda');
      expect(backupSectionOf('el.extras'), 'opzioni');
      expect(backupSectionOf('el.chiaveNuova'), 'opzioni');
      expect(defaultBackupSections.contains('excel'), isFalse);
      // Cifrate nel backup online
      for (final k in ['el.grades', 'el.absences', 'el.agenda', 'el.teachers', 'el.username', 'el.studyLog', 'el.extras', 'el.nicknames', 'el.chiaveNuova']) {
        expect(isSensitiveKey(k), isTrue, reason: k);
      }
      for (final k in ['el.schedules', 'el.themeId', 'el.subjectEmojis', 'el.xlsx']) {
        expect(isSensitiveKey(k), isFalse, reason: k);
      }
      for (final s in defaultBackupSections) {
        expect(backupSections.any((b) => b.$1 == s), isTrue);
      }
    });
  });
}

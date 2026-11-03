import 'package:easy_lesson/social.dart';
import 'package:easy_lesson/ui/code_scanner.dart' show parseCodeText;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('classe e amici', () {
    test('link nei QR', () {
      expect(parseCodeText(classLink('K7PQ2MXA')), ('class', 'K7PQ2MXA'));
      expect(parseCodeText(friendLink('ABCD2345')), ('friend', 'ABCD2345'));
      expect(parseCodeText('easylesson://class?c='), ('raw', 'easylesson://class?c='));
    });

    test('date e modelli', () {
      expect(isoDate(DateTime(2026, 3, 7)), '2026-03-07');
      final it = ClassItem({'id': 'x', 'kind': 'test', 'title': 'Verifica', 'day': '2026-11-05', 'confirms': 3, 'confirmedByMe': true});
      expect(it.date, DateTime(2026, 11, 5));
      expect(it.confirms, 3);
      expect(it.confirmedByMe, isTrue);
      expect(it.author, 'Un compagno');
      final c = ClassChallenge({'target': 200, 'done': 250});
      expect(c.progress, 1.0);
      expect(c.completed, isTrue);
      final f = FriendsData({
        'leaderboard': [
          {'code': 'A', 'nickname': 'Anna', 'weekXp': 30, 'rank': 1, 'me': true},
          'rotto',
        ],
      });
      expect(f.leaderboard.single.me, isTrue);
      expect(f.friends, isEmpty);
    });

    test('avatar e metriche', () {
      expect(socialAvatars.toSet().length, socialAvatars.length);
      expect(challengeMetrics.keys, containsAll(['studied', 'agendaDone', 'days']));
    });
  });
}

import 'package:easy_lesson/announcements.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('avvisi', () {
    test('si leggono dal JSON del server', () {
      final a = Announcement.fromJson({
        'id': 'a1',
        'title': 'Sciopero',
        'body': 'Domani niente scuola',
        'level': 'warning',
        'link': 'https://example.org',
        'starts': 1000,
        'ends': 2000,
      })!;
      expect(a.title, 'Sciopero');
      expect(a.level, 'warning');
      expect(a.urgent, isFalse);
      expect(a.link, 'https://example.org');
      expect(a.ends.millisecondsSinceEpoch, 2000);
    });

    test('dati strani: livello predefinito, link solo http(s), righe rotte scartate', () {
      final a = Announcement.fromJson({'id': 'x', 'title': 'T', 'level': 'boh', 'link': 'javascript:alert(1)', 'starts': 1, 'ends': 2})!;
      expect(a.level, 'info');
      expect(a.link, isNull);
      expect(Announcement.fromJson({'title': 'senza id', 'starts': 1, 'ends': 2}), isNull);
      expect(Announcement.fromJson('niente'), isNull);
      expect(Announcement.fromJson({'id': 'u', 'title': 'U', 'level': 'urgent', 'starts': 1, 'ends': 2})!.urgent, isTrue);
    });
  });
}

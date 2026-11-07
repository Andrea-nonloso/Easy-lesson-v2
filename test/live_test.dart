// 3.8: canale in diretta lato app. Lettore SSE, pallini dei non letti, "sta scrivendo", server diretti attendibili.
import 'package:easy_lesson/cloud.dart';
import 'package:easy_lesson/live.dart';
import 'package:easy_lesson/live_sse.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SseParser', () {
    test('blocchi interi, a pezzi, battito, più righe di dati', () {
      final p = SseParser();
      expect(p.add('retry: 3000\n\n'), isEmpty);
      expect(p.add('event: hello\ndata: {"node":"casa"}\n\n').single.event, 'hello');
      // a pezzi, anche a metà riga
      expect(p.add('event: ch'), isEmpty);
      expect(p.add('at\ndata: {"classId":"ab'), isEmpty);
      final f = p.add('c"}\n\n: ping\n\n');
      expect(f, hasLength(1));
      expect(f.single.event, 'chat');
      expect(f.single.data, '{"classId":"abc"}');
      // fine riga di Windows e più righe di dati
      final g = p.add('event: x\r\ndata: uno\r\ndata: due\r\n\r\n');
      expect(g.single.data, 'uno\ndue');
      // senza "event:" è un "message"
      expect(p.add('data: ciao\n\n').single.event, 'message');
    });
  });

  group('Live', () {
    final live = Live.instance;
    setUp(() {
      live.unread.clear();
      live.viewing.clear();
    });

    test('messaggi degli altri = non letti; i miei e quelli della chat aperta no', () {
      live.handle(LiveEvent('chat', {'classId': 'aaaa'}));
      live.handle(LiveEvent('chat', {'classId': 'aaaa'}));
      live.handle(LiveEvent('chat', {'classId': 'aaaa', 'mine': true}));
      live.handle(LiveEvent('adult', {}));
      live.handle(LiveEvent('notice', {}));
      expect(live.unreadOf('class:aaaa'), 2);
      expect(live.unreadOf('adult'), 1);
      expect(live.unreadClasses, 2);
      expect(live.totalUnread, 4);
      // aperta la chat: si azzera e i nuovi non contano
      live.openChat('class:aaaa');
      expect(live.unreadOf('class:aaaa'), 0);
      live.handle(LiveEvent('chat', {'classId': 'aaaa'}));
      expect(live.unreadOf('class:aaaa'), 0);
      live.closeChat('class:aaaa');
      live.handle(LiveEvent('chat', {'classId': 'aaaa'}));
      expect(live.unreadOf('class:aaaa'), 1);
      live.markRead('adult');
      expect(live.totalUnread, 2);
      // eventi che non sono messaggi non contano
      live.handle(LiveEvent('friends', {}));
      live.handle(LiveEvent('me', {}));
      expect(live.totalUnread, 2);
    });

    test('"sta scrivendo" dura qualche secondo e sparisce quando arriva il messaggio', () {
      live.handle(LiveEvent('typing', {'chat': 'class:bbbb', 'who': '🦊 Anna'}));
      expect(live.typingIn('class:bbbb'), '🦊 Anna');
      expect(live.typingIn('adult'), isNull);
      expect(live.unreadOf('class:bbbb'), 0); // scrivere non è un messaggio
      live.handle(LiveEvent('chat', {'classId': 'bbbb'}));
      expect(live.typingIn('class:bbbb'), isNull);
    });

    test('hello = collegati; gli eventi arrivano anche alle pagine', () async {
      final got = <String>[];
      final sub = live.events.listen((e) => got.add(e.type));
      live.handle(LiveEvent('hello', {'node': 'nodo2', 'heartbeat': 25}));
      expect(live.connected, isTrue);
      expect(live.node, 'nodo2');
      live.handle(LiveEvent('friends', {}));
      await Future<void>.delayed(Duration.zero);
      expect(got, ['friends']);
      await sub.cancel();
    });
  });

  test('il token va solo ai nostri server diretti (https://easylesson-*.stesso dominio)', () {
    bool ok(String u) => Cloud.isTrustedLiveServer(Uri.parse(u));
    final official = Uri.parse(cloudDefaultUrl);
    final parent = official.host.substring(official.host.indexOf('.') + 1);
    expect(ok(cloudDefaultUrl), isTrue);
    expect(ok('https://easylesson-casa.$parent'), isTrue);
    expect(ok('https://easylesson-nodo2.$parent/'), isTrue);
    expect(ok('http://easylesson-casa.$parent'), isFalse); // niente http
    expect(ok('https://easylesson-casa.$parent:8443'), isFalse); // niente porte strane
    expect(ok('https://casa.$parent'), isFalse); // solo easylesson-*
    expect(ok('https://easylesson-casa.$parent.cattivo.com'), isFalse);
    expect(ok('https://easylesson-casa.altro.cc'), isFalse);
    expect(ok('https://x.easylesson-casa.$parent'), isFalse);
  });
}

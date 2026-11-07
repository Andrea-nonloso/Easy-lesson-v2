// 3.8: grandi lato app. Sticker riconosciuti dai byte, conversazioni private, pallini dei privati.
import 'dart:typed_data';

import 'package:easy_lesson/live.dart';
import 'package:easy_lesson/social.dart';
import 'package:easy_lesson/stickers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('sticker: WebP, PNG, GIF sì; il resto no', () {
    Uint8List b(List<int> x) => Uint8List.fromList(x);
    expect(StickerStore.kind(b([...'RIFF'.codeUnits, 0, 0, 0, 0, ...'WEBP'.codeUnits])), 'webp');
    expect(StickerStore.kind(b([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])), 'png');
    expect(StickerStore.kind(b([...'GIF89a'.codeUnits])), 'gif');
    expect(StickerStore.kind(b([0xff, 0xd8, 0xff])), isNull); // le foto JPEG non sono sticker
    expect(StickerStore.kind(b('<svg>'.codeUnits)), isNull);
  });

  test('conversazioni private: richieste, ultimo messaggio', () {
    final req = DmThread({
      'id': 'a' * 16,
      'with': {'handle': 'b' * 12, 'nickname': 'Bruno', 'avatar': '🦊'},
      'status': 'pending',
      'startedByMe': false,
      'unread': 2,
      'last': {'text': '', 'kind': 'photo', 'at': 1, 'byMe': false},
    });
    expect(req.isRequestForMe, isTrue);
    expect(req.other.label, '🦊 Bruno');
    expect(req.lastText, '📷 Foto');
    final mine = DmThread({'status': 'pending', 'startedByMe': true, 'last': {'text': 'ciao', 'kind': 'text', 'at': 1, 'byMe': true}});
    expect(mine.isRequestForMe, isFalse);
    expect(mine.lastText, 'Tu: ciao');
    final m = ChatMessage({'id': 'x', 'text': '', 'media': 'media/${'0' * 64}.webp', 'kind': 'sticker', 'handle': 'c' * 12});
    expect(m.kind, 'sticker');
    expect(m.handle, 'c' * 12);
  });

  test('privati in diretta: non letti per conversazione e in tutto', () {
    final live = Live.instance;
    live.unread.clear();
    live.viewing.clear();
    live.handle(LiveEvent('dm', {'threadId': 'aaaa'}));
    live.handle(LiveEvent('dm', {'threadId': 'aaaa'}));
    live.handle(LiveEvent('dm', {'threadId': 'bbbb'}));
    live.handle(LiveEvent('dm', {'threadId': 'bbbb', 'mine': true}));
    expect(live.unreadOf('dm:aaaa'), 2);
    expect(live.unreadDm, 3);
    live.handle(LiveEvent('typing', {'chat': 'dm:aaaa', 'who': '🦊 Anna'}));
    expect(live.typingIn('dm:aaaa'), '🦊 Anna');
    live.markReadPrefix('dm:');
    expect(live.unreadDm, 0);
  });
}

// Esporta oggetti del negozio e obiettivi per l'app della moderazione (pagina progressi di un utente).
// Si rigenera con: CATALOG=../../easy-lesson-moderazione/assets/catalog.json flutter test test/catalogo_moderazione_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:easy_lesson/progress.dart';
import 'package:easy_lesson/shop.dart';
import 'package:easy_lesson/ui/achievements.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('catalogo per la moderazione', () {
    final out = {
      'xpPerCoin': xpPerCoin,
      'xpPerDay': xpPerDay,
      'items': [
        for (final i in shopItems) {'id': i.id, 'slot': i.slot, 'name': i.name, 'emoji': i.preview, 'price': i.price},
      ],
      'achievements': [
        for (final a in achievements) {'id': a.id, 'emoji': a.emoji, 'title': a.titleIt, 'xp': a.tier.xp, 'secret': a.secret},
      ],
    };
    expect((out['items'] as List).isNotEmpty, isTrue);
    final path = Platform.environment['CATALOG'];
    if (path != null) File(path).writeAsStringSync(const JsonEncoder.withIndent(' ').convert(out));
  });
}

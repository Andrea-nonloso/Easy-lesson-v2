import 'package:easy_lesson/shop.dart';
import 'package:easy_lesson/ui/achievements.dart' show LevelBadge;
import 'package:easy_lesson/ui/theme.dart' show shopThemes, appThemes;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('negozio', () {
    test('catalogo coerente', () {
      final ids = shopItems.map((i) => i.id).toList();
      expect(ids.toSet().length, ids.length, reason: 'id doppi');
      for (final i in shopItems) {
        expect(shopSlots.containsKey(i.slot), isTrue, reason: i.id);
        expect(i.id.startsWith('${i.slot}.'), isTrue, reason: i.id);
        expect(i.price, greaterThan(0));
        // la chiave del contatore sincronizzato deve passare il controllo del server: [\w.\-]{1,40}
        expect(RegExp(r'^[\w.\-]{1,40}$').hasMatch('own.${i.id}'), isTrue, reason: i.id);
      }
    });

    test('ogni cornice e ogni tema esistono davvero', () {
      for (final i in shopItems.where((i) => i.slot == 'frame')) {
        expect(LevelBadge.frameColors.containsKey(i.id), isTrue, reason: i.id);
      }
      final themeIds = shopThemes.map((t) => t.id).toSet();
      for (final i in shopItems.where((i) => i.slot == 'theme')) {
        expect(themeIds.contains(shopThemeId(i.id)), isTrue, reason: i.id);
      }
      // nessun tema del negozio ha lo stesso id di uno gratis
      expect(themeIds.intersection(appThemes.map((t) => t.id).toSet()), isEmpty);
    });

    test('shopItem', () {
      expect(shopItem('frame.fire')?.name, 'Fuoco');
      expect(shopItem('niente'), isNull);
      expect(shopThemeId('theme.cosmo'), 'shop_cosmo');
    });
  });
}

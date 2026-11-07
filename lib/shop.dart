import 'store.dart';
import 'i18n.dart';

/// Negozio (3.0): si spendono monete guadagnate con l'XP.
///
/// Tutto sta nei contatori "stat.*", che si sincronizzano già con l'account (il server tiene il
/// massimo di ogni contatore, quindi non si perde niente cambiando telefono):
///   stat.coinsSpent       monete spese in tutto
///   stat.coinBonus        monete regalate (eventi, Sviluppatore²)
///   stat.own.<id>  = 1    oggetto comprato
/// Cosa si sta usando (opzioni locali): shop.eq.<slot> = id.

/// 1 moneta ogni [xpPerCoin] XP.
const xpPerCoin = 4;

class ShopItem {
  const ShopItem(this.id, this.slot, this.name, this.price, this.preview, {this.minLevel = 1, this.description = ''});
  final String id;

  /// frame | title | avatar | theme
  final String slot;
  final String name;
  final int price;

  /// Emoji (o testo) da mostrare nell'anteprima.
  final String preview;
  final int minLevel;
  final String description;
}

Map<String, (String, String)> get shopSlots => {
  'frame': (tr('Cornici', 'Frames'), tr('Intorno al distintivo del livello', 'Around the level badge')),
  'title': (tr('Titoli', 'Titles'), tr('Al posto del nome del livello', 'Instead of the level name')),
  'avatar': ('Avatar', tr('Emoji speciali per classe e amici', 'Special emoji for class and friends')),
  'theme': (tr('Temi', 'Themes'), tr('Colori nuovi per tutta l\'app', 'New colors for the whole app')),
};

List<ShopItem> get shopItems => <ShopItem>[
  // Cornici del distintivo (disegnate in ui/shop_page.dart: frameColors)
  const ShopItem('frame.wood', 'frame', 'Legno intagliato', 60, '🪵'),
  const ShopItem('frame.fire', 'frame', 'Fuoco', 150, '🔥'),
  const ShopItem('frame.ice', 'frame', 'Ghiaccio', 150, '🧊'),
  const ShopItem('frame.leaf', 'frame', 'Foglie', 150, '🍃'),
  const ShopItem('frame.gold', 'frame', 'Oro', 300, '🥇', minLevel: 5),
  const ShopItem('frame.neon', 'frame', 'Neon', 350, '💡', minLevel: 8),
  const ShopItem('frame.rainbow', 'frame', 'Arcobaleno', 450, '🌈', minLevel: 10),
  const ShopItem('frame.galaxy', 'frame', 'Galassia', 700, '🌌', minLevel: 15),
  // Titoli
  ShopItem('title.secchione', 'title', tr('Il Secchione', 'The Nerd'), 100, '🤓'),
  const ShopItem('title.puntuale', 'title', 'Spaccasecondo', 100, '⏰'),
  const ShopItem('title.nottambulo', 'title', 'Nottambulo', 120, '🦉'),
  ShopItem('title.campanella', 'title', tr('Signore della campanella', 'Lord of the bell'), 150, '🔔'),
  ShopItem('title.ninja', 'title', tr('Ninja dei compiti', 'Homework ninja'), 200, '🥷', minLevel: 5),
  ShopItem('title.detective', 'title', tr('Detective dell\'orario', 'Timetable detective'), 200, '🕵️', minLevel: 5),
  const ShopItem('title.prof', 'title', 'Quasi prof', 300, '👩‍🏫', minLevel: 10),
  const ShopItem('title.leggenda', 'title', 'Leggenda vivente', 600, '🌟', minLevel: 20),
  // Avatar speciali
  const ShopItem('avatar.drago', 'avatar', 'Drago', 80, '🐉'),
  const ShopItem('avatar.leone', 'avatar', 'Leone', 80, '🦁'),
  const ShopItem('avatar.lupo', 'avatar', 'Lupo', 80, '🐺'),
  const ShopItem('avatar.squalo', 'avatar', 'Squalo', 80, '🦈'),
  const ShopItem('avatar.robot', 'avatar', 'Robot', 120, '🤖'),
  const ShopItem('avatar.alieno', 'avatar', 'Alieno', 120, '👽'),
  const ShopItem('avatar.mago', 'avatar', 'Mago', 150, '🧙'),
  const ShopItem('avatar.ninja', 'avatar', 'Ninja', 150, '🥷'),
  const ShopItem('avatar.eroe', 'avatar', 'Supereroe', 200, '🦸', minLevel: 5),
  const ShopItem('avatar.corona', 'avatar', 'Corona', 400, '👑', minLevel: 12),
  // Temi (definiti in ui/theme.dart: shopThemes, id = 'shop_<nome>')
  const ShopItem('theme.ciliegio', 'theme', 'Ciliegio', 300, '🌸'),
  const ShopItem('theme.caramella', 'theme', 'Caramella', 300, '🍬'),
  const ShopItem('theme.abisso', 'theme', 'Abisso', 400, '🐋', minLevel: 4),
  const ShopItem('theme.matrix', 'theme', 'Matrix', 450, '💚', minLevel: 6),
  const ShopItem('theme.oro', 'theme', 'Nero e oro', 550, '🖤', minLevel: 10),
  const ShopItem('theme.cosmo', 'theme', 'Cosmo', 800, '🪐', minLevel: 15),
];

ShopItem? shopItem(String id) {
  for (final i in shopItems) {
    if (i.id == id) return i;
  }
  return null;
}

/// Id del tema dell'app per un oggetto del negozio ('theme.lava' -> 'shop_lava').
String shopThemeId(String itemId) => 'shop_${itemId.substring(6)}';

class Shop {
  Shop._();

  static int earned(int totalXp, AppStore s) => totalXp ~/ xpPerCoin + s.stat('coinBonus');
  static int spent(AppStore s) => s.stat('coinsSpent');
  static int balance(int totalXp, AppStore s) => earned(totalXp, s) - spent(s);

  static bool owns(AppStore s, String id) => s.stat('own.$id') > 0;
  static int ownedCount(AppStore s) => shopItems.where((i) => owns(s, i.id)).length;

  /// Quello che si sta usando per [slot] (null = niente).
  static String? equipped(AppStore s, String slot) {
    final id = s.opt<String?>('shop.eq.$slot', null);
    return id != null && owns(s, id) ? id : null;
  }

  /// null = comprato; altrimenti il motivo.
  static Future<String?> buy(AppStore s, ShopItem item, {required int totalXp, required int level}) async {
    if (owns(s, item.id)) return tr('Ce l\'hai già', 'You already have it');
    if (level < item.minLevel) return tr('Serve il livello ${item.minLevel}', 'You need level ${item.minLevel}');
    if (balance(totalXp, s) < item.price) return tr('Non hai abbastanza monete', 'You don\'t have enough coins');
    await s.setOpt('stat.own.${item.id}', 1);
    await s.bump('coinsSpent', item.price);
    await s.bump('shopBought');
    return null;
  }

  static Future<void> equip(AppStore s, ShopItem item) async {
    if (!owns(s, item.id)) return;
    await s.setOpt('shop.eq.${item.slot}', item.id);
    if (item.slot == 'theme') await s.setThemeId(shopThemeId(item.id));
  }

  static Future<void> unequip(AppStore s, String slot) => s.setOpt('shop.eq.$slot', null);

  /// Avatar speciali già comprati (per la scelta del profilo).
  static List<String> ownedAvatars(AppStore s) => [
        for (final i in shopItems)
          if (i.slot == 'avatar' && owns(s, i.id)) i.preview,
      ];
}

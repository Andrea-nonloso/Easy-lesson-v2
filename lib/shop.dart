import 'store.dart';

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

const shopSlots = {
  'frame': ('Cornici', 'Intorno al distintivo del livello'),
  'title': ('Titoli', 'Al posto del nome del livello'),
  'avatar': ('Avatar', 'Emoji speciali per classe e amici'),
  'theme': ('Temi', 'Colori nuovi per tutta l\'app'),
};

const shopItems = <ShopItem>[
  // Cornici del distintivo (disegnate in ui/shop_page.dart: frameColors)
  ShopItem('frame.wood', 'frame', 'Legno intagliato', 60, '🪵'),
  ShopItem('frame.fire', 'frame', 'Fuoco', 150, '🔥'),
  ShopItem('frame.ice', 'frame', 'Ghiaccio', 150, '🧊'),
  ShopItem('frame.leaf', 'frame', 'Foglie', 150, '🍃'),
  ShopItem('frame.gold', 'frame', 'Oro', 300, '🥇', minLevel: 5),
  ShopItem('frame.neon', 'frame', 'Neon', 350, '💡', minLevel: 8),
  ShopItem('frame.rainbow', 'frame', 'Arcobaleno', 450, '🌈', minLevel: 10),
  ShopItem('frame.galaxy', 'frame', 'Galassia', 700, '🌌', minLevel: 15),
  // Titoli
  ShopItem('title.secchione', 'title', 'Il Secchione', 100, '🤓'),
  ShopItem('title.puntuale', 'title', 'Spaccasecondo', 100, '⏰'),
  ShopItem('title.nottambulo', 'title', 'Nottambulo', 120, '🦉'),
  ShopItem('title.campanella', 'title', 'Signore della campanella', 150, '🔔'),
  ShopItem('title.ninja', 'title', 'Ninja dei compiti', 200, '🥷', minLevel: 5),
  ShopItem('title.detective', 'title', 'Detective dell\'orario', 200, '🕵️', minLevel: 5),
  ShopItem('title.prof', 'title', 'Quasi prof', 300, '👩‍🏫', minLevel: 10),
  ShopItem('title.leggenda', 'title', 'Leggenda vivente', 600, '🌟', minLevel: 20),
  // Avatar speciali
  ShopItem('avatar.drago', 'avatar', 'Drago', 80, '🐉'),
  ShopItem('avatar.leone', 'avatar', 'Leone', 80, '🦁'),
  ShopItem('avatar.lupo', 'avatar', 'Lupo', 80, '🐺'),
  ShopItem('avatar.squalo', 'avatar', 'Squalo', 80, '🦈'),
  ShopItem('avatar.robot', 'avatar', 'Robot', 120, '🤖'),
  ShopItem('avatar.alieno', 'avatar', 'Alieno', 120, '👽'),
  ShopItem('avatar.mago', 'avatar', 'Mago', 150, '🧙'),
  ShopItem('avatar.ninja', 'avatar', 'Ninja', 150, '🥷'),
  ShopItem('avatar.eroe', 'avatar', 'Supereroe', 200, '🦸', minLevel: 5),
  ShopItem('avatar.corona', 'avatar', 'Corona', 400, '👑', minLevel: 12),
  // Temi (definiti in ui/theme.dart: shopThemes, id = 'shop_<nome>')
  ShopItem('theme.ciliegio', 'theme', 'Ciliegio', 300, '🌸'),
  ShopItem('theme.caramella', 'theme', 'Caramella', 300, '🍬'),
  ShopItem('theme.abisso', 'theme', 'Abisso', 400, '🐋', minLevel: 4),
  ShopItem('theme.matrix', 'theme', 'Matrix', 450, '💚', minLevel: 6),
  ShopItem('theme.oro', 'theme', 'Nero e oro', 550, '🖤', minLevel: 10),
  ShopItem('theme.cosmo', 'theme', 'Cosmo', 800, '🪐', minLevel: 15),
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
    if (owns(s, item.id)) return 'Ce l\'hai già';
    if (level < item.minLevel) return 'Serve il livello ${item.minLevel}';
    if (balance(totalXp, s) < item.price) return 'Non hai abbastanza monete';
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

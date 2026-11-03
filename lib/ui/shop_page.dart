import 'package:flutter/material.dart';

import '../shop.dart';
import '../store.dart';
import 'achievements.dart';
import 'theme.dart';

void openShop(BuildContext context) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ShopPage()));

/// Negozio: cornici, titoli, avatar e temi da comprare con le monete (1 ogni 4 XP).
class ShopPage extends StatelessWidget {
  const ShopPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final xp = totalXp(store);
    final coins = Shop.balance(xp, store);
    return DefaultTabController(
      length: shopSlots.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Negozio'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Chip(
                avatar: const Text('🪙'),
                label: Text('$coins', style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [for (final e in shopSlots.entries) Tab(text: e.value.$1)],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Text(
                'Guadagni 1 moneta ogni $xpPerCoin XP: obiettivi, missioni e giorni con l\'app. '
                'Con l\'account le cose comprate ti seguono su ogni telefono.',
                style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  for (final slot in shopSlots.keys) _SlotGrid(slot: slot),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlotGrid extends StatelessWidget {
  const _SlotGrid({required this.slot});
  final String slot;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final items = shopItems.where((i) => i.slot == slot).toList();
    final eq = Shop.equipped(store, slot);
    return GridView(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.78,
      ),
      children: [
        if (slot != 'theme' && slot != 'avatar')
          _Tile(
            preview: slot == 'frame' ? LevelBadge(level: levelOf(store).level, size: 64) : const Text('—', style: TextStyle(fontSize: 34)),
            name: 'Nessuno',
            footer: eq == null ? 'In uso' : 'Togli',
            selected: eq == null,
            onTap: () => Shop.unequip(store, slot),
          ),
        for (final i in items) _ItemTile(item: i, equipped: eq == i.id),
      ],
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.item, required this.equipped});
  final ShopItem item;
  final bool equipped;

  Widget _preview(BuildContext context, AppStore store) {
    switch (item.slot) {
      case 'frame':
        return LevelBadge(level: levelOf(store).level, size: 64, frame: item.id);
      case 'theme':
        final t = themeById(shopThemeId(item.id));
        final colors = [t.background ?? t.seed, t.seed, ...t.backdropColors.take(2)];
        return Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          alignment: Alignment.center,
          child: Text(item.preview, style: const TextStyle(fontSize: 28)),
        );
      default:
        return Text(item.preview, style: const TextStyle(fontSize: 44));
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final lv = levelOf(store);
    final owned = Shop.owns(store, item.id);
    final locked = lv.level < item.minLevel;
    return _Tile(
      preview: Opacity(opacity: locked && !owned ? 0.45 : 1, child: _preview(context, store)),
      name: item.name,
      footer: equipped
          ? 'In uso'
          : owned
              ? 'Usa'
              : locked
                  ? '🔒 Livello ${item.minLevel}'
                  : '🪙 ${item.price}',
      selected: equipped,
      onTap: () => _tap(context, store, owned, locked),
    );
  }

  Future<void> _tap(BuildContext context, AppStore store, bool owned, bool locked) async {
    final messenger = ScaffoldMessenger.of(context);
    if (owned) {
      if (equipped && item.slot != 'theme') {
        await Shop.unequip(store, item.slot);
      } else {
        await Shop.equip(store, item);
        messenger.showSnackBar(SnackBar(content: Text('${item.name}: in uso')));
      }
      return;
    }
    if (locked) {
      messenger.showSnackBar(SnackBar(content: Text('Si sblocca al livello ${item.minLevel}')));
      return;
    }
    final xp = totalXp(store);
    final coins = Shop.balance(xp, store);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        icon: Text(item.preview, style: const TextStyle(fontSize: 40)),
        title: Text(item.name),
        content: Text(coins >= item.price
            ? 'Costa ${item.price} monete. Te ne restano ${coins - item.price}.'
            : 'Costa ${item.price} monete, ne hai $coins. Te ne servono altre ${item.price - coins} '
                '(circa ${(item.price - coins) * xpPerCoin} XP).'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annulla')),
          if (coins >= item.price) FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Compra')),
        ],
      ),
    );
    if (ok != true) return;
    final err = await Shop.buy(store, item, totalXp: xp, level: levelOf(store).level);
    if (err != null) {
      messenger.showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    await Shop.equip(store, item);
    messenger.showSnackBar(SnackBar(content: Text('Comprato! ${item.name} è in uso')));
    if (context.mounted) await checkAchievements(context);
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.preview, required this.name, required this.footer, required this.selected, required this.onTap});
  final Widget preview;
  final String name;
  final String footer;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: selected ? scheme.primary : Colors.transparent, width: 2.5),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              Expanded(child: Center(child: preview)),
              Text(name, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(footer, style: TextStyle(fontSize: 12.5, color: selected ? scheme.primary : scheme.onSurfaceVariant, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../store.dart';
import 'backdrop.dart';
import 'theme.dart';
import 'widgets.dart';

void openThemesPage(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ThemesPage()));

/// Scelta del tema con anteprime dal vivo.
class ThemesPage extends StatelessWidget {
  const ThemesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final platform = MediaQuery.platformBrightnessOf(context);
    final categories = <String, List<AppThemeSpec>>{};
    for (final t in appThemes) {
      (categories[t.category] ??= []).add(t);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Temi')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: CustomScrollView(
            slivers: [
              // Il tuo tema: creato dall'utente scegliendo colore e modalità.
              const SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(child: SectionLabel('Il tuo tema')),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 170,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.72,
                  ),
                  delegate: SliverChildListDelegate([
                    _NewThemeCard(onTap: () => editCustomTheme(context)),
                    if (store.customThemeSpec case final spec?)
                      _ThemeCard(
                        spec: spec,
                        brightness: spec.brightness ?? platform,
                        selected: store.themeId == customThemeId,
                        onTap: () => store.setThemeId(customThemeId),
                        onLongPress: () => editCustomTheme(context),
                      ),
                  ]),
                ),
              ),
              for (final e in categories.entries) ...[
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverToBoxAdapter(child: SectionLabel(e.key)),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 170,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.72,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        final spec = e.value[i];
                        return _ThemeCard(
                          spec: spec,
                          brightness: spec.brightness ?? platform,
                          selected: store.themeId == spec.id,
                          onTap: () => store.setThemeId(spec.id),
                        );
                      },
                      childCount: e.value.length,
                    ),
                  ),
                ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.spec,
    required this.brightness,
    required this.selected,
    required this.onTap,
    this.onLongPress,
  });

  final AppThemeSpec spec;
  final Brightness brightness;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  static final Map<String, ThemeData> _cache = {};

  @override
  Widget build(BuildContext context) {
    final outer = Theme.of(context).colorScheme;
    final data = _cache.putIfAbsent(
        '${spec.id}-${spec.seed.value}-${spec.pureBlack}-${brightness.name}', () => buildTheme(brightness, spec));
    final scheme = data.colorScheme;
    final p = data.extension<AppPalette>()!;

    final preview = Theme(
      data: data,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (spec.animated)
              AnimatedBackdrop(kind: spec.backdrop, base: p.background, colors: spec.backdropColors)
            else
              ColoredBox(color: p.background),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 8,
                    width: 56,
                    decoration: BoxDecoration(color: scheme.onSurface, borderRadius: BorderRadius.circular(4)),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 30,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [scheme.primary, Color.lerp(scheme.primary, scheme.tertiary, 0.55)!],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final c in [scheme.primaryContainer, scheme.tertiaryContainer, scheme.secondaryContainer])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Container(
                        height: 16,
                        decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                  const Spacer(),
                  Container(
                    height: 18,
                    decoration: BoxDecoration(color: p.nav, borderRadius: BorderRadius.circular(9)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        for (var i = 0; i < 3; i++)
                          Container(
                            width: 16,
                            height: 6,
                            decoration: BoxDecoration(
                              color: i == 0 ? scheme.primary : scheme.onSurfaceVariant.withAlpha(90),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return Semantics(
      button: true,
      selected: selected,
      label: 'Tema ${spec.name}',
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? outer.primary : outer.outlineVariant.withAlpha(120),
              width: selected ? 3 : 1,
            ),
          ),
          child: Column(
            children: [
              Expanded(child: preview),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
                child: Row(
                  children: [
                    if (selected) ...[
                      Icon(Icons.check_circle_rounded, size: 16, color: outer.primary),
                      const SizedBox(width: 4),
                    ],
                    Expanded(
                      child: Text(
                        spec.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: selected ? FontWeight.w700 : FontWeight.w500),
                      ),
                    ),
                    if (spec.animated) Icon(Icons.motion_photos_on_outlined, size: 14, color: outer.onSurfaceVariant),
                    if (spec.pureBlack) Icon(Icons.brightness_1, size: 12, color: outer.onSurfaceVariant),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card per creare (o modificare) il tema personalizzato.
class _NewThemeCard extends StatelessWidget {
  const _NewThemeCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: scheme.outlineVariant.withAlpha(120)),
        ),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: ColoredBox(
                  color: scheme.surfaceContainerHighest.withAlpha(90),
                  child: Center(
                    child: Icon(Icons.add_rounded, size: 44, color: scheme.primary),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
              child: Text(
                'Crea il tuo tema',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w500, color: scheme.onSurface),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Colori proposti nel dialogo: in testa la palette lavanda delle foto,
/// poi una scelta di tinte per coprire tutta la ruota dei colori.
const _customSeedColors = <int>[
  0xFF985DE4, 0xFFAE80EA, 0xFFC4A4F1, 0xFFBA93EC, 0xFF794AB6, 0xFF5B3788, // lavanda
  0xFFDC5DE4, 0xFF5D65E4, 0xFFA9E45D, // armonia (analogo + complementare)
  0xFF16A34A, 0xFF2979FF, 0xFF00E676, 0xFFEC407A, 0xFFFF7043, 0xFFFFD600,
  0xFF00BFA5, 0xFF00838F, 0xFF8D6E63, 0xFFD81B60, 0xFF0288D1, 0xFF26A69A,
  0xFFFF5722, 0xFF7B1FA2, 0xFF3949AB, 0xFF607D8B,
];

/// Apre il dialogo per creare/modificare il tema personalizzato.
Future<void> editCustomTheme(BuildContext context) async {
  final store = StoreScope.read(context);
  final nameCtrl = TextEditingController(text: store.customName);
  var seed = store.customSeed;
  var mode = store.customMode;
  var oled = store.customOled;

  final saved = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) {
        final scheme = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          title: const Text('Il tuo tema'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtrl,
                    maxLength: 24,
                    decoration: const InputDecoration(
                      labelText: 'Nome del tema',
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('Colore', style: TextStyle(fontWeight: FontWeight.w600, color: scheme.onSurface)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final c in _customSeedColors)
                        InkWell(
                          onTap: () => setState(() => seed = c),
                          customBorder: const CircleBorder(),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Color(c),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: seed == c ? scheme.onSurface : Colors.transparent,
                                width: 3,
                              ),
                            ),
                            child: seed == c
                                ? Icon(
                                    Icons.check_rounded,
                                    size: 20,
                                    color: ThemeData.estimateBrightnessForColor(Color(c)) == Brightness.dark
                                        ? Colors.white
                                        : Colors.black,
                                  )
                                : null,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Modalità', style: TextStyle(fontWeight: FontWeight.w600, color: scheme.onSurface)),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'system', label: Text('Automatico')),
                      ButtonSegment(value: 'light', label: Text('Chiaro')),
                      ButtonSegment(value: 'dark', label: Text('Scuro')),
                    ],
                    selected: {mode},
                    onSelectionChanged: (s) => setState(() => mode = s.first),
                  ),
                  if (mode != 'light')
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Nero assoluto (OLED)'),
                      subtitle: const Text('Sfondo nero puro: i pixel restano spenti'),
                      value: oled,
                      onChanged: (v) => setState(() => oled = v),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Salva'),
            ),
          ],
        );
      },
    ),
  );

  if (saved == true) {
    await store.setCustomTheme(name: nameCtrl.text, seed: seed, mode: mode, oled: oled);
  }
  nameCtrl.dispose();
}

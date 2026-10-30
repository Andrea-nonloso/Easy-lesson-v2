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
  });

  final AppThemeSpec spec;
  final Brightness brightness;
  final bool selected;
  final VoidCallback onTap;

  static final Map<String, ThemeData> _cache = {};

  @override
  Widget build(BuildContext context) {
    final outer = Theme.of(context).colorScheme;
    final data = _cache.putIfAbsent('${spec.id}-${brightness.name}', () => buildTheme(brightness, spec));
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

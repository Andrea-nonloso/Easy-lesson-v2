import 'package:flutter/material.dart';

const brandSeed = Color(0xFF16A34A);

/// Icona "schiocco di dita" del font originale di Easy Lesson.
const easyIcon = IconData(0xE802, fontFamily: 'EasyIcons');

/// Tipi di sfondo animato (vedi backdrop.dart).
enum BackdropKind { none, blobs, gradient, pulse, stars, waves }

/// Definizione di un tema. I colori null vengono ricavati dal colore base.
class AppThemeSpec {
  const AppThemeSpec({
    required this.id,
    required this.name,
    required this.seed,
    this.brightness,
    this.background,
    this.card,
    this.nav,
    this.backdrop = BackdropKind.none,
    this.backdropColors = const [],
    this.pureBlack = false,
    this.category = 'Classici',
  });

  final String id;
  final String name;
  final Color seed;

  /// null = segue il tema chiaro/scuro del sistema.
  final Brightness? brightness;
  final Color? background;
  final Color? card;
  final Color? nav;
  final BackdropKind backdrop;
  final List<Color> backdropColors;

  /// Nero puro (#000000) per schermi OLED / AMOLED: i pixel neri sono spenti.
  final bool pureBlack;
  final String category;

  bool get animated => backdrop != BackdropKind.none;
}

/// Colori extra usati dall'app oltre al ColorScheme.
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.background,
    required this.card,
    required this.nav,
    required this.backdrop,
    required this.backdropColors,
  });

  final Color background;
  final Color card;
  final Color nav;
  final BackdropKind backdrop;
  final List<Color> backdropColors;

  @override
  AppPalette copyWith({Color? background, Color? card, Color? nav}) => AppPalette(
        background: background ?? this.background,
        card: card ?? this.card,
        nav: nav ?? this.nav,
        backdrop: backdrop,
        backdropColors: backdropColors,
      );

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      background: Color.lerp(background, other.background, t)!,
      card: Color.lerp(card, other.card, t)!,
      nav: Color.lerp(nav, other.nav, t)!,
      backdrop: t < 0.5 ? backdrop : other.backdrop,
      backdropColors: t < 0.5 ? backdropColors : other.backdropColors,
    );
  }
}

// ---------------------------------------------------------------------------
// Catalogo dei temi

const appThemes = <AppThemeSpec>[
  // Classici
  AppThemeSpec(id: 'auto', name: 'Automatico', seed: brandSeed, category: 'Classici'),
  AppThemeSpec(id: 'light', name: 'Chiaro', seed: brandSeed, brightness: Brightness.light, category: 'Classici'),
  AppThemeSpec(id: 'dark', name: 'Scuro', seed: brandSeed, brightness: Brightness.dark, category: 'Classici'),
  AppThemeSpec(
    id: 'paper', name: 'Carta', seed: Color(0xFF8D6E63), brightness: Brightness.light,
    background: Color(0xFFF5EFE3), card: Color(0xFFFFFBF2), nav: Color(0xFFFFFBF2), category: 'Classici',
  ),
  AppThemeSpec(
    id: 'contrast', name: 'Alto contrasto', seed: Color(0xFFFFD600), brightness: Brightness.dark,
    background: Color(0xFF000000), card: Color(0xFF111111), nav: Color(0xFF000000), pureBlack: true,
    category: 'Classici',
  ),

  // Neri (OLED / AMOLED)
  AppThemeSpec(
    id: 'pureblack', name: 'Pure Black', seed: Color(0xFF9E9E9E), brightness: Brightness.dark,
    background: Color(0xFF000000), card: Color(0xFF0E0E0E), nav: Color(0xFF000000), pureBlack: true,
    category: 'Neri (OLED)',
  ),
  AppThemeSpec(
    id: 'oled', name: 'OLED Blu', seed: Color(0xFF2979FF), brightness: Brightness.dark,
    background: Color(0xFF000000), card: Color(0xFF0B0F17), nav: Color(0xFF000000), pureBlack: true,
    category: 'Neri (OLED)',
  ),
  AppThemeSpec(
    id: 'amoled', name: 'AMOLED Verde', seed: Color(0xFF00E676), brightness: Brightness.dark,
    background: Color(0xFF000000), card: Color(0xFF07120B), nav: Color(0xFF000000), pureBlack: true,
    category: 'Neri (OLED)',
  ),
  AppThemeSpec(
    id: 'neon', name: 'AMOLED Neon', seed: Color(0xFFFF2BD6), brightness: Brightness.dark,
    background: Color(0xFF000000), card: Color(0xFF120713), nav: Color(0xFF000000), pureBlack: true,
    category: 'Neri (OLED)',
  ),

  // Natura
  AppThemeSpec(
    id: 'desert', name: 'Deserto', seed: Color(0xFFC2703D), brightness: Brightness.light,
    background: Color(0xFFF3E3C7), card: Color(0xFFFBF1DE), nav: Color(0xFFFBF1DE), category: 'Natura',
  ),
  AppThemeSpec(
    id: 'ocean', name: 'Oceano', seed: Color(0xFF0277BD), brightness: Brightness.light,
    background: Color(0xFFE3F2FB), card: Color(0xFFF7FBFE), nav: Color(0xFFF7FBFE), category: 'Natura',
  ),
  AppThemeSpec(
    id: 'forest', name: 'Foresta', seed: Color(0xFF2E7D32), brightness: Brightness.dark,
    background: Color(0xFF0E1A10), card: Color(0xFF15261A), nav: Color(0xFF0B150D), category: 'Natura',
  ),
  AppThemeSpec(
    id: 'sakura', name: 'Sakura', seed: Color(0xFFD81B60), brightness: Brightness.light,
    background: Color(0xFFFCE8EF), card: Color(0xFFFFF6F9), nav: Color(0xFFFFF6F9), category: 'Natura',
  ),
  AppThemeSpec(
    id: 'arctic', name: 'Artico', seed: Color(0xFF00838F), brightness: Brightness.light,
    background: Color(0xFFE6F6F7), card: Color(0xFFFFFFFF), nav: Color(0xFFFFFFFF), category: 'Natura',
  ),
  AppThemeSpec(
    id: 'coffee', name: 'Caffè', seed: Color(0xFF8D5B3A), brightness: Brightness.dark,
    background: Color(0xFF1B1411), card: Color(0xFF261C17), nav: Color(0xFF16100D), category: 'Natura',
  ),

  // Animati
  AppThemeSpec(
    id: 'sunset', name: 'Tramonto', seed: Color(0xFFFF7043), brightness: Brightness.dark,
    background: Color(0xFF1E1028), card: Color(0xE62A1734), nav: Color(0xCC1E1028),
    backdrop: BackdropKind.gradient,
    backdropColors: [Color(0xFF2B1055), Color(0xFF7B2869), Color(0xFFD9534F), Color(0xFFF2A65A)],
    category: 'Animati',
  ),
  AppThemeSpec(
    id: 'aurora', name: 'Aurora', seed: Color(0xFF1DE9B6), brightness: Brightness.dark,
    background: Color(0xFF050B14), card: Color(0xE00C1724), nav: Color(0xCC050B14),
    backdrop: BackdropKind.blobs,
    backdropColors: [Color(0xFF00BFA5), Color(0xFF6A1B9A), Color(0xFF00E5FF), Color(0xFF2E7D32)],
    category: 'Animati',
  ),
  AppThemeSpec(
    id: 'lava', name: 'Lava', seed: Color(0xFFFF5722), brightness: Brightness.dark,
    background: Color(0xFF120605), card: Color(0xE01E0D0A), nav: Color(0xCC120605),
    backdrop: BackdropKind.blobs,
    backdropColors: [Color(0xFFD84315), Color(0xFFB71C1C), Color(0xFFFF8F00)],
    category: 'Animati',
  ),
  AppThemeSpec(
    id: 'night', name: 'Notte stellata', seed: Color(0xFF7986CB), brightness: Brightness.dark,
    background: Color(0xFF060A1E), card: Color(0xE00D1330), nav: Color(0xCC060A1E),
    backdrop: BackdropKind.stars,
    backdropColors: [Color(0xFF283593), Color(0xFF4A148C)],
    category: 'Animati',
  ),
  AppThemeSpec(
    id: 'waves', name: 'Onde', seed: Color(0xFF0288D1), brightness: Brightness.light,
    background: Color(0xFFE1F3FC), card: Color(0xF0FFFFFF), nav: Color(0xE6FFFFFF),
    backdrop: BackdropKind.waves,
    backdropColors: [Color(0xFF4FC3F7), Color(0xFF29B6F6), Color(0xFF0288D1)],
    category: 'Animati',
  ),
  AppThemeSpec(
    id: 'candy', name: 'Caramella', seed: Color(0xFFEC407A), brightness: Brightness.light,
    background: Color(0xFFFFF0F6), card: Color(0xF0FFFFFF), nav: Color(0xE6FFFFFF),
    backdrop: BackdropKind.gradient,
    backdropColors: [Color(0xFFFFD1DC), Color(0xFFD7C4F2), Color(0xFFC4E7F2), Color(0xFFD9F2C4)],
    category: 'Animati',
  ),
  AppThemeSpec(
    id: 'mood', name: 'Tinta viva', seed: Color(0xFF5C6BC0), brightness: Brightness.dark,
    background: Color(0xFF14152B), card: Color(0xE0101124), nav: Color(0xCC14152B),
    backdrop: BackdropKind.pulse,
    backdropColors: [Color(0xFF1A237E), Color(0xFF4A148C), Color(0xFF004D40), Color(0xFF01579B)],
    category: 'Animati',
  ),
  AppThemeSpec(
    id: 'mint', name: 'Menta in movimento', seed: Color(0xFF26A69A), brightness: Brightness.light,
    background: Color(0xFFE0F5F1), card: Color(0xF0FFFFFF), nav: Color(0xE6FFFFFF),
    backdrop: BackdropKind.pulse,
    backdropColors: [Color(0xFFD7F5EC), Color(0xFFDDEFFA), Color(0xFFF3F7D4)],
    category: 'Animati',
  ),
];

AppThemeSpec themeById(String? id) =>
    appThemes.firstWhere((t) => t.id == id, orElse: () => appThemes.first);

// ---------------------------------------------------------------------------
// Costruzione del ThemeData

ThemeData buildTheme(Brightness brightness, [AppThemeSpec spec = const AppThemeSpec(id: 'auto', name: 'Automatico', seed: brandSeed)]) {
  final dark = brightness == Brightness.dark;
  var scheme = ColorScheme.fromSeed(seedColor: spec.seed, brightness: brightness);
  final bg = spec.background ?? (dark ? const Color(0xFF0F1411) : const Color(0xFFF4F7F4));
  final card = spec.card ?? (dark ? const Color(0xFF18201B) : Colors.white);
  final nav = spec.nav ?? (dark ? const Color(0xFF161C18) : Colors.white);
  if (spec.pureBlack) {
    scheme = scheme.copyWith(
      surface: Colors.black,
      surfaceContainerLowest: Colors.black,
      surfaceContainerLow: const Color(0xFF0A0A0A),
      surfaceContainer: const Color(0xFF111111),
      surfaceContainerHigh: const Color(0xFF181818),
      surfaceContainerHighest: const Color(0xFF202020),
    );
  }
  if (spec.id == 'contrast') {
    scheme = scheme.copyWith(
      primary: const Color(0xFFFFD600),
      onPrimary: Colors.black,
      primaryContainer: const Color(0xFFFFD600),
      onPrimaryContainer: Colors.black,
      onSurface: Colors.white,
      onSurfaceVariant: const Color(0xFFE0E0E0),
      outlineVariant: const Color(0xFF9E9E9E),
    );
  }
  // Con sfondo animato le superfici sono trasparenti e lo sfondo sta dietro a tutto.
  final scaffoldBg = spec.animated ? Colors.transparent : bg;

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: brightness,
    fontFamily: 'Hind',
    scaffoldBackgroundColor: scaffoldBg,
    canvasColor: spec.animated ? card : null,
    visualDensity: VisualDensity.standard,
    extensions: [
      AppPalette(
        background: bg,
        card: card,
        nav: nav,
        backdrop: spec.backdrop,
        backdropColors: spec.backdropColors,
      ),
    ],
  );
  final text = base.textTheme;
  return base.copyWith(
    appBarTheme: AppBarTheme(
      backgroundColor: scaffoldBg,
      foregroundColor: scheme.onSurface,
      iconTheme: IconThemeData(color: scheme.onSurface),
      actionsIconTheme: IconThemeData(color: scheme.onSurface),
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: nav,
      surfaceTintColor: Colors.transparent,
      indicatorColor: scheme.primaryContainer,
      elevation: 0,
      height: 68,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: nav,
      indicatorColor: scheme.primaryContainer,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: spec.pureBlack ? const Color(0xFF0E0E0E) : null,
      surfaceTintColor: Colors.transparent,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide(color: scheme.outlineVariant.withAlpha(120)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

AppPalette palette(BuildContext context) =>
    Theme.of(context).extension<AppPalette>() ??
    AppPalette(
      background: Theme.of(context).scaffoldBackgroundColor,
      card: Theme.of(context).colorScheme.surface,
      nav: Theme.of(context).colorScheme.surface,
      backdrop: BackdropKind.none,
      backdropColors: const [],
    );

/// Superficie "card" del tema corrente.
Color cardColor(BuildContext context) => palette(context).card;

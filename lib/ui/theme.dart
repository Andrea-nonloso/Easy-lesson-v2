import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../i18n.dart';

/// Accento predefinito dell'app: azzurro elettrico (stile "blu notte").
const brandSeed = Color(0xFF3B82F6);

/// Icona "schiocco di dita" del font originale di Easy Lesson.
const easyIcon = IconData(0xE802, fontFamily: 'EasyIcons');

/// Tipi di sfondo animato (vedi backdrop.dart).
enum BackdropKind { none, blobs, gradient, pulse, stars, waves }

/// Definizione di un tema. I colori null vengono ricavati dal colore base.
class AppThemeSpec {
  const AppThemeSpec({
    required this.id,
    required String name,
    required this.seed,
    this.brightness,
    this.background,
    this.card,
    this.nav,
    this.backdrop = BackdropKind.none,
    this.backdropColors = const [],
    this.pureBlack = false,
    String category = 'Classici',
  })  : nameIt = name,
        categoryIt = category;

  final String id;

  /// Nome e gruppo in italiano (come scritti qui sotto); [name] e [category] seguono la lingua dell'app.
  final String nameIt;
  final String categoryIt;
  String get name => appEnglish ? (_themeNamesEn[id] ?? nameIt) : nameIt;
  String get category => appEnglish ? (_themeCategoriesEn[categoryIt] ?? categoryIt) : categoryIt;
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

final appThemes = <AppThemeSpec>[
  // Classici
  const AppThemeSpec(id: 'auto', name: 'Automatico', seed: brandSeed, category: 'Classici'),
  const AppThemeSpec(id: 'light', name: 'Chiaro', seed: brandSeed, brightness: Brightness.light, category: 'Classici'),
  const AppThemeSpec(id: 'dark', name: 'Scuro', seed: brandSeed, brightness: Brightness.dark, category: 'Classici'),
  const AppThemeSpec(
    id: 'blunotte', name: 'Blu notte', seed: Color(0xFF3B82F6), brightness: Brightness.dark,
    background: Color(0xFF0C1626), card: Color(0xFF16233A), nav: Color(0xFF101C30), category: 'Classici',
  ),
  const AppThemeSpec(
    id: 'paper', name: 'Carta', seed: Color(0xFF8D6E63), brightness: Brightness.light,
    background: Color(0xFFF5EFE3), card: Color(0xFFFFFBF2), nav: Color(0xFFFFFBF2), category: 'Classici',
  ),
  const AppThemeSpec(
    id: 'contrast', name: 'Alto contrasto', seed: Color(0xFFFFD600), brightness: Brightness.dark,
    background: Color(0xFF000000), card: Color(0xFF111111), nav: Color(0xFF000000), pureBlack: true,
    category: 'Classici',
  ),

  // Neri (OLED / AMOLED)
  const AppThemeSpec(
    id: 'pureblack', name: 'Pure Black', seed: Color(0xFF9E9E9E), brightness: Brightness.dark,
    background: Color(0xFF000000), card: Color(0xFF0E0E0E), nav: Color(0xFF000000), pureBlack: true,
    category: 'Neri (OLED)',
  ),
  const AppThemeSpec(
    id: 'oled', name: 'OLED Blu', seed: Color(0xFF2979FF), brightness: Brightness.dark,
    background: Color(0xFF000000), card: Color(0xFF0B0F17), nav: Color(0xFF000000), pureBlack: true,
    category: 'Neri (OLED)',
  ),
  const AppThemeSpec(
    id: 'amoled', name: 'AMOLED Verde', seed: Color(0xFF00E676), brightness: Brightness.dark,
    background: Color(0xFF000000), card: Color(0xFF07120B), nav: Color(0xFF000000), pureBlack: true,
    category: 'Neri (OLED)',
  ),
  const AppThemeSpec(
    id: 'neon', name: 'AMOLED Neon', seed: Color(0xFFFF2BD6), brightness: Brightness.dark,
    background: Color(0xFF000000), card: Color(0xFF120713), nav: Color(0xFF000000), pureBlack: true,
    category: 'Neri (OLED)',
  ),

  // Natura
  const AppThemeSpec(
    id: 'desert', name: 'Deserto', seed: Color(0xFFC2703D), brightness: Brightness.light,
    background: Color(0xFFF3E3C7), card: Color(0xFFFBF1DE), nav: Color(0xFFFBF1DE), category: 'Natura',
  ),
  const AppThemeSpec(
    id: 'ocean', name: 'Oceano', seed: Color(0xFF0277BD), brightness: Brightness.light,
    background: Color(0xFFE3F2FB), card: Color(0xFFF7FBFE), nav: Color(0xFFF7FBFE), category: 'Natura',
  ),
  const AppThemeSpec(
    id: 'forest', name: 'Foresta', seed: Color(0xFF2E7D32), brightness: Brightness.dark,
    background: Color(0xFF0E1A10), card: Color(0xFF15261A), nav: Color(0xFF0B150D), category: 'Natura',
  ),
  const AppThemeSpec(
    id: 'sakura', name: 'Sakura', seed: Color(0xFFD81B60), brightness: Brightness.light,
    background: Color(0xFFFCE8EF), card: Color(0xFFFFF6F9), nav: Color(0xFFFFF6F9), category: 'Natura',
  ),
  const AppThemeSpec(
    id: 'arctic', name: 'Artico', seed: Color(0xFF00838F), brightness: Brightness.light,
    background: Color(0xFFE6F6F7), card: Color(0xFFFFFFFF), nav: Color(0xFFFFFFFF), category: 'Natura',
  ),
  const AppThemeSpec(
    id: 'coffee', name: 'Caffè', seed: Color(0xFF8D5B3A), brightness: Brightness.dark,
    background: Color(0xFF1B1411), card: Color(0xFF261C17), nav: Color(0xFF16100D), category: 'Natura',
  ),

  // Animati
  const AppThemeSpec(
    id: 'sunset', name: 'Tramonto', seed: Color(0xFFFF7043), brightness: Brightness.dark,
    background: Color(0xFF1E1028), card: Color(0xE62A1734), nav: Color(0xCC1E1028),
    backdrop: BackdropKind.gradient,
    backdropColors: [Color(0xFF2B1055), Color(0xFF7B2869), Color(0xFFD9534F), Color(0xFFF2A65A)],
    category: 'Animati',
  ),
  const AppThemeSpec(
    id: 'aurora', name: 'Aurora', seed: Color(0xFF1DE9B6), brightness: Brightness.dark,
    background: Color(0xFF050B14), card: Color(0xE00C1724), nav: Color(0xCC050B14),
    backdrop: BackdropKind.blobs,
    backdropColors: [Color(0xFF00BFA5), Color(0xFF6A1B9A), Color(0xFF00E5FF), Color(0xFF2E7D32)],
    category: 'Animati',
  ),
  const AppThemeSpec(
    id: 'lava', name: 'Lava', seed: Color(0xFFFF5722), brightness: Brightness.dark,
    background: Color(0xFF120605), card: Color(0xE01E0D0A), nav: Color(0xCC120605),
    backdrop: BackdropKind.blobs,
    backdropColors: [Color(0xFFD84315), Color(0xFFB71C1C), Color(0xFFFF8F00)],
    category: 'Animati',
  ),
  const AppThemeSpec(
    id: 'night', name: 'Notte stellata', seed: Color(0xFF7986CB), brightness: Brightness.dark,
    background: Color(0xFF060A1E), card: Color(0xE00D1330), nav: Color(0xCC060A1E),
    backdrop: BackdropKind.stars,
    backdropColors: [Color(0xFF283593), Color(0xFF4A148C)],
    category: 'Animati',
  ),
  const AppThemeSpec(
    id: 'waves', name: 'Onde', seed: Color(0xFF0288D1), brightness: Brightness.light,
    background: Color(0xFFE1F3FC), card: Color(0xF0FFFFFF), nav: Color(0xE6FFFFFF),
    backdrop: BackdropKind.waves,
    backdropColors: [Color(0xFF4FC3F7), Color(0xFF29B6F6), Color(0xFF0288D1)],
    category: 'Animati',
  ),
  const AppThemeSpec(
    id: 'candy', name: 'Caramella', seed: Color(0xFFEC407A), brightness: Brightness.light,
    background: Color(0xFFFFF0F6), card: Color(0xF0FFFFFF), nav: Color(0xE6FFFFFF),
    backdrop: BackdropKind.gradient,
    backdropColors: [Color(0xFFFFD1DC), Color(0xFFD7C4F2), Color(0xFFC4E7F2), Color(0xFFD9F2C4)],
    category: 'Animati',
  ),
  const AppThemeSpec(
    id: 'mood', name: 'Tinta viva', seed: Color(0xFF5C6BC0), brightness: Brightness.dark,
    background: Color(0xFF14152B), card: Color(0xE0101124), nav: Color(0xCC14152B),
    backdrop: BackdropKind.pulse,
    backdropColors: [Color(0xFF1A237E), Color(0xFF4A148C), Color(0xFF004D40), Color(0xFF01579B)],
    category: 'Animati',
  ),
  const AppThemeSpec(
    id: 'mint', name: 'Menta in movimento', seed: Color(0xFF26A69A), brightness: Brightness.light,
    background: Color(0xFFE0F5F1), card: Color(0xF0FFFFFF), nav: Color(0xE6FFFFFF),
    backdrop: BackdropKind.pulse,
    backdropColors: [Color(0xFFD7F5EC), Color(0xFFDDEFFA), Color(0xFFF3F7D4)],
    category: 'Animati',
  ),

  // Lavanda (palette dalle foto: base Lavender Indigo #985DE4)
  const AppThemeSpec(
    id: 'lavender', name: 'Lavanda', seed: Color(0xFF985DE4), brightness: Brightness.light,
    background: Color(0xFFF1EBFF), card: Color(0xFFFFFFFF), nav: Color(0xFFFFFFFF), category: 'Lavanda',
  ),
  const AppThemeSpec(
    id: 'lavenderSoft', name: 'Lavanda Tenue', seed: Color(0xFF9667D3), brightness: Brightness.light,
    background: Color(0xFFF6F1FF), card: Color(0xFFFCFAFF), nav: Color(0xFFFCFAFF), category: 'Lavanda',
  ),
  const AppThemeSpec(
    id: 'lavenderNight', name: 'Notte Lavanda', seed: Color(0xFFA978E8), brightness: Brightness.dark,
    background: Color(0xFF1E122D), card: Color(0xFF2C1B42), nav: Color(0xFF241638), category: 'Lavanda',
  ),
  const AppThemeSpec(
    id: 'lavenderOled', name: 'Lavanda OLED', seed: Color(0xFFAE80EA), brightness: Brightness.dark,
    background: Color(0xFF000000), card: Color(0xFF150A20), nav: Color(0xFF000000), pureBlack: true,
    category: 'Lavanda',
  ),
  const AppThemeSpec(
    id: 'lavenderHarmony', name: 'Lavanda in movimento', seed: Color(0xFF985DE4), brightness: Brightness.dark,
    background: Color(0xFF160E24), card: Color(0xE6221A38), nav: Color(0xCC160E24),
    backdrop: BackdropKind.gradient,
    backdropColors: [Color(0xFF985DE4), Color(0xFFDC5DE4), Color(0xFF5D65E4)],
    category: 'Lavanda',
  ),
];

/// Id riservato al tema creato dall'utente: i colori sono salvati a parte
/// (vedi AppStore.customThemeSpec) perché non fanno parte del catalogo.
const customThemeId = 'custom';

/// Costruisce il tema dai colori scelti dall'utente.
/// [mode]: 'system' | 'light' | 'dark'. [oled] vale solo per lo scuro.
AppThemeSpec buildCustomSpec({
  required String name,
  required Color seed,
  String mode = 'system',
  bool oled = false,
  Color? background,
  Color? card,
  Color? nav,
}) {
  final brightness = switch (mode) {
    'light' => Brightness.light,
    'dark' => Brightness.dark,
    _ => null,
  };
  final darkOled = oled && brightness != Brightness.light;
  return AppThemeSpec(
    id: customThemeId,
    name: name.trim().isEmpty ? tr('Il mio tema', 'My theme') : name.trim(),
    seed: seed,
    brightness: brightness,
    pureBlack: darkOled,
    background: background ?? (darkOled ? const Color(0xFF000000) : null),
    card: card ?? (darkOled ? const Color(0xFF0E0E0E) : null),
    nav: nav ?? (darkOled ? const Color(0xFF000000) : null),
    category: 'Il tuo tema',
  );
}

/// Temi del negozio (3.0): si usano solo dopo averli comprati (vedi lib/shop.dart).
const shopThemes = <AppThemeSpec>[
  AppThemeSpec(
    id: 'shop_ciliegio', name: 'Ciliegio', seed: Color(0xFFEC407A), brightness: Brightness.light,
    background: Color(0xFFFFF1F5), card: Color(0xFFFFFFFF), nav: Color(0xFFFFE4EC), category: 'Dal negozio',
  ),
  AppThemeSpec(
    id: 'shop_caramella', name: 'Caramella', seed: Color(0xFF7E57C2), brightness: Brightness.light,
    background: Color(0xFFF3F0FF), card: Color(0xFFFFFFFF), nav: Color(0xFFE9F7FF),
    backdrop: BackdropKind.blobs,
    backdropColors: [Color(0xFFFFC1E3), Color(0xFFB3E5FC), Color(0xFFFFF59D)],
    category: 'Dal negozio',
  ),
  AppThemeSpec(
    id: 'shop_abisso', name: 'Abisso', seed: Color(0xFF26C6DA), brightness: Brightness.dark,
    background: Color(0xFF02101A), card: Color(0xE0062033), nav: Color(0xCC02101A),
    backdrop: BackdropKind.waves,
    backdropColors: [Color(0xFF01579B), Color(0xFF006064), Color(0xFF0D47A1)],
    category: 'Dal negozio',
  ),
  AppThemeSpec(
    id: 'shop_matrix', name: 'Matrix', seed: Color(0xFF00E676), brightness: Brightness.dark,
    background: Color(0xFF000000), card: Color(0xE0061208), nav: Color(0xCC000000),
    backdrop: BackdropKind.stars,
    backdropColors: [Color(0xFF00E676), Color(0xFF1B5E20)],
    pureBlack: true,
    category: 'Dal negozio',
  ),
  AppThemeSpec(
    id: 'shop_oro', name: 'Nero e oro', seed: Color(0xFFFFC107), brightness: Brightness.dark,
    background: Color(0xFF0A0A0A), card: Color(0xFF17140C), nav: Color(0xFF0A0A0A), pureBlack: true, category: 'Dal negozio',
  ),
  AppThemeSpec(
    id: 'shop_cosmo', name: 'Cosmo', seed: Color(0xFFB388FF), brightness: Brightness.dark,
    background: Color(0xFF07041A), card: Color(0xE0140E2E), nav: Color(0xCC07041A),
    backdrop: BackdropKind.stars,
    backdropColors: [Color(0xFF7C4DFF), Color(0xFF448AFF), Color(0xFFFF4081)],
    category: 'Dal negozio',
  ),
];

AppThemeSpec themeById(String? id, {AppThemeSpec? custom}) {
  if (id == customThemeId && custom != null) return custom;
  for (final t in shopThemes) {
    if (t.id == id) return t;
  }
  return appThemes.firstWhere((t) => t.id == id, orElse: () => appThemes.first);
}

// ---------------------------------------------------------------------------
// Costruzione del ThemeData

ThemeData buildTheme(Brightness brightness, [AppThemeSpec spec = const AppThemeSpec(id: 'auto', name: 'Automatico', seed: brandSeed)]) {
  final dark = brightness == Brightness.dark;
  var scheme = ColorScheme.fromSeed(seedColor: spec.seed, brightness: brightness);
  // Predefiniti: scuro neutro su scala di grigi; chiaro morbido grigio-lilla.
  final bg = spec.background ?? (dark ? const Color(0xFF131313) : const Color(0xFFF4F3F7));
  final card = spec.card ?? (dark ? const Color(0xFF1F1F1F) : Colors.white);
  final nav = spec.nav ?? (dark ? const Color(0xFF181818) : Colors.white);
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

/// 3.0 — stile "Material 3 Expressive": forme più tonde e varie, pulsanti più grandi e decisi,
/// titoli più pesanti, barra di navigazione con indicatore a pillola, transizioni con il "torna
/// indietro predittivo" di Android. Solo API stabili di Flutter: si spegne dalle impostazioni.
ThemeData expressiveTheme(ThemeData t) {
  final scheme = t.colorScheme;
  final text = t.textTheme;
  const pill = StadiumBorder();
  RoundedRectangleBorder round(double r) => RoundedRectangleBorder(borderRadius: BorderRadius.circular(r));
  const big = Size(64, 52);
  const label = TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5, letterSpacing: 0.1);
  return t.copyWith(
    textTheme: text.copyWith(
      displaySmall: text.displaySmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
      headlineLarge: text.headlineLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
      headlineMedium: text.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.3),
      headlineSmall: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: round(26),
      surfaceTintColor: Colors.transparent,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(shape: pill, minimumSize: big, textStyle: label, padding: const EdgeInsets.symmetric(horizontal: 24)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(shape: pill, minimumSize: big, textStyle: label),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(shape: pill, minimumSize: big, textStyle: label, side: BorderSide(color: scheme.outline, width: 1.5)),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(shape: pill, textStyle: label)),
    iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(shape: round(16))),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      shape: round(22),
      elevation: 2,
      extendedTextStyle: label,
      extendedSizeConstraints: const BoxConstraints.tightFor(height: 60),
      sizeConstraints: const BoxConstraints.tightFor(width: 64, height: 64),
    ),
    navigationBarTheme: t.navigationBarTheme.copyWith(
      height: 76,
      indicatorShape: pill,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontSize: 12.5,
          fontWeight: s.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w500,
          color: s.contains(WidgetState.selected) ? scheme.onSurface : scheme.onSurfaceVariant,
        ),
      ),
    ),
    navigationRailTheme: t.navigationRailTheme.copyWith(indicatorShape: pill),
    dialogTheme: DialogThemeData(shape: round(32)),
    bottomSheetTheme: t.bottomSheetTheme.copyWith(
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      showDragHandle: true,
    ),
    chipTheme: t.chipTheme.copyWith(shape: pill),
    listTileTheme: ListTileThemeData(shape: round(18)),
    segmentedButtonTheme: SegmentedButtonThemeData(style: SegmentedButton.styleFrom(shape: pill)),
    snackBarTheme: t.snackBarTheme.copyWith(shape: round(18)),
    tooltipTheme: TooltipThemeData(decoration: BoxDecoration(color: scheme.inverseSurface, borderRadius: BorderRadius.circular(12))),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        TargetPlatform.windows: ZoomPageTransitionsBuilder(),
        TargetPlatform.linux: ZoomPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      },
    ),
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

// 3.8: nomi dei temi e dei gruppi in inglese.
const _themeNamesEn = {
  'auto': 'Automatic', 'light': 'Light', 'dark': 'Dark', 'blunotte': 'Midnight blue', 'paper': 'Paper',
  'contrast': 'High contrast', 'pureblack': 'Pure Black', 'oled': 'OLED Blue', 'amoled': 'AMOLED Green', 'neon': 'AMOLED Neon',
  'desert': 'Desert', 'ocean': 'Ocean', 'forest': 'Forest', 'sakura': 'Sakura', 'arctic': 'Arctic', 'coffee': 'Coffee',
  'sunset': 'Sunset', 'aurora': 'Aurora', 'lava': 'Lava', 'night': 'Starry night', 'waves': 'Waves', 'candy': 'Candy',
  'mood': 'Vivid tint', 'mint': 'Moving mint', 'lavender': 'Lavender', 'lavenderSoft': 'Soft lavender',
  'lavenderNight': 'Lavender night', 'lavenderOled': 'Lavender OLED', 'lavenderHarmony': 'Moving lavender',
  'shop_ciliegio': 'Cherry blossom', 'shop_caramella': 'Candy', 'shop_abisso': 'Abyss', 'shop_matrix': 'Matrix',
  'shop_oro': 'Black and gold', 'shop_cosmo': 'Cosmos',
};
const _themeCategoriesEn = {
  'Classici': 'Classic', 'Neri (OLED)': 'Blacks (OLED)', 'Natura': 'Nature', 'Animati': 'Animated', 'Lavanda': 'Lavender',
  'Dal negozio': 'From the shop', 'Il tuo tema': 'Your theme',
};

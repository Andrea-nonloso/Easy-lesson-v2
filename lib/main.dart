import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';

import 'log.dart';
import 'store.dart';
import 'ui/backdrop.dart';
import 'ui/home_shell.dart';
import 'ui/onboarding.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppLog.install();
  final store = await AppStore.create();
  runApp(EasyLessonApp(store: store));
}

class EasyLessonApp extends StatelessWidget {
  const EasyLessonApp({super.key, required this.store});

  final AppStore store;

  static final Map<String, ThemeData> _themes = {};

  static ThemeData _theme(AppThemeSpec spec, Brightness b,
          {bool contrast = false, bool readable = false, bool expressive = true, int spacing = 0}) =>
      _themes.putIfAbsent(
        '${spec.id}-${spec.seed.toARGB32()}-${spec.background?.toARGB32()}-${spec.card?.toARGB32()}'
        '-${spec.nav?.toARGB32()}-${spec.pureBlack}-${b.name}-$contrast-$readable-$expressive-$spacing',
        () {
          var t = buildTheme(b, spec);
          // 3.0: stile "Material 3 Expressive" (forme più tonde, pulsanti e barra più grandi).
          if (expressive) t = expressiveTheme(t);
          // Accessibilità: testi secondari e bordi più marcati.
          if (contrast) {
            final c = t.colorScheme;
            t = t.copyWith(
              colorScheme: c.copyWith(onSurfaceVariant: c.onSurface, outline: c.onSurface, outlineVariant: c.onSurfaceVariant),
            );
          }
          // Font ad alta leggibilità (Lexend), più spazio tra lettere e righe.
          if (readable) {
            TextTheme spaced(TextTheme x) => GoogleFonts.lexendTextTheme(x).apply(fontSizeFactor: 1.0).copyWith(
                  bodyLarge: GoogleFonts.lexend(textStyle: x.bodyLarge?.copyWith(letterSpacing: 0.4, height: 1.5)),
                  bodyMedium: GoogleFonts.lexend(textStyle: x.bodyMedium?.copyWith(letterSpacing: 0.4, height: 1.5)),
                  bodySmall: GoogleFonts.lexend(textStyle: x.bodySmall?.copyWith(letterSpacing: 0.4, height: 1.5)),
                );
            t = t.copyWith(textTheme: spaced(t.textTheme), primaryTextTheme: spaced(t.primaryTextTheme));
          }
          // 3.9: spaziatura del testo (lettere, parole, righe), anche senza Lexend.
          if (spacing > 0) {
            final k = spacing.clamp(1, 3);
            final letter = const [0.0, 0.3, 0.6, 1.0][k];
            final word = const [0.0, 1.5, 3.0, 5.0][k];
            final line = const [1.0, 1.45, 1.6, 1.8][k];
            TextStyle? sp(TextStyle? x) => x?.copyWith(letterSpacing: (x.letterSpacing ?? 0) + letter, wordSpacing: word, height: line);
            TextTheme all(TextTheme x) => x.copyWith(
                  bodyLarge: sp(x.bodyLarge),
                  bodyMedium: sp(x.bodyMedium),
                  bodySmall: sp(x.bodySmall),
                  titleMedium: sp(x.titleMedium),
                  titleSmall: sp(x.titleSmall),
                  labelLarge: sp(x.labelLarge),
                );
            t = t.copyWith(textTheme: all(t.textTheme), primaryTextTheme: all(t.primaryTextTheme));
          }
          return t;
        },
      );

  @override
  Widget build(BuildContext context) {
    return StoreScope(
      store: store,
      child: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final spec = themeById(store.themeId, custom: store.customThemeSpec);
          return MaterialApp(
          title: 'Easy Lesson',
          debugShowCheckedModeBanner: false,
          // Opzioni sviluppatore.
          showPerformanceOverlay: store.opt('dev.perf', false),
          showSemanticsDebugger: store.opt('dev.semantics', false),
          // Calendario, orologio e testi dei componenti in italiano.
          locale: Locale(store.opt('lang', 'it')),
          supportedLocales: const [Locale('it'), Locale('en')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          themeMode: switch (spec.brightness) {
            Brightness.light => ThemeMode.light,
            Brightness.dark => ThemeMode.dark,
            null => ThemeMode.system,
          },
          theme: _theme(spec, spec.brightness ?? Brightness.light,
              contrast: store.opt('a11y.contrast', false),
              readable: store.opt('a11y.font', false),
              spacing: store.opt('a11y.spacing', 0),
              expressive: store.opt('look.expressive', true)),
          darkTheme: _theme(spec, spec.brightness ?? Brightness.dark,
              contrast: store.opt('a11y.contrast', false),
              readable: store.opt('a11y.font', false),
              spacing: store.opt('a11y.spacing', 0),
              expressive: store.opt('look.expressive', true)),
          // Sfondo del tema (anche animato) dietro a tutte le schermate, con la dimensione del testo scelta.
          builder: (context, child) {
            final mq = MediaQuery.of(context);
            final scale = store.opt('a11y.text', 100) / 100;
            return MediaQuery(
              data: mq.copyWith(
                textScaler: scale == 1 ? mq.textScaler : TextScaler.linear(mq.textScaler.scale(1) * scale),
                highContrast: mq.highContrast || store.opt('a11y.contrast', false),
                disableAnimations: mq.disableAnimations || store.opt('a11y.motion', false),
              ),
              child: AppBackdrop(child: child ?? const SizedBox()),
            );
          },
          scrollBehavior: const _AppScrollBehavior(),
          home: store.setupDone ? const HomeShell() : const OnboardingPage(),
          );
        },
      ),
    );
  }
}

/// Permette lo swipe tra i giorni anche con mouse e trackpad (versione web).
class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.unknown,
      };
}


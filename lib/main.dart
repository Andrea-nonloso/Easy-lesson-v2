import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

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

  static ThemeData _theme(AppThemeSpec spec, Brightness b) =>
      _themes.putIfAbsent(
        '${spec.id}-${spec.seed.toARGB32()}-${spec.background?.toARGB32()}-${spec.card?.toARGB32()}'
        '-${spec.nav?.toARGB32()}-${spec.pureBlack}-${b.name}',
        () => buildTheme(b, spec),
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
          locale: const Locale('it'),
          supportedLocales: const [Locale('it'), Locale('en')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          themeMode: switch (spec.brightness) {
            Brightness.light => ThemeMode.light,
            Brightness.dark => ThemeMode.dark,
            null => ThemeMode.system,
          },
          theme: _theme(spec, spec.brightness ?? Brightness.light),
          darkTheme: _theme(spec, spec.brightness ?? Brightness.dark),
          // Sfondo del tema (anche animato) dietro a tutte le schermate
          builder: (context, child) => AppBackdrop(child: child ?? const SizedBox()),
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


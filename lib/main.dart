import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';

import 'store.dart';
import 'ui/home_shell.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await AppStore.create();
  runApp(EasyLessonApp(store: store));
}

class EasyLessonApp extends StatelessWidget {
  const EasyLessonApp({super.key, required this.store});

  final AppStore store;

  static final _light = buildTheme(Brightness.light);
  static final _dark = buildTheme(Brightness.dark);

  @override
  Widget build(BuildContext context) {
    return StoreScope(
      store: store,
      child: ListenableBuilder(
        listenable: store,
        builder: (context, _) => MaterialApp(
          title: 'Easy Lesson',
          debugShowCheckedModeBanner: false,
          themeMode: store.themeMode,
          theme: _light,
          darkTheme: _dark,
          scrollBehavior: const _AppScrollBehavior(),
          home: const HomeShell(),
        ),
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

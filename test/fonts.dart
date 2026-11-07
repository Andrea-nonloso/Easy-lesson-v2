// Font veri per le immagini delle schermate (SCREENS=1): Roboto, Hind, icone.
import 'dart:io';

import 'package:flutter/services.dart';

Future<void> loadTestFonts() async {
  final dir = '${Platform.environment['FLUTTER_ROOT'] ?? '${Platform.environment['HOME']}/dev/flutter'}/bin/cache/artifacts/material_fonts';
  if (!Directory(dir).existsSync()) return;
  final roboto = FontLoader('Roboto');
  for (final f in ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf']) {
    roboto.addFont(File('$dir/$f').readAsBytes().then((b) => ByteData.view(b.buffer)));
  }
  await roboto.load();
  final hind = FontLoader('Hind');
  for (final f in ['Light', 'Regular', 'Medium', 'Bold']) {
    hind.addFont(File('assets/fonts/HindSiliguri-$f.ttf').readAsBytes().then((b) => ByteData.view(b.buffer)));
  }
  await hind.load();
  final easy = FontLoader('EasyIcons')..addFont(File('assets/fonts/MyFlutterApp.ttf').readAsBytes().then((b) => ByteData.view(b.buffer)));
  await easy.load();
  final icons = FontLoader('MaterialIcons')..addFont(File('$dir/MaterialIcons-Regular.otf').readAsBytes().then((b) => ByteData.view(b.buffer)));
  await icons.load();
}

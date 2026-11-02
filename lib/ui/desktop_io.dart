import 'dart:async';
import 'dart:io';

import 'package:local_notifier/local_notifier.dart';
import 'package:tray_manager/legacy.dart';

import '../log.dart';
import '../models.dart';
import '../native.dart';
import '../store.dart';

/// Windows: notifiche (le stesse di Android, mentre l'app è aperta o ridotta a icona)
/// e un'icona vicino all'orologio con la lezione di adesso / la prossima.
class DesktopBridge with TrayListener {
  DesktopBridge._(this._store);

  static DesktopBridge? _instance;
  final AppStore _store;
  Timer? _timer;
  DateTime _last = DateTime.now();
  String _tip = '';

  static bool get supported => Platform.isWindows;

  static Future<void> init(AppStore store) async {
    if (!supported || _instance != null) return;
    final b = DesktopBridge._(store);
    _instance = b;
    try {
      await localNotifier.setup(appName: 'Easy Lesson', shortcutPolicy: ShortcutPolicy.requireCreate);
    } catch (e) {
      AppLog.w('windows', 'Notifiche non disponibili: $e');
    }
    try {
      await trayManager.setIcon('assets/images/tray.ico');
      trayManager.addListener(b);
    } catch (e) {
      AppLog.w('windows', 'Icona nell\'area di notifica non disponibile: $e');
    }
    await b._update();
    b._timer = Timer.periodic(const Duration(seconds: 30), (_) => b._update());
  }

  static void notify(String title, String body) {
    if (!supported) return;
    try {
      LocalNotification(title: title, body: body).show();
    } catch (e) {
      AppLog.w('windows', 'Notifica non mostrata: $e');
    }
  }

  Future<void> _update() async {
    final now = DateTime.now();
    // Notifiche arrivate nell'ultimo giro (stesse regole di Android).
    for (final m in NativeBridge.reminders(_store, _last)) {
      final at = DateTime.fromMillisecondsSinceEpoch(m['at'] as int);
      if (at.isAfter(_last) && !at.isAfter(now)) notify('${m['title']}', '${m['body']}');
    }
    _last = now;
    // Testo dell'icona.
    final groups = NativeBridge.groupsOn(_store, now);
    final slots = _store.slots;
    final m = now.hour * 60 + now.minute;
    var tip = 'Easy Lesson';
    final lines = <String>[];
    for (final g in groups) {
      final s = slots[g.from].start!;
      final e = slots[g.to].end!;
      if (m >= s && m < e) tip = 'Adesso: ${g.lesson.title} fino alle ${TimeSlot.fmt(e)}';
      if (s > m) {
        if (tip == 'Easy Lesson') tip = 'Prossima: ${g.lesson.title} alle ${TimeSlot.fmt(s)}';
        lines.add('${TimeSlot.fmt(s)} ${g.lesson.title}');
      }
    }
    if (tip == _tip) return;
    _tip = tip;
    try {
      await trayManager.setToolTip(tip);
      await trayManager.setContextMenu(Menu(items: [
        MenuItem(key: 'now', label: tip, disabled: true),
        if (lines.isNotEmpty) MenuItem.separator(),
        for (final l in lines.take(6)) MenuItem(key: l, label: l, disabled: true),
        MenuItem.separator(),
        MenuItem(key: 'exit', label: 'Chiudi Easy Lesson'),
      ]));
    } catch (_) {/* area di notifica non disponibile */}
  }

  @override
  void onTrayIconMouseDown() => trayManager.popUpContextMenu();

  @override
  void onTrayIconRightMouseDown() => trayManager.popUpContextMenu();

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'exit') {
      _timer?.cancel();
      exit(0);
    }
  }
}

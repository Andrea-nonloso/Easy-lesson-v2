import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'cloud.dart';
import 'log.dart';
import 'store.dart';
import 'updater.dart';

/// Un avviso dal server (es. "domani sciopero"). level: info | warning | urgent.
class Announcement {
  const Announcement({
    required this.id,
    required this.title,
    this.body = '',
    this.level = 'info',
    this.link,
    required this.starts,
    required this.ends,
  });

  final String id;
  final String title;
  final String body;
  final String level;
  final String? link;
  final DateTime starts;
  final DateTime ends;

  /// Gli avvisi urgenti non si possono chiudere finché durano.
  bool get urgent => level == 'urgent';

  static Announcement? fromJson(Object? j) {
    if (j is! Map) return null;
    final id = j['id'];
    final title = j['title'];
    final s = j['starts'];
    final e = j['ends'];
    if (id is! String || title is! String || s is! num || e is! num) return null;
    final link = j['link'];
    return Announcement(
      id: id,
      title: title,
      body: j['body'] is String ? j['body'] as String : '',
      level: const {'info', 'warning', 'urgent'}.contains(j['level']) ? j['level'] as String : 'info',
      link: link is String && (link.startsWith('https://') || link.startsWith('http://')) ? link : null,
      starts: DateTime.fromMillisecondsSinceEpoch(s.toInt()),
      ends: DateTime.fromMillisecondsSinceEpoch(e.toInt()),
    );
  }
}

/// Avvisi dal server: scaricati al massimo ogni ora, tenuti in memoria per quando manca la rete.
class Announcements {
  Announcements._();

  static String get platform {
    if (kIsWeb) return 'web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.windows => 'windows',
      TargetPlatform.iOS => 'ios',
      TargetPlatform.macOS => 'macos',
      TargetPlatform.linux => 'linux',
      TargetPlatform.fuchsia => 'other',
    };
  }

  static Future<void> refresh(AppStore s, {bool force = false}) async {
    final last = DateTime.tryParse(s.opt('ann.at', ''));
    if (!force && last != null && DateTime.now().difference(last) < const Duration(hours: 1)) return;
    try {
      final list = await Cloud.announcements(version: await Updater.currentVersion(), platform: platform);
      await s.setOpt('ann.cache', jsonEncode(list));
      await s.setOpt('ann.at', DateTime.now().toIso8601String());
    } catch (e) {
      AppLog.w('avvisi', 'Avvisi non scaricati: $e');
    }
  }

  static Set<String> _dismissed(AppStore s) => s.opt('ann.dismissed', '').split(',').where((x) => x.isNotEmpty).toSet();

  /// Quelli da mostrare adesso: in corso e non chiusi (gli urgenti sempre). Prima i più gravi.
  static List<Announcement> current(AppStore s, [DateTime? now]) {
    final t = now ?? DateTime.now();
    final hidden = _dismissed(s);
    List<Object?> raw;
    try {
      final j = jsonDecode(s.opt('ann.cache', '[]'));
      raw = j is List ? j : const [];
    } catch (_) {
      raw = const [];
    }
    const order = {'urgent': 0, 'warning': 1, 'info': 2};
    return [
      for (final r in raw)
        if (Announcement.fromJson(r) case final a?)
          if (!t.isBefore(a.starts) && t.isBefore(a.ends) && (a.urgent || !hidden.contains(a.id))) a,
    ]..sort((a, b) => order[a.level]!.compareTo(order[b.level]!));
  }

  static Future<void> dismiss(AppStore s, String id) async {
    final list = [..._dismissed(s), id];
    // Basta ricordarsi gli ultimi 50.
    await s.setOpt('ann.dismissed', list.skip(list.length > 50 ? list.length - 50 : 0).join(','));
  }
}

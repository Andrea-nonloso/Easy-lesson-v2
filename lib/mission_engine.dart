import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;

import 'cloud.dart';
import 'log.dart';
import 'missions.dart';
import 'progress.dart' show isoDay;
import 'store.dart';
import 'i18n.dart';

/// Valore attuale di una metrica delle missioni (sempre crescente, o quasi).
int missionMetric(AppStore s, String metric) => switch (metric) {
      'studied' => s.studyMinutes.values.fold(0, (a, b) => a + b),
      'agendaDone' => s.agenda.where((a) => a.done).length,
      'countdowns' => s.countdowns.length,
      'teachers' => s.teachers.length,
      _ => s.stat(metric),
    };

class MissionStatus {
  MissionStatus(this.def, this.progress, this.done, this.xp);
  final MissionDef def;
  final int progress;
  final bool done;

  /// XP che dà (con il moltiplicatore dell'evento, se c'è).
  final int xp;
}

/// Il motore delle missioni: sceglie quelle del giorno/settimana, guarda i progressi, dà le XP.
/// Stato salvato nelle opzioni: mis.d.* (giorno) e mis.w.* (settimana).
class Missions {
  Missions._();

  // ------------------------------------------------------------------ eventi (dal server)

  static List<MissionEvent> events(AppStore s) {
    try {
      final list = jsonDecode(s.opt('event.cache', '[]'));
      return [
        for (final e in (list is List ? list : const []))
          if (MissionEvent.fromJson(e) case final ev?) ev,
      ];
    } catch (_) {
      return const [];
    }
  }

  static MissionEvent? activeEvent(AppStore s, [DateTime? now]) {
    final t = now ?? DateTime.now();
    for (final e in events(s)) {
      if (e.activeAt(t)) return e;
    }
    return null;
  }

  /// Riscarica gli eventi dal server (al massimo ogni 6 ore). Funziona anche senza account.
  static Future<void> refreshEvents(AppStore s, {bool force = false}) async {
    final last = DateTime.tryParse(s.opt('event.at', ''));
    if (!force && last != null && DateTime.now().difference(last) < const Duration(hours: 6)) return;
    try {
      final list = await Cloud.events();
      await s.setOpt('event.cache', jsonEncode(list));
      await s.setOpt('event.at', DateTime.now().toIso8601String());
    } catch (e) {
      AppLog.w('missioni', 'Eventi non scaricati: $e');
    }
  }

  // ------------------------------------------------------------------ giorno e settimana

  static String _p(bool weekly) => weekly ? 'mis.w' : 'mis.d';

  static bool _schoolToday(AppStore s, DateTime now) {
    final days = s.myScheduleOn(now)?.week.days;
    if (days != null) {
      return now.weekday - 1 < days.length && !days[now.weekday - 1].isEmpty && s.calendar.closureOn(now) == null;
    }
    return s.calendar.isSchoolDay(now);
  }

  /// Se è cambiato il giorno (o la settimana), escono le missioni nuove.
  static Future<void> _roll(AppStore s, DateTime now, {required bool weekly}) async {
    final p = _p(weekly);
    final key = weekly ? weekKey(now) : isoDay(now);
    if (s.opt('$p.key', '') == key) return;
    final school = _schoolToday(s, now);
    final ev = activeEvent(s, now);
    final picked = pickMissions(
      weekly ? weeklyMissions : dailyMissions,
      key,
      3,
      allowed: (m) => (!m.schoolDay || school) && (!m.notOnWeb || !kIsWeb),
      forced: weekly || ev == null ? const [] : ev.daily,
    );
    final base = <String, int>{};
    for (final m in picked) {
      var v = missionMetric(s, m.metric);
      // L'apertura di adesso (e il giorno di oggi) contano già.
      if (!weekly && m.metric == 'sessions') v -= 1;
      if (weekly && m.metric == 'days') v -= 1;
      base[m.id] = v;
    }
    await s.setOpt('$p.key', key);
    await s.setOpt('$p.ids', picked.map((m) => m.id).join(','));
    await s.setOpt('$p.base', base);
    await s.setOpt('$p.done', '');
    await s.setOpt('$p.bonus', null);
    AppLog.i('missioni', '${weekly ? 'Settimana' : 'Giorno'} $key: ${picked.map((m) => m.id).join(', ')}');
  }

  static Set<String> _done(AppStore s, bool weekly) =>
      s.opt('${_p(weekly)}.done', '').split(',').where((x) => x.isNotEmpty).toSet();

  /// Missioni di adesso con il loro progresso.
  static List<MissionStatus> status(AppStore s, {required bool weekly}) {
    final p = _p(weekly);
    final ids = s.opt('$p.ids', '').split(',').where((x) => x.isNotEmpty).toList();
    final base = s.opt<Map>('$p.base', const {});
    final done = _done(s, weekly);
    final mult = activeEvent(s)?.multiplier ?? 1.0;
    final pool = weekly ? weeklyMissions : dailyMissions;
    return [
      for (final id in ids)
        for (final m in pool)
          if (m.id == id)
            MissionStatus(
              m,
              done.contains(id)
                  ? m.goal
                  : (missionMetric(s, m.metric) - ((base[id] as num?)?.toInt() ?? 0)).clamp(0, m.goal).toInt(),
              done.contains(id),
              (m.xp * mult).round(),
            ),
    ];
  }

  /// Controlla le missioni: nuove se è cambiato il giorno, XP per quelle finite.
  /// Restituisce i messaggi da mostrare (missioni completate e bonus).
  static Future<List<String>> check(AppStore s, [DateTime? at]) async {
    final now = at ?? DateTime.now();
    await _roll(s, now, weekly: false);
    await _roll(s, now, weekly: true);
    final ev = activeEvent(s, now);
    final out = <String>[];
    for (final weekly in [false, true]) {
      final p = _p(weekly);
      final done = _done(s, weekly);
      final list = status(s, weekly: weekly);
      var changed = false;
      for (final m in list) {
        if (m.done || m.progress < m.def.goal) continue;
        done.add(m.def.id);
        changed = true;
        await s.setOpt('stat.missionXp', s.stat('missionXp') + m.xp);
        await s.bump(weekly ? 'weeklyMissionsDone' : 'missionsDone');
        if (ev != null) await s.bump('eventMissions');
        out.add('${m.def.emoji} Missione completata: ${m.def.title} · +${m.xp} XP');
      }
      if (!changed) continue;
      await s.setOpt('$p.done', (done.toList()..sort()).join(','));
      if (list.isNotEmpty && list.every((m) => done.contains(m.def.id)) && !s.opt('$p.bonus', false)) {
        final bonus = weekly ? weeklyBonusXp : dailyBonusXp;
        await s.setOpt('$p.bonus', true);
        await s.setOpt('stat.missionXp', s.stat('missionXp') + bonus);
        await s.bump(weekly ? 'weeklyFull' : 'dailyFull');
        out.add(weekly ? tr('🌟 Settimana perfetta! +$bonus XP', '🌟 Perfect week! +$bonus XP') : tr('⭐ Tutte le missioni di oggi! +$bonus XP', '⭐ All of today\'s missions! +$bonus XP'));
      }
    }
    return out;
  }

  /// Quanto manca a nuove missioni.
  static Duration untilNext(DateTime now, {required bool weekly}) {
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    if (!weekly) return tomorrow.difference(now);
    final monday = DateTime(now.year, now.month, now.day + (8 - now.weekday));
    return monday.difference(now);
  }
}

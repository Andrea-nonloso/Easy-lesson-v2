import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'agenda.dart' show dateOnly;
import 'bag.dart';
import 'log.dart';
import 'models.dart';
import 'school_calendar.dart';
import 'school_extra.dart';
import 'school_life.dart';
import 'store.dart';
import 'updater.dart';
import 'ui/fun.dart' show labInfo;

/// Ponte con Android (MainActivity.kt): notifiche, widget, scorciatoie.
/// Sulle altre piattaforme non fa niente.
class NativeBridge {
  NativeBridge._();

  static const _ch = MethodChannel('easylesson/native');

  static bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<T?> _call<T>(String method, [Object? args]) async {
    if (!supported) return null;
    try {
      return await _ch.invokeMethod<T>(method, args);
    } catch (e) {
      AppLog.w('native', '$method: $e');
      return null;
    }
  }

  /// Salva un piccolo testo nel Block Store di Google (codici dell'account). true = salvato.
  static Future<bool> vaultSave(String data) async => await _call<bool>('vaultSave', data) ?? false;

  /// Legge quello salvato con [vaultSave] (anche su un telefono nuovo, dopo il ripristino di Google).
  static Future<String?> vaultRead() => _call<String>('vaultRead');

  static Future<void> vaultDelete() async {
    await _call<bool>('vaultDelete');
  }

  /// Una notifica sola a un'ora precisa (timer di studio). [id] tra 7000 e 7099.
  static Future<void> scheduleOne(int id, DateTime at, String title, String body) =>
      _call<bool>('scheduleOne', jsonEncode({'id': id, 'at': at.millisecondsSinceEpoch, 'title': title, 'body': body}));

  static Future<void> cancelOne(int id) => _call<bool>('cancelOne', id);

  /// "Non disturbare" a scuola: serve il permesso speciale di Android.
  /// Notifica subito (es. "l'orario è cambiato").
  static Future<void> notifyNow(String title, String body) => testNotification(title, body, channel: 'giorno');

  /// Schermo sempre acceso (modalità verifica).
  static Future<void> keepScreenOn(bool on) => _call<bool>('keepScreenOn', on);

  /// Non disturbare subito (modalità verifica), se c'è il permesso.
  static Future<void> silenceNow(bool on) => _call<bool>('silenceNow', on);

  /// Apre le impostazioni delle notifiche dell'app in Android.
  static Future<void> openNotificationSettings() => _call<bool>('openNotificationSettings');

  static Future<bool> silenceAllowed() async => await _call<bool>('silenceAllowed') ?? false;
  static Future<void> openSilenceSettings() => _call<bool>('openSilenceSettings');

  /// Mostra subito una notifica (per provarle dalle opzioni sviluppatore).
  static Future<void> testNotification(String title, String body, {String channel = 'lezioni'}) =>
      _call<bool>('testNotification', jsonEncode({'title': title, 'body': body, 'ch': channel}));

  /// Icona dell'app scelta ("default", "blue", ...).
  static Future<String> appIcon() async => await _call<String>('getAppIcon') ?? 'default';
  static Future<void> setAppIcon(String id) => _call<bool>('setAppIcon', id);

  /// Controllo aggiornamenti in background: ogni qualche ora guarda GitHub e
  /// manda una notifica se c'è una versione nuova.
  static Future<void> configureUpdates({required bool enabled, required bool beta, required String current}) =>
      _call<bool>('configureUpdates', jsonEncode({
        'enabled': enabled,
        'beta': beta,
        'current': current,
        'repo': githubRepo,
      }));

  /// Fa subito il controllo in background (anche se la versione era già stata notificata).
  static Future<void> runUpdateCheckNow() => _call<bool>('runUpdateCheck');

  static Future<bool> notificationsAllowed() async => await _call<bool>('notificationsAllowed') ?? false;
  static Future<bool> requestNotificationPermission() async =>
      await _call<bool>('requestNotificationPermission') ?? false;

  /// Scorciatoia con cui è stata aperta l'app ("mine", "prof", "agenda"), una volta sola.
  static Future<String?> takeShortcut() => _call<String>('takeShortcut');

  /// 3.0: notifica "lezione in corso" (Live Update su Android 16+), vedi LiveLesson.kt.
  static Future<void> setLiveLesson(bool on) => _call<bool>('setLiveLesson', on);

  /// Scorciatoie e risposte che arrivano con l'app già aperta.
  static void listen(void Function(String shortcut) onShortcut) {
    if (!supported) return;
    _ch.setMethodCallHandler((call) async {
      if (call.method == 'shortcut' && call.arguments is String) onShortcut(call.arguments as String);
      return null;
    });
  }

  // ------------------------------------------------------------ sincronizzazione

  static Timer? _debounce;
  static String? _lastNotify;
  static String? _lastWidget;
  static String? _lastUpdates;
  static String? _lastSilence;
  static bool? _lastLive;
  static String? _version;

  /// Da chiamare quando cambia qualcosa nello store: dopo un attimo aggiorna
  /// notifiche e widget (solo se il contenuto è cambiato davvero).
  static void scheduleSync(AppStore store) {
    if (!supported) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), () => sync(store));
  }

  static Future<void> sync(AppStore store) async {
    if (!supported) return;
    final now = DateTime.now();
    final widget = jsonEncode(widgetData(store));
    if (widget != _lastWidget) {
      _lastWidget = widget;
      await _call<bool>('updateWidget', widget);
    }
    _version ??= await Updater.currentVersion();
    final upd = jsonEncode([store.opt('n.updates', true), store.betaUpdates, _version]);
    if (upd != _lastUpdates) {
      _lastUpdates = upd;
      await configureUpdates(
          enabled: store.opt('n.updates', true), beta: store.betaUpdates, current: _version ?? '');
    }
    final live = store.opt('n.live', false);
    if (live != _lastLive) {
      _lastLive = live;
      await setLiveLesson(live);
    }
    final silence = jsonEncode(store.opt('silence', false) ? silenceWindows(store, now) : const []);
    if (silence != _lastSilence) {
      _lastSilence = silence;
      await _call<bool>('scheduleSilence', silence);
    }
    final notify = jsonEncode(reminders(store, now));
    if (notify != _lastNotify) {
      _lastNotify = notify;
      await _call<bool>('scheduleNotifications', notify);
      AppLog.i('notifiche', 'Programmate ${(jsonDecode(notify) as List).length} notifiche');
    }
  }

  /// Gruppi di ore uguali consecutive del giorno (come nella vista giorno).
  static List<({int from, int to, Lesson lesson})> _groups(DaySchedule day, List<TimeSlot> slots) {
    final out = <({int from, int to, Lesson lesson})>[];
    final breaks = breaksOf(slots);
    var i = 0;
    while (i < day.lessons.length) {
      final l = day.lessons[i];
      var j = i;
      while (j + 1 < day.lessons.length &&
          day.lessons[j + 1].signature == l.signature &&
          breakAfter(breaks, j) == null) {
        j++;
      }
      if (!l.isEmpty && i < slots.length && j < slots.length && slots[i].start != null && slots[j].end != null) {
        out.add((from: i, to: j, lesson: l));
      }
      i = j + 1;
    }
    return out;
  }

  static String _place(Lesson l) => l.lab.isEmpty ? '' : '${labInfo(l.lab).emoji} ${l.lab}';

  /// Gruppi di ore del mio orario nel giorno [d], tenendo conto di entrate e uscite.
  static List<({int from, int to, Lesson lesson})> groupsOn(AppStore store, DateTime d) {
    final days = store.myScheduleOn(d)?.week.days;
    final wd = d.weekday - 1;
    if (days == null || wd >= days.length || store.calendar.closureOn(d) != null) return const [];
    final range = store.attendedOn(d, days[wd].lessons.length);
    if (range == null) return const [];
    return _groups(days[wd], store.slots).where((g) => g.to >= range.$1 && g.from <= range.$2).toList();
  }

  /// Dati per il widget (formato in LessonWidget.kt).
  static Map<String, dynamic> widgetData(AppStore store) {
    final ref = store.myRef;
    final cached = ref == null ? null : store.cached(ref);
    if (ref == null || cached == null) return const {};
    final slots = store.slots;
    final now = DateTime.now();
    String iso(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    // Prossimi 120 giorni senza scuola (vacanze e feste), già con il nome.
    final off = <List<String>>[];
    final cal = store.calendar;
    for (var k = 0; k < 120; k++) {
      final d = DateTime(now.year, now.month, now.day + k);
      final c = cal.closureOn(d);
      if (c != null && d.weekday <= cached.week.days.length) off.add([iso(d), iso(d), '${c.emoji} ${c.name}']);
    }
    // Prossimi compiti e verifiche (per il widget agenda).
    final agenda = [
      for (final a in store.agendaFrom(now, days: 14).take(8)) [iso(a.date), a.summary],
    ];
    // Entrate/uscite già note: il widget mostra solo le ore in cui ci sei.
    final skip = <List<Object>>[];
    for (var k = 0; k < 14; k++) {
      final d = DateTime(now.year, now.month, now.day + k);
      final wd = d.weekday - 1;
      if (wd >= cached.week.days.length) continue;
      final n = cached.week.days[wd].lessons.length;
      final r = store.attendedOn(d, n);
      if (r == null) {
        skip.add([iso(d), 0, -1]);
      } else if (r.$1 > 0 || r.$2 < n - 1) {
        final s0 = r.$1 < slots.length ? slots[r.$1].start : null;
        final e0 = r.$2 < slots.length ? slots[r.$2].end : null;
        if (s0 != null && e0 != null) skip.add([iso(d), s0, e0]);
      }
    }
    // Medie per il widget dei voti.
    final bySubject = <String, List<Grade>>{};
    for (final g in store.grades) {
      (bySubject[g.subject] ??= []).add(g);
    }
    final avgs = [for (final e in bySubject.entries) [e.key, average(e.value)!.toStringAsFixed(2)]]
      ..sort((a, b) => a[0].compareTo(b[0]));
    final all = bySubject.values.map((l) => average(l)!).toList();
    return {
      'grades': avgs,
      'gradesAvg': all.isEmpty ? '' : (all.reduce((a, b) => a + b) / all.length).toStringAsFixed(2),
      'agenda': agenda,
      'only': skip,
      'name': ref.displayName,
      'days': [
        for (final day in cached.week.days)
          [
            for (final g in _groups(day, slots))
              {
                's': slots[g.from].start,
                'e': slots[g.to].end,
                't': g.lesson.title,
                'p': _place(g.lesson),
              },
          ],
      ],
      'off': off,
    };
  }

  /// Intervalli in cui stare in silenzioso: dall'inizio della prima ora alla fine dell'ultima
  /// (con entrate/uscite), per le prossime 3 settimane. [[inizio, fine], ...] in millisecondi.
  static List<List<int>> silenceWindows(AppStore store, DateTime now) {
    final slots = store.slots;
    final cal = store.calendar;
    final out = <List<int>>[];
    for (var k = 0; k < 21; k++) {
      final d = DateTime(now.year, now.month, now.day + k);
      final days = store.myScheduleOn(d)?.week.days;
      final wd = d.weekday - 1;
      if (days == null || wd >= days.length || !cal.isSchoolDay(d, daysPerWeek: days.length)) continue;
      final range = store.attendedOn(d, days[wd].lessons.length);
      if (range == null) continue;
      final groups = _groups(days[wd], slots).where((g) => g.to >= range.$1 && g.from <= range.$2).toList();
      if (groups.isEmpty) continue;
      final s = slots[groups.first.from].start!;
      final e = slots[groups.last.to].end!;
      final a = DateTime(d.year, d.month, d.day, s ~/ 60, s % 60);
      final b = DateTime(d.year, d.month, d.day, e ~/ 60, e % 60);
      if (b.isAfter(now)) out.add([a.millisecondsSinceEpoch, b.millisecondsSinceEpoch]);
    }
    return out;
  }

  /// Notifiche delle prossime 3 settimane (senza vacanze): lezioni, riepiloghi, ricreazione...
  static List<Map<String, Object>> reminders(AppStore store, DateTime now) {
    if (store.myScheduleOn(now) == null) return const [];
    final before = store.notifyMinutes;
    final evening = store.opt('n.evening', false);
    final eveningAt = store.opt('n.eveningAt', 20 * 60);
    final morning = store.opt('n.morning', false);
    final morningLead = store.opt('n.morningLead', 30);
    final breaks = store.opt('n.break', false);
    final end = store.opt('n.end', false);
    final holiday = store.opt('n.holiday', false);
    final lastHour = store.opt('n.last', false);
    if (before == null && !evening && !morning && !breaks && !end && !holiday && !lastHour &&
        !store.opt('n.homework', false) && !store.opt('n.plan', false)) {
      return const [];
    }
    final slots = store.slots;
    final cal = store.calendar;
    final out = <Map<String, Object>>[];
    DateTime at(DateTime d, int minutes) => DateTime(d.year, d.month, d.day, minutes ~/ 60, minutes % 60);
    void add(int id, DateTime when, String title, String body, String ch) {
      if (!when.isAfter(now)) return;
      out.add({'id': id, 'at': when.millisecondsSinceEpoch, 'title': title, 'body': body, 'ch': ch});
    }

    final pauses = breaksOf(slots);
    for (var k = 0; k < 22 && out.length < 250; k++) {
      final d = DateTime(now.year, now.month, now.day + k);
      final wd = d.weekday - 1;
      final days = store.myScheduleOn(d)?.week.days;
      if (days == null) continue;
      final school = wd < days.length && cal.isSchoolDay(d, daysPerWeek: days.length);
      final prev = DateTime(d.year, d.month, d.day - 1);

      // Domani niente scuola: la sera prima, solo il primo giorno di chiusura.
      if (holiday && !school && wd < days.length) {
        final c = cal.closureOn(d);
        final pwd = prev.weekday - 1;
        if (c != null && pwd < days.length && cal.isSchoolDay(prev, daysPerWeek: days.length)) {
          final back = c.backOn;
          add(3000 + k * 10 + 7, at(prev, eveningAt), 'Domani niente scuola! ${c.emoji}',
              '${c.name}\nSi torna ${dayNames[back.weekday - 1].toLowerCase()} ${back.day}/${back.month}', 'giorno');
        }
      }
      if (!school) continue;
      // Entrate posticipate e uscite anticipate: si tengono solo le ore in cui ci sono.
      final range = store.attendedOn(d, days[wd].lessons.length);
      if (range == null) continue;
      final groups = _groups(days[wd], slots).where((g) => g.to >= range.$1 && g.from <= range.$2).toList();
      if (groups.isEmpty) continue;
      final first = groups.first;
      final last = groups.last;
      final firstStart = slots[first.from].start!;
      final lastEnd = slots[last.to].end!;
      final todo = store.agendaFrom(d, days: 1);
      final hoursCount = last.to + 1;

      // Riepilogo della sera prima.
      if (evening) {
        final items = <dynamic>{
          ...bagItems(days[wd], store.bagRules),
          ...extraBagItems(days[wd], d.weekday, store.materials, store.weeklyItems),
        }.toList();
        add(
          3000 + k * 10 + 6,
          at(prev, eveningAt),
          'Domani: $hoursCount ore, entri alle ${TimeSlot.fmt(firstStart)}',
          [
            groups.map((g) => g.lesson.title).toSet().join(', '),
            for (final a in todo) a.summary,
            if (items.isNotEmpty) '🎒 ${items.join(', ')}',
          ].join('\n'),
          'giorno',
        );
      }

      // Compiti per domani non ancora fatti (si ricalcola appena li spunti).
      if (store.opt('n.homework', false)) {
        final todoHw = todo.where((a) => a.kind == 'compito' && !a.done).toList();
        if (todoHw.isNotEmpty) {
          add(
            3000 + k * 10 + 9,
            at(prev, store.opt('n.homeworkAt', 18 * 60)),
            todoHw.length == 1 ? 'Hai ancora un compito per domani 📚' : 'Hai ancora ${todoHw.length} compiti per domani 📚',
            todoHw.map((a) => a.summary).join('\n'),
            'giorno',
          );
        }
      }

      // Buongiorno, prima di entrare.
      if (morning) {
        add(
          3000 + k * 10 + 0,
          at(d, firstStart - morningLead),
          'Buongiorno! Oggi ${first.lesson.title} alla prima ora',
          [
            'Entri alle ${TimeSlot.fmt(firstStart)}, esci alle ${TimeSlot.fmt(lastEnd)}',
            if (first.lesson.lab.isNotEmpty) _place(first.lesson),
            for (final a in todo) a.summary,
          ].join('\n'),
          'giorno',
        );
      }

      // Ricreazione.
      if (breaks) {
        var n = 0;
        for (final p in pauses) {
          if (p.afterIndex >= last.to || n >= 3) continue;
          final after = groups.where((g) => g.from > p.afterIndex).toList();
          add(
            3000 + k * 10 + 1 + n,
            at(d, p.start),
            'Ricreazione! ☕',
            'Fino alle ${TimeSlot.fmt(p.end)}${after.isEmpty ? '' : ' · Dopo: ${after.first.lesson.title}'}',
            'giorno',
          );
          n++;
        }
      }

      // Ultima ora e fine della scuola.
      if (lastHour && groups.length > 1) {
        add(3000 + k * 10 + 4, at(d, slots[last.from].start!), 'Ultima ora! 💪',
            '${last.lesson.title} fino alle ${TimeSlot.fmt(lastEnd)}', 'giorno');
      }
      if (end) {
        final next = store.nextSchoolDay(d, daysPerWeek: days.length);
        final nwd = next == null ? -1 : next.weekday - 1;
        final nextGroups = nwd >= 0 && nwd < days.length ? _groups(days[nwd], slots) : const <({int from, int to, Lesson lesson})>[];
        add(
          3000 + k * 10 + 5,
          at(d, lastEnd),
          'Scuola finita! 🎉',
          next == null || nextGroups.isEmpty
              ? 'Buon riposo!'
              : '${daysBetween(d, next) == 1 ? 'Domani' : dayNames[next.weekday - 1]} si entra alle '
                  '${TimeSlot.fmt(slots[nextGroups.first.from].start!)} con ${nextGroups.first.lesson.title}',
          'giorno',
        );
      }

      // Prima di ogni lezione.
      if (before != null) {
        for (final g in groups) {
          final start = slots[g.from].start!;
          final stop = slots[g.to].end!;
          final notes = store.agendaOn(d, g.lesson.title);
          final hours = g.to > g.from ? '${g.from + 1}ª–${g.to + 1}ª ora' : '${g.from + 1}ª ora';
          add(
            1000 + k * 20 + g.from,
            at(d, start).subtract(Duration(minutes: before)),
            before == 0 ? 'Adesso: ${g.lesson.title}' : 'Tra $before min: ${g.lesson.title}',
            [
              '$hours · ${TimeSlot.fmt(start)}–${TimeSlot.fmt(stop)}',
              if (g.lesson.lab.isNotEmpty) _place(g.lesson),
              if (g.lesson.details.isNotEmpty) g.lesson.details.first,
              for (final a in notes) a.summary,
            ].join('\n'),
            'lezioni',
          );
        }
      }
    }
    // Piano di studio: ogni pomeriggio cosa ripassare per le verifiche in arrivo.
    if (store.opt('n.plan', false)) {
      final plan = studyPlan(store.agenda, now, days: store.opt('plan.days', 3));
      final byDay = <String, List<StudyStep>>{};
      for (final p in plan) {
        (byDay[isoDay(p.day)] ??= []).add(p);
      }
      for (final e in byDay.entries) {
        final d = e.value.first.day;
        final k = daysBetween(dateOnly(now), d);
        if (k < 0 || k > 21) continue;
        add(3000 + k * 10 + 8, at(d, store.opt('n.planAt', 16 * 60)), 'Oggi si ripassa 📖',
            e.value.map((p) => '• ${p.label}').join('\n'), 'giorno');
      }
    }
    out.sort((a, b) => (a['at'] as int).compareTo(b['at'] as int));
    return out;
  }
}

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show compute, kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'agenda.dart';
import 'api.dart';
import 'bag.dart';
import 'log.dart';
import 'models.dart';
import 'progress.dart';
import 'school_calendar.dart';
import 'school_extra.dart' hide isoDay;
import 'school_life.dart';
import 'i18n.dart';
import 'live_sync.dart' show isLocalOnlyOption;
import 'timetable.dart';
import 'ui/theme.dart';
import 'xlsx.dart';

/// Un orario salvato sul dispositivo.
class CachedSchedule {
  CachedSchedule({
    required this.ref,
    required this.raw,
    required this.updatedAt,
    required this.lastOpened,
    this.favorite = false,
  });

  final ScheduleRef ref;
  final Map<String, dynamic> raw;
  final DateTime updatedAt;
  DateTime lastOpened;
  bool favorite;

  late final WeekSchedule week = WeekSchedule.fromJson(raw, prof: ref.prof);

  Map<String, dynamic> toJson() => {
        'name': ref.name,
        'prof': ref.prof,
        'raw': raw,
        'updatedAt': updatedAt.toIso8601String(),
        'lastOpened': lastOpened.toIso8601String(),
        'favorite': favorite,
      };

  static CachedSchedule? fromJson(dynamic j) {
    try {
      final m = Map<String, dynamic>.from(j as Map);
      return CachedSchedule(
        ref: ScheduleRef(m['name'] as String, prof: m['prof'] == true),
        raw: Map<String, dynamic>.from(m['raw'] as Map),
        updatedAt: DateTime.parse(m['updatedAt'] as String),
        lastOpened: DateTime.tryParse('${m['lastOpened']}') ?? DateTime.parse(m['updatedAt'] as String),
        favorite: m['favorite'] == true,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Parti del backup che si possono scegliere: (id, nome, cosa contiene).
const backupSections = <(String, String, String)>[
  ('orari', 'Orari salvati', 'Il tuo orario, preferiti, recenti ed elenchi'),
  ('aspetto', 'Aspetto', 'Tema, soprannomi ed emoji, nome (soprannomi e nome cifrati)'),
  ('agenda', 'Agenda e calendario', 'Compiti, conti alla rovescia, zaino, ponti'),
  ('scuola', 'Voti, assenze e studio', 'Voti, assenze, minuti di studio, prof, libri, foto (solo l\'elenco)'),
  ('opzioni', 'Impostazioni e progressi', 'Notifiche, campanelle, home, obiettivi e livello'),
  ('excel', 'File Excel importato', 'L\'orario completo della scuola: può pesare parecchio'),
];

/// Informativa privacy (pagina della versione web).
const privacyUrl = 'https://easylesson.khugudvjan.cc/privacy.html';

/// Dati sensibili: nel backup online vanno cifrati (voti, assenze, studio, prof, agenda,
/// impostazioni e statistiche, nome e soprannomi).
bool isSensitiveKey(String key) {
  final s = backupSectionOf(key);
  return secretBackupSections.contains(s) || key == 'el.username' || key == 'el.nicknames';
}

/// Sezioni del backup cifrate per intero (le altre vanno in chiaro, tranne nome e soprannomi).
/// 'opzioni' contiene el.extras: crediti, statistiche per prof (nomi di persone)…
const secretBackupSections = {'scuola', 'agenda', 'opzioni'};

/// Le sezioni consigliate (tutte tranne il file Excel).
const defaultBackupSections = {'orari', 'aspetto', 'agenda', 'scuola', 'opzioni'};

/// A quale sezione del backup appartiene una chiave della memoria.
String backupSectionOf(String key) => switch (key) {
      'el.schedules' || 'el.mine' || 'el.classi' || 'el.docenti' || 'el.ore' || 'el.listsAt' || 'el.grid' || 'el.changes' =>
        'orari',
      'el.theme' || 'el.themeId' || 'el.customTheme' || 'el.nicknames' || 'el.subjectEmojis' || 'el.username' => 'aspetto',
      'el.agenda' || 'el.closures' || 'el.countdowns' || 'el.weekly' || 'el.bagRules' || 'el.bagChecked' => 'agenda',
      'el.grades' ||
      'el.absences' ||
      'el.study' ||
      'el.studyLog' ||
      'el.teachers' ||
      'el.materials' ||
      'el.photos' =>
        'scuola',
      'el.xlsx' => 'excel',
      _ => 'opzioni',
    };

List<List<String>> _parseXlsx(List<int> bytes) => readXlsx(bytes);

/// Stato dell'app + persistenza locale (localStorage sul web,
/// SharedPreferences su Android e Windows).
class AppStore extends ChangeNotifier {
  AppStore._(this._prefs, this._api);

  static Future<AppStore> create({EasyLessonApi? api}) async {
    final prefs = await SharedPreferences.getInstance();
    final store = AppStore._(prefs, api ?? EasyLessonApi());
    store._load();
    store._countLaunch();
    unawaited(store.markActive());
    unawaited(store.refreshLists(onlyIfStale: true));
    return store;
  }

  final SharedPreferences _prefs;
  final EasyLessonApi _api;

  static const _kTheme = 'el.theme';
  static const _kUsername = 'el.username';
  static const _kSetupDone = 'el.setupDone';
  static const _kThemeId = 'el.themeId';
  static const _kCustomTheme = 'el.customTheme';
  static const _kClassi = 'el.classi';
  static const _kDocenti = 'el.docenti';
  static const _kOre = 'el.ore';
  static const _kListsAt = 'el.listsAt';
  static const _kSchedules = 'el.schedules';
  static const _kMine = 'el.mine';
  static const _kGrid = 'el.grid';
  static const _kXlsx = 'el.xlsx';
  static const _kSubjects = 'el.subjects';
  static const _kTeacherSubjects = 'el.teacherSubjects';
  static const _kDevMode = 'el.devMode';
  static const _kAgenda = 'el.agenda';
  static const _kBagRules = 'el.bagRules';
  static const _kBagChecked = 'el.bagChecked';
  static const _kClosures = 'el.closures';
  static const _kNotify = 'el.notify';
  static const _kBeta = 'el.betaUpdates';
  static const _kExtras = 'el.extras';
  static const _kAccount = 'el.account';
  static const _kRecovery = 'el.recovery';
  static const _kNicknames = 'el.nicknames';
  static const _kEmojis = 'el.subjectEmojis';
  static const _kBells = 'el.bells';
  static const _kLaunches = 'el.launches';
  static const _kFirstRun = 'el.firstRun';
  static const _kAbsences = 'el.absences';
  static const _kGrades = 'el.grades';
  static const _kPhotos = 'el.photos';
  static const _kStudy = 'el.study';
  static const _kStudyLog = 'el.studyLog';
  static const _kTeachers = 'el.teachers';
  static const _kMaterials = 'el.materials';
  static const _kWeekly = 'el.weekly';
  static const _kCountdowns = 'el.countdowns';
  static const _kChanges = 'el.changes';
  static const _maxRecents = 8;

  ThemeMode themeMode = ThemeMode.system;

  /// Nome mostrato nel saluto della home (chiesto al primo avvio).
  String? username;

  /// true dopo il setup iniziale (anche se completato saltando dei passi).
  bool setupDone = false;

  /// Tema scelto nella pagina Temi (vedi ui/theme.dart).
  String themeId = 'auto';

  /// Tema creato dall'utente ("Il tuo tema" nella pagina Temi).
  bool hasCustomTheme = false;
  String customName = 'Il mio tema';
  int customSeed = 0xFF985DE4;
  String customMode = 'system'; // 'system' | 'light' | 'dark'
  bool customOled = false;

  /// Colori esatti scelti nel "Laboratorio colori" (null = automatico).
  int? customBg;
  int? customCard;
  int? customNav;

  /// Compiti, verifiche e promemoria (vedi agenda.dart).
  final List<AgendaItem> agenda = [];

  /// Regole dello zaino ("se c'è chimica porta il camice").
  final List<BagRule> bagRules = [...defaultBagRules];

  /// Cose già messe nello zaino, per data ("2026-11-2" -> elementi spuntati).
  final Map<String, Set<String>> bagChecked = {};

  /// Giorni senza scuola aggiunti a mano (ponti, sospensioni decise dalla scuola).
  final List<Closure> extraClosures = [];

  /// Calendario scolastico con i giorni aggiunti a mano.
  SchoolCalendar get calendar => SchoolCalendar(extraClosures);

  /// Notifiche della prossima lezione: minuti prima (null = spente).
  int? notifyMinutes;

  /// Canale aggiornamenti: false = Stabile, true = Beta (anche le pre-release).
  bool betaUpdates = false;

  /// Opzioni sviluppatore sbloccate (7 tocchi sulla foglia nelle impostazioni).
  bool devMode = false;

  /// Codice dell'account Easy Lesson Cloud (null = nessun account, tutto solo sul dispositivo).
  String? accountCode;

  /// Codice di recupero (se questo dispositivo lo conosce: per il foglio PDF e Google).
  String? recoveryCode;

  /// Il tema personalizzato come AppThemeSpec, null se mai creato.
  AppThemeSpec? get customThemeSpec => hasCustomTheme
      ? buildCustomSpec(
          name: customName,
          seed: Color(customSeed),
          mode: customMode,
          oled: customOled,
          background: customBg == null ? null : Color(customBg!),
          card: customCard == null ? null : Color(customCard!),
          nav: customNav == null ? null : Color(customNav!),
        )
      : null;
  List<String> _serverClassi = [];
  List<String> _serverDocenti = [];
  List<TimeSlot> _serverSlots = [];

  /// Orari delle campanelle scelti a mano (null = quelli della scuola).
  List<(int, int)>? customBells;
  List<TimeSlot>? _customSlots;

  /// Fasce orarie in uso: quelle personalizzate se ci sono, altrimenti della scuola.
  List<TimeSlot> get slots => _customSlots ?? _serverSlots;

  /// Fasce della scuola (server o predefinite), senza le modifiche a mano.
  List<TimeSlot> get schoolSlots => _serverSlots;

  /// Opzioni varie (home, notifiche, sviluppatore...), salvate tutte insieme.
  final Map<String, Object?> _extras = {};

  /// Volte in cui l'app è stata aperta e data della prima apertura.
  int launches = 0;
  DateTime? firstRun;

  // Orario importato da file Excel (ha la precedenza sul server).
  Timetable? _timetable;
  String? excelName;
  DateTime? excelAt;
  String? excelUrl;

  bool get usingExcel => _timetable != null;

  /// Il file Excel importato, per le ricerche "chi c'è dove" (null = si usa il server).
  Timetable? get timetable => _timetable;

  /// Il foglio Excel importato così com'è (per vederlo nelle opzioni sviluppatore).
  List<List<String>>? excelGrid;

  /// Orario calcolato dal file Excel, senza salvarlo (per le esportazioni).
  WeekSchedule? excelWeek(ScheduleRef ref) =>
      _timetable != null && _timetable!.has(ref)
          ? WeekSchedule.fromJson(_timetable!.scheduleJson(ref), prof: ref.prof)
          : null;
  List<String> get classi => _timetable != null ? (_timetable!.classi..sort(compareClassi)) : _serverClassi;
  List<String> get docenti => _timetable?.docenti ?? _serverDocenti;
  List<String> _oreLabels = [];
  DateTime? listsUpdatedAt;
  bool listsLoading = false;
  Object? listsError;
  bool preferGrid = true;

  final Map<String, CachedSchedule> _schedules = {};
  String? _mineKey;

  // ---------------------------------------------------------------- getters

  /// Il mio orario di questa settimana (con la settimana A/B, quello giusto).
  /// Nel weekend vale la settimana che inizia lunedì.
  ScheduleRef? get myRef => myRefOn(DateTime.now());

  /// Il mio orario "A" (quello scelto con "il mio orario").
  ScheduleRef? get myMainRef => _mineKey == null ? null : ScheduleRef.fromKey(_mineKey!);

  /// Il mio orario per il giorno [d]: nelle settimane B quello alternativo, se impostato.
  ScheduleRef? myRefOn(DateTime d) {
    final main = myMainRef;
    final alt = altRef;
    final anchor = DateTime.tryParse(opt('ab.anchor', ''));
    if (main == null || alt == null || anchor == null || cached(alt) == null) return main;
    final day = d.weekday > 5 ? d.add(Duration(days: 8 - d.weekday)) : d;
    return isWeekB(day, anchor) ? alt : main;
  }

  /// Orario della settimana B (null = niente settimane alternate).
  ScheduleRef? get altRef {
    final k = opt('ab.alt', '');
    return k.isEmpty ? null : ScheduleRef.fromKey(k);
  }

  /// Orario salvato da usare per il giorno [d].
  CachedSchedule? myScheduleOn(DateTime d) {
    final r = myRefOn(d);
    return r == null ? null : cached(r);
  }

  /// Assenze, entrate posticipate e uscite anticipate (anche future, se già si sanno).
  final List<AbsenceEntry> absences = [];

  /// Voti.
  final List<Grade> grades = [];

  /// Foto attaccate alle lezioni.
  final List<LessonPhoto> photos = [];

  /// Minuti di studio per materia (timer).
  final Map<String, int> studyMinutes = {};

  /// Minuti di studio per giorno ("2026-11-3" -> minuti), per i grafici.
  final Map<String, int> studyLog = {};

  /// Ricevimento, email e note dei prof (nome come nell'orario -> info).
  final Map<String, TeacherInfo> teachers = {};

  /// Libri e materiale per materia (nome originale -> cose da portare).
  final Map<String, List<String>> materials = {};

  /// Cose da portare ogni settimana in un certo giorno.
  final List<WeeklyItem> weeklyItems = [];

  /// Conti alla rovescia personali (gita, compleanno…).
  final List<CountdownEvent> countdowns = [];

  /// Ultime modifiche trovate nel mio orario (null = nessuna da mostrare).
  List<String>? scheduleChanges;
  DateTime? scheduleChangesAt;

  /// Ore in cui sono a scuola quel giorno (indici), dopo entrate e uscite. null = assente.
  (int, int)? attendedOn(DateTime day, int count) => attendedRange(absences, day, count);

  bool isMine(ScheduleRef ref) => ref.key == _mineKey;

  CachedSchedule? cached(ScheduleRef ref) => _schedules[ref.key];

  List<CachedSchedule> get favorites {
    final l = _schedules.values.where((s) => s.favorite).toList()
      ..sort((a, b) {
        if (isMine(a.ref) != isMine(b.ref)) return isMine(a.ref) ? -1 : 1;
        return a.ref.displayName.compareTo(b.ref.displayName);
      });
    return l;
  }

  List<CachedSchedule> get recents {
    final l = _schedules.values.where((s) => !s.favorite).toList()
      ..sort((a, b) => b.lastOpened.compareTo(a.lastOpened));
    return l.take(_maxRecents).toList();
  }

  // ---------------------------------------------------------------- load/save

  void _load() {
    themeId = _prefs.getString(_kThemeId) ??
        switch (_prefs.getString(_kTheme)) {
          'light' => 'light',
          'dark' => 'dark',
          _ => 'auto',
        };
    themeMode = ThemeMode.values.firstWhere(
      (m) => m.name == _prefs.getString(_kTheme),
      orElse: () => ThemeMode.system,
    );
    final u = _prefs.getString(_kUsername);
    username = (u != null && u.trim().isNotEmpty) ? u.trim() : null;
    setupDone = _prefs.getBool(_kSetupDone) ?? false;
    devMode = _prefs.getBool(_kDevMode) ?? false;
    final code = _prefs.getString(_kAccount);
    accountCode = code == null || code.trim().isEmpty ? null : code;
    final rec = _prefs.getString(_kRecovery);
    recoveryCode = rec == null || rec.trim().isEmpty ? null : rec;
    try {
      final rules = _prefs.getString(_kBagRules);
      if (rules != null) {
        bagRules
          ..clear()
          ..addAll((jsonDecode(rules) as List).map(BagRule.fromJson).whereType<BagRule>());
      }
      final checked = jsonDecode(_prefs.getString(_kBagChecked) ?? '{}') as Map;
      bagChecked
        ..clear()
        ..addAll({for (final e in checked.entries) '${e.key}': {for (final x in e.value as List) '$x'}});
      extraClosures
        ..clear()
        ..addAll((jsonDecode(_prefs.getString(_kClosures) ?? '[]') as List).map(Closure.fromJson).whereType<Closure>());
      // Il canale Beta si sceglie solo dalle opzioni sviluppatore.
      betaUpdates = devMode && (_prefs.getBool(_kBeta) ?? false);
      final n = _prefs.getInt(_kNotify);
      notifyMinutes = n == null || n < 0 ? null : n;
    } catch (e) {
      AppLog.w('prefs', 'Zaino/calendario non leggibili: $e');
    }
    try {
      agenda
        ..clear()
        ..addAll((jsonDecode(_prefs.getString(_kAgenda) ?? '[]') as List)
            .map(AgendaItem.fromJson)
            .whereType<AgendaItem>());
    } catch (e) {
      AppLog.w('agenda', 'Agenda non leggibile: $e');
    }
    final custom = _prefs.getString(_kCustomTheme);
    if (custom != null) {
      try {
        final m = jsonDecode(custom) as Map<String, dynamic>;
        customName = m['name'] as String? ?? customName;
        customSeed = m['seed'] as int? ?? customSeed;
        customMode = m['mode'] as String? ?? customMode;
        customOled = m['oled'] == true;
        customBg = m['bg'] as int?;
        customCard = m['card'] as int?;
        customNav = m['nav'] as int?;
        hasCustomTheme = true;
      } catch (_) {/* tema salvato non più leggibile */}
    }
    _serverClassi = _prefs.getStringList(_kClassi) ?? [];
    _serverDocenti = _prefs.getStringList(_kDocenti) ?? [];
    Map<String, String> readMap(String key) {
      try {
        return Map<String, String>.from(jsonDecode(_prefs.getString(key) ?? '{}') as Map);
      } catch (_) {
        return {};
      }
    }

    subjectOverrides
      ..clear()
      ..addAll(readMap(_kSubjects));
    nicknames
      ..clear()
      ..addAll(readMap(_kNicknames));
    subjectEmojis
      ..clear()
      ..addAll(readMap(_kEmojis));
    teacherSubjectOverrides
      ..clear()
      ..addAll(readMap(_kTeacherSubjects));
    final xlsx = _prefs.getString(_kXlsx);
    if (xlsx != null) {
      try {
        final m = jsonDecode(xlsx) as Map<String, dynamic>;
        final grid = [
          for (final r in m['grid'] as List) [for (final c in r as List) c.toString()],
        ];
        _timetable = Timetable.parse(grid);
        excelGrid = grid;
        excelName = m['name'] as String?;
        excelAt = DateTime.tryParse('${m['at']}');
        excelUrl = m['url'] as String?;
      } catch (e, st) {
        AppLog.e('excel', e, st); // file salvato non più leggibile
      }
    }
    _oreLabels = _prefs.getStringList(_kOre) ?? [];
    _serverSlots = slotsFrom(_oreLabels);
    try {
      final b = _prefs.getString(_kBells);
      customBells = b == null
          ? null
          : [for (final x in jsonDecode(b) as List) ((x as List)[0] as int, x[1] as int)];
    } catch (_) {
      customBells = null;
    }
    _customSlots = customBells == null || customBells!.isEmpty ? null : TimeSlot.parseAll(bellLabels(customBells!));
    try {
      _extras
        ..clear()
        ..addAll(Map<String, Object?>.from(jsonDecode(_prefs.getString(_kExtras) ?? '{}') as Map));
    } catch (_) {/* opzioni non leggibili: si usano quelle predefinite */}
    List<T> readList<T>(String key, T? Function(dynamic) f) {
      try {
        return (jsonDecode(_prefs.getString(key) ?? '[]') as List).map(f).whereType<T>().toList();
      } catch (e) {
        AppLog.w('prefs', '$key non leggibile: $e');
        return [];
      }
    }

    absences
      ..clear()
      ..addAll(readList(_kAbsences, AbsenceEntry.fromJson));
    grades
      ..clear()
      ..addAll(readList(_kGrades, Grade.fromJson));
    photos
      ..clear()
      ..addAll(readList(_kPhotos, LessonPhoto.fromJson));
    try {
      studyMinutes
        ..clear()
        ..addAll(Map<String, int>.from(jsonDecode(_prefs.getString(_kStudy) ?? '{}') as Map));
    } catch (_) {
      studyMinutes.clear();
    }
    Map<String, dynamic> readMapJson(String key) {
      try {
        return Map<String, dynamic>.from(jsonDecode(_prefs.getString(key) ?? '{}') as Map);
      } catch (_) {
        return {};
      }
    }

    studyLog
      ..clear()
      ..addAll({for (final e in readMapJson(_kStudyLog).entries) e.key: (e.value as num).toInt()});
    teachers
      ..clear()
      ..addAll({for (final e in readMapJson(_kTeachers).entries) e.key: TeacherInfo.fromJson(e.value)});
    materials
      ..clear()
      ..addAll({
        for (final e in readMapJson(_kMaterials).entries) e.key: [for (final x in e.value as List) '$x'],
      });
    weeklyItems
      ..clear()
      ..addAll(readList(_kWeekly, WeeklyItem.fromJson));
    countdowns
      ..clear()
      ..addAll(readList(_kCountdowns, CountdownEvent.fromJson));
    final ch = readMapJson(_kChanges);
    scheduleChanges = ch['list'] is List ? [for (final x in ch['list'] as List) '$x'] : null;
    scheduleChangesAt = DateTime.tryParse('${ch['at']}');
    appEnglish = opt('lang', 'it') == 'en';
    launches = _prefs.getInt(_kLaunches) ?? 0;
    firstRun = DateTime.tryParse(_prefs.getString(_kFirstRun) ?? '');
    listsUpdatedAt = DateTime.tryParse(_prefs.getString(_kListsAt) ?? '');
    _mineKey = _prefs.getString(_kMine);
    preferGrid = _prefs.getBool(_kGrid) ?? true;
    final raw = _prefs.getString(_kSchedules);
    if (raw != null) {
      try {
        for (final e in (jsonDecode(raw) as List)) {
          final s = CachedSchedule.fromJson(e);
          if (s != null) _schedules[s.ref.key] = s;
        }
      } catch (_) {/* cache corrotta: si riparte da zero */}
    }
  }

  Future<void> _saveSchedules() =>
      _prefs.setString(_kSchedules, jsonEncode(_schedules.values.map((s) => s.toJson()).toList()));

  // ---------------------------------------------------------------- actions

  Future<void> refreshLists({bool onlyIfStale = false}) async {
    if (listsLoading) return;
    final updated = usingExcel ? excelAt : listsUpdatedAt;
    final fresh = updated != null &&
        DateTime.now().difference(updated) < const Duration(hours: 12) &&
        classi.isNotEmpty;
    if (onlyIfStale && fresh) return;
    if (usingExcel && excelUrl == null) return; // file importato a mano: niente da scaricare
    listsLoading = true;
    listsError = null;
    notifyListeners();
    if (usingExcel) {
      try {
        await _downloadExcel(excelUrl!);
      } catch (e) {
        listsError = e;
        AppLog.e('excel', e);
      }
      listsLoading = false;
      notifyListeners();
      return;
    }
    try {
      final (c, d) = await (_api.lista('studs'), _api.lista('profs')).wait;
      _serverClassi = c..sort(compareClassi);
      _serverDocenti = d..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      listsUpdatedAt = DateTime.now();
      await _prefs.setStringList(_kClassi, _serverClassi);
      await _prefs.setStringList(_kDocenti, _serverDocenti);
      await _prefs.setString(_kListsAt, listsUpdatedAt!.toIso8601String());
    } catch (e) {
      listsError = e is ParallelWaitError ? ApiException('Connessione non disponibile') : e;
      AppLog.w('server', 'Elenchi non aggiornati: $e');
    }
    try {
      final ore = await _api.ore();
      if (ore.isNotEmpty) {
        _oreLabels = ore;
        _serverSlots = slotsFrom(ore);
        await _prefs.setStringList(_kOre, ore);
      }
    } catch (_) {/* si usano le fasce salvate */}
    listsLoading = false;
    notifyListeners();
  }

  /// Scarica l'orario e lo salva in locale. Lancia un'eccezione se non riesce.
  Future<void> fetchSchedule(ScheduleRef ref) async {
    final Map<String, dynamic> raw;
    AppLog.i('orario', 'Carico ${ref.key} da ${_timetable != null ? 'Excel' : 'server'}');
    if (_timetable != null) {
      if (!_timetable!.has(ref)) throw ApiException('${ref.displayName} non è nel file Excel importato');
      raw = _timetable!.scheduleJson(ref);
    } else {
      raw = await _api.orario(ref, ore: _oreLabels.isNotEmpty ? _oreLabels.length : defaultOreLabels.length);
    }
    if (WeekSchedule.fromJson(raw, prof: ref.prof).days.isEmpty) {
      throw ApiException('Orario non trovato');
    }
    final old = _schedules[ref.key];
    final now = DateTime.now();
    // Il mio orario è cambiato? Si confronta con quello salvato.
    if (old != null && ref == myMainRef) {
      final diff = scheduleDiff(old.week, WeekSchedule.fromJson(raw, prof: ref.prof));
      if (diff.isNotEmpty) {
        scheduleChanges = diff;
        scheduleChangesAt = now;
        AppLog.i('orario', 'Il mio orario è cambiato: ${diff.length} differenze');
        await _prefs.setString(_kChanges, jsonEncode({'list': diff, 'at': now.toIso8601String()}));
      }
    }
    _schedules[ref.key] = CachedSchedule(
      ref: ref,
      raw: raw,
      updatedAt: now,
      lastOpened: now,
      favorite: old?.favorite ?? isMine(ref),
    );
    _prune();
    await _saveSchedules();
    notifyListeners();
  }

  /// Importa il file Excel dell'orario: da qui in poi tutto viene calcolato
  /// sul dispositivo, senza bisogno di internet.
  Future<void> importExcelBytes(List<int> bytes, {String? name, String? url}) async {
    // Fuori dal thread dell'interfaccia (su web compute gira qui, ma i limiti di readXlsx valgono comunque).
    final grid = await compute(_parseXlsx, bytes);
    final tt = Timetable.parse(grid); // lancia FormatException se il formato non va
    // Si salvano solo le celle utili (niente righe vuote in fondo).
    final trimmed = [
      for (final r in grid) [...r],
    ];
    while (trimmed.isNotEmpty && trimmed.last.every((c) => c.isEmpty)) {
      trimmed.removeLast();
    }
    _timetable = tt;
    excelGrid = trimmed;
    AppLog.i('excel', 'Importato ${name ?? 'file'}: ${trimmed.length} righe, ${tt.classi.length} classi, ${tt.docenti.length} docenti');
    listsError = null;
    excelName = name ?? excelName ?? 'orario.xlsx';
    excelAt = DateTime.now();
    excelUrl = url;
    await _prefs.setString(
      _kXlsx,
      jsonEncode({'name': excelName, 'at': excelAt!.toIso8601String(), 'url': url, 'grid': trimmed}),
    );
    // Ricalcola gli orari già salvati con il nuovo file.
    final now = DateTime.now();
    for (final s in _schedules.values.toList()) {
      if (!tt.has(s.ref)) continue;
      _schedules[s.ref.key] = CachedSchedule(
        ref: s.ref,
        raw: tt.scheduleJson(s.ref),
        updatedAt: now,
        lastOpened: s.lastOpened,
        favorite: s.favorite,
      );
    }
    await _saveSchedules();
    notifyListeners();
  }

  /// Scarica il file Excel da un link (es. quello sul sito della scuola).
  Future<void> importExcelUrl(String url) => _downloadExcel(url.trim());

  Future<void> _downloadExcel(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) throw ApiException('Link non valido');
    final http.Response res;
    try {
      res = await http.get(uri).timeout(const Duration(seconds: 40));
    } catch (_) {
      throw ApiException(kIsWeb
          ? 'Download non riuscito: dal browser molti siti bloccano i download. '
              'Scarica il file e usa "Importa file Excel".'
          : 'Download non riuscito: controlla la connessione e il link');
    }
    if (res.statusCode != 200) throw ApiException('Il sito ha risposto con errore ${res.statusCode}');
    final name = uri.pathSegments.isNotEmpty ? Uri.decodeComponent(uri.pathSegments.last) : null;
    await importExcelBytes(res.bodyBytes, name: name, url: url);
  }

  /// Torna a usare il server di Easy Lesson.
  Future<void> removeExcel() async {
    _timetable = null;
    excelName = null;
    excelAt = null;
    excelUrl = null;
    excelGrid = null;
    AppLog.i('excel', 'File rimosso, si torna al server');
    await _prefs.remove(_kXlsx);
    notifyListeners();
    unawaited(refreshLists());
  }

  void touch(ScheduleRef ref) {
    final s = _schedules[ref.key];
    if (s == null) return;
    s.lastOpened = DateTime.now();
    _saveSchedules();
    _countView(ref);
    notifyListeners();
  }

  Future<void> toggleFavorite(ScheduleRef ref) async {
    final s = _schedules[ref.key];
    if (s == null) return;
    s.favorite = !s.favorite;
    if (!s.favorite && isMine(ref)) await setMine(null);
    await _saveSchedules();
    notifyListeners();
  }

  Future<void> setMine(ScheduleRef? ref) async {
    _mineKey = ref?.key;
    if (ref == null) {
      await _prefs.remove(_kMine);
    } else {
      await _prefs.setString(_kMine, ref.key);
      final s = _schedules[ref.key];
      if (s != null && !s.favorite) {
        s.favorite = true;
        await _saveSchedules();
      }
    }
    notifyListeners();
  }

  Future<void> remove(ScheduleRef ref) async {
    _schedules.remove(ref.key);
    if (isMine(ref)) {
      _mineKey = null;
      await _prefs.remove(_kMine);
    }
    await _saveSchedules();
    notifyListeners();
  }

  // ------------------------------------------------------- materie e codici

  Map<String, List<String>> get teachersByCode => _timetable?.teachersByCode ?? const {};

  /// Cambia la materia di un codice (vuoto = torna al predefinito).
  Future<void> setCodeSubject(String code, String? subject) async {
    final v = subject?.trim() ?? '';
    if (v.isEmpty || v == subjectNames[code]) {
      subjectOverrides.remove(code);
    } else {
      subjectOverrides[code] = v;
    }
    await _prefs.setString(_kSubjects, jsonEncode(subjectOverrides));
    await _afterSubjectsChanged();
  }

  /// Materia specifica per un docente (vuoto = usa quella del codice).
  Future<void> setTeacherSubject(String teacher, String? subject) async {
    final v = subject?.trim() ?? '';
    if (v.isEmpty) {
      teacherSubjectOverrides.remove(teacher);
    } else {
      teacherSubjectOverrides[teacher] = v;
    }
    await _prefs.setString(_kTeacherSubjects, jsonEncode(teacherSubjectOverrides));
    await _afterSubjectsChanged();
  }

  Future<void> resetSubjects() async {
    subjectOverrides.clear();
    teacherSubjectOverrides.clear();
    await _prefs.remove(_kSubjects);
    await _prefs.remove(_kTeacherSubjects);
    await _afterSubjectsChanged();
  }

  /// Gli orari calcolati dal file Excel contengono il nome della materia: si ricalcolano.
  /// Anche gli orari del server vengono ricostruiti, perché i nomi delle materie
  /// si calcolano quando l'orario viene letto.
  Future<void> _afterSubjectsChanged() async {
    final tt = _timetable;
    for (final s in _schedules.values.toList()) {
      _schedules[s.ref.key] = CachedSchedule(
        ref: s.ref,
        raw: (tt != null && tt.has(s.ref)) ? tt.scheduleJson(s.ref) : s.raw,
        updatedAt: s.updatedAt,
        lastOpened: s.lastOpened,
        favorite: s.favorite,
      );
    }
    await _saveSchedules();
    notifyListeners();
  }

  Future<void> clearAll() async {
    _schedules.clear();
    _mineKey = null;
    await _prefs.remove(_kMine);
    await _saveSchedules();
    notifyListeners();
  }

  Future<void> setThemeId(String id) async {
    if (id != themeId) unawaited(bump('themeChanges'));
    themeId = id;
    AppLog.i('tema', 'Tema: $id');
    notifyListeners();
    await _prefs.setString(_kThemeId, id);
  }

  /// Salva il nome utente (null/vuoto = nessun nome).
  Future<void> setUsername(String? name) async {
    final v = name?.trim() ?? '';
    username = v.isEmpty ? null : v;
    notifyListeners();
    if (username == null) {
      await _prefs.remove(_kUsername);
    } else {
      await _prefs.setString(_kUsername, username!);
    }
  }

  /// Opzioni sviluppatore: si rifà il setup iniziale (i dati restano).
  Future<void> restartSetup() async {
    setupDone = false;
    notifyListeners();
    await _prefs.setBool(_kSetupDone, false);
  }

  /// Il setup iniziale e' finito: alla prossima apertura si va alla home.
  Future<void> completeSetup() async {
    setupDone = true;
    notifyListeners();
    await _prefs.setBool(_kSetupDone, true);
  }

  /// Crea o aggiorna "Il tuo tema" e lo attiva subito.
  Future<void> setCustomTheme({
    String? name,
    int? seed,
    String? mode,
    bool? oled,
  }) async {
    customName = name ?? customName;
    customSeed = seed ?? customSeed;
    customMode = mode ?? customMode;
    customOled = oled ?? customOled;
    hasCustomTheme = true;
    themeId = customThemeId;
    notifyListeners();
    await _saveCustomTheme();
  }

  /// Colori esatti dal Laboratorio colori (null = automatico).
  Future<void> setCustomColors({required int? background, required int? card, required int? nav}) async {
    customBg = background;
    customCard = card;
    customNav = nav;
    hasCustomTheme = true;
    themeId = customThemeId;
    notifyListeners();
    await _saveCustomTheme();
  }

  Future<void> _saveCustomTheme() async {
    AppLog.i('tema', 'Tema personalizzato: seed #${customSeed.toRadixString(16)} · $customMode'
        '${customBg != null ? ' · sfondo #${customBg!.toRadixString(16)}' : ''}');
    await _prefs.setString(
      _kCustomTheme,
      jsonEncode({
        'name': customName,
        'seed': customSeed,
        'mode': customMode,
        'oled': customOled,
        'bg': customBg,
        'card': customCard,
        'nav': customNav,
      }),
    );
    await _prefs.setString(_kThemeId, themeId);
  }

  // ---------------------------------------------------------------- agenda

  /// Elementi da [from] in poi (solo date), ordinati per data.
  List<AgendaItem> agendaFrom(DateTime from, {bool includeDone = false, int? days}) {
    final start = dateOnly(from);
    final end = days == null ? null : start.add(Duration(days: days));
    return agenda
        .where((a) =>
            !a.date.isBefore(start) && (end == null || a.date.isBefore(end)) && (includeDone || !a.done))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  /// Elementi di una materia in un certo giorno.
  List<AgendaItem> agendaOn(DateTime date, String subject) =>
      agenda.where((a) => !a.done && a.date == dateOnly(date) && a.sameSubject(subject)).toList();

  Future<void> addAgenda({
    required DateTime date,
    required String kind,
    required String subject,
    required String text,
  }) async {
    agenda.add(AgendaItem(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      date: dateOnly(date),
      kind: kind,
      subject: subject.trim(),
      text: text.trim(),
    ));
    AppLog.i('agenda', 'Aggiunto $kind · $subject');
    _extras['stat.agendaAdded'] = stat('agendaAdded') + 1;
    await _saveAgenda();
    await _prefs.setString(_kExtras, jsonEncode(_extras));
  }

  Future<void> toggleAgendaDone(AgendaItem item) async {
    item.done = !item.done;
    await _saveAgenda();
  }

  Future<void> removeAgenda(AgendaItem item) async {
    agenda.removeWhere((a) => a.id == item.id);
    await _saveAgenda();
  }

  Future<void> _saveAgenda() async {
    // Le cose fatte da più di 60 giorni si tolgono da sole.
    final old = DateTime.now().subtract(const Duration(days: 60));
    agenda.removeWhere((a) => a.done && a.date.isBefore(old));
    notifyListeners();
    await _prefs.setString(_kAgenda, jsonEncode(agenda.map((a) => a.toJson()).toList()));
  }

  // ---------------------------------------------------------------- zaino e calendario

  static String dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

  /// Prossimo giorno di scuola dopo [from] (escluso), secondo il calendario e
  /// i giorni dell'orario. null se non ce n'è uno nei prossimi 120 giorni.
  DateTime? nextSchoolDay(DateTime from, {int daysPerWeek = 5}) {
    final cal = calendar;
    for (var off = 1; off <= 120; off++) {
      final d = DateTime(from.year, from.month, from.day + off);
      if (cal.isSchoolDay(d, daysPerWeek: daysPerWeek)) return d;
    }
    return null;
  }

  Future<void> setBagRules(List<BagRule> rules) async {
    bagRules
      ..clear()
      ..addAll(rules);
    notifyListeners();
    await _prefs.setString(_kBagRules, jsonEncode(bagRules.map((r) => r.toJson()).toList()));
  }

  Future<void> toggleBagItem(DateTime day, String item) async {
    final k = dayKey(day);
    final set = bagChecked[k] ??= {};
    if (!set.remove(item)) {
      set.add(item);
      _extras['stat.bagTicks'] = stat('bagTicks') + 1;
      unawaited(_prefs.setString(_kExtras, jsonEncode(_extras)));
    }
    // Si tengono solo gli ultimi giorni.
    if (bagChecked.length > 10) {
      final keys = bagChecked.keys.toList()..sort();
      for (final old in keys.take(bagChecked.length - 10)) {
        bagChecked.remove(old);
      }
    }
    notifyListeners();
    await _prefs.setString(_kBagChecked, jsonEncode({for (final e in bagChecked.entries) e.key: e.value.toList()}));
  }

  Future<void> addClosure(Closure c) async {
    extraClosures.add(c);
    await _saveClosures();
  }

  Future<void> removeClosure(Closure c) async {
    extraClosures.remove(c);
    await _saveClosures();
  }

  Future<void> _saveClosures() async {
    notifyListeners();
    await _prefs.setString(_kClosures, jsonEncode(extraClosures.map((c) => c.toJson()).toList()));
  }

  // ---------------------------------------------------------------- opzioni varie

  /// Legge un'opzione (es. opt('home.agenda', true)).
  T opt<T>(String key, T fallback) {
    final v = _extras[key];
    return v is T ? v : fallback;
  }

  /// Cambia un'opzione (null = torna al valore predefinito).
  Future<void> setOpt(String key, Object? value) async {
    if (value == null) {
      _extras.remove(key);
    } else {
      _extras[key] = value;
    }
    AppLog.i('opzioni', '$key = $value');
    notifyListeners();
    await _prefs.setString(_kExtras, jsonEncode(_extras));
  }

  void _countLaunch() {
    launches++;
    firstRun ??= DateTime.now();
    _prefs.setInt(_kLaunches, launches);
    _prefs.setString(_kFirstRun, firstRun!.toIso8601String());
  }

  // ---------------------------------------------------------------- soprannomi ed emoji

  /// Soprannome e emoji per un nome dell'orario (vuoto = toglie).
  Future<void> setNickname(String original, {String? name, String? emoji}) async {
    final k = original.trim();
    if (k.isEmpty) return;
    if (name != null) {
      if (name.trim().isEmpty || name.trim() == k) {
        nicknames.remove(k);
      } else {
        nicknames[k] = name.trim();
      }
    }
    if (emoji != null) {
      if (emoji.trim().isEmpty) {
        subjectEmojis.remove(k);
      } else {
        subjectEmojis[k] = emoji.trim();
      }
    }
    AppLog.i('soprannomi', '$k → ${nicknames[k] ?? k} ${subjectEmojis[k] ?? ''}');
    await _prefs.setString(_kNicknames, jsonEncode(nicknames));
    await _prefs.setString(_kEmojis, jsonEncode(subjectEmojis));
    await _afterSubjectsChanged();
  }

  Future<void> resetNicknames() async {
    nicknames.clear();
    subjectEmojis.clear();
    await _prefs.remove(_kNicknames);
    await _prefs.remove(_kEmojis);
    await _afterSubjectsChanged();
  }

  // ---------------------------------------------------------------- campanelle

  /// Orari delle campanelle scelti a mano: (inizio, fine) in minuti. null = quelli della scuola.
  Future<void> setCustomBells(List<(int, int)>? bells) async {
    customBells = bells == null || bells.isEmpty ? null : [...bells];
    _customSlots = customBells == null ? null : TimeSlot.parseAll(bellLabels(customBells!));
    AppLog.i('campanelle', customBells == null ? 'Orari della scuola' : bellLabels(customBells!).join(', '));
    if (customBells == null) {
      await _prefs.remove(_kBells);
    } else {
      await _prefs.setString(_kBells, jsonEncode([for (final b in customBells!) [b.$1, b.$2]]));
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------- memoria (opzioni sviluppatore)

  /// Tutto quello che l'app ha salvato sul dispositivo (chiave -> valore).
  Map<String, Object?> rawPrefs() => {
        for (final k in _prefs.getKeys().toList()..sort()) k: _prefs.get(k),
      };

  Future<void> removePref(String key) async {
    await _prefs.remove(key);
    AppLog.w('memoria', 'Chiave cancellata: $key');
    reload();
  }

  /// Copia di sicurezza (JSON). [sections] = solo quelle parti (vedi [backupSections]), null = tutto.
  /// Il codice dell'account non finisce mai nel backup.
  String backup({Set<String>? sections}) => jsonEncode({
        'easyLessonBackup': 2,
        'at': DateTime.now().toIso8601String(),
        if (sections != null) 'sections': (sections.toList()..sort()),
        'prefs': {
          for (final e in rawPrefs().entries)
            if (e.key.startsWith('el.') &&
                e.key != _kAccount &&
                e.key != _kRecovery &&
                (sections == null || sections.contains(backupSectionOf(e.key))))
              e.key: e.value,
        },
      });

  /// Le chiavi della memoria da mettere nel backup online (solo le sezioni scelte, mai i codici).
  Map<String, Object?> backupPrefs(Set<String> sections) => {
        for (final e in rawPrefs().entries)
          if (e.key.startsWith('el.') &&
              e.key != _kAccount &&
              e.key != _kRecovery &&
              sections.contains(backupSectionOf(e.key)))
            e.key: e.value,
      };

  /// Chiavi che un backup non tocca mai: i codici dell'account e le scelte di questo dispositivo.
  static const _neverRestored = {_kAccount, _kRecovery, _kDevMode, _kBeta};

  /// Opzioni (dentro el.extras) che nessun backup può portare né cambiare (sicurezza EL-01):
  /// stato di questo dispositivo (cloud.*, dev.* — compreso l'indirizzo del server —, missioni…)
  /// e i regali che può dare solo il server. Restano sempre quelle di qui.
  static bool isProtectedOption(String k) => isLocalOnlyOption(k) || k == 'stat.xpBonus' || k == 'stat.coinBonus';

  /// Ripristina una copia fatta con [backup]. Lancia FormatException se non è valida.
  /// Prima controlla e prepara tutto il documento, poi scrive: un backup rovinato non lascia
  /// la memoria a metà. Le opzioni protette ([isProtectedOption]) restano quelle di qui.
  Future<int> restore(String json) async {
    final Map<String, dynamic> m;
    try {
      m = Map<String, dynamic>.from(jsonDecode(json.trim()) as Map);
    } catch (_) {
      throw const FormatException('Non è un backup di Easy Lesson');
    }
    final prefs = m['prefs'];
    if (m['easyLessonBackup'] == null || prefs is! Map) throw const FormatException('Non è un backup di Easy Lesson');
    final ready = <String, Object>{};
    var skipped = 0;
    for (final e in prefs.entries) {
      final k = '${e.key}';
      final v = e.value;
      if (!k.startsWith('el.') || _neverRestored.contains(k)) {
        skipped++;
        continue;
      }
      final Object? clean = switch (k) {
        _kExtras => _restoredExtras(v),
        _kPhotos => _restoredPhotos(v),
        _ => switch (v) {
            bool() || int() || double() || String() => v,
            List() => [for (final x in v) '$x'],
            _ => null,
          },
      };
      if (clean == null) {
        skipped++;
        continue;
      }
      ready[k] = clean;
    }
    for (final e in ready.entries) {
      final v = e.value;
      if (v is bool) {
        await _prefs.setBool(e.key, v);
      } else if (v is int) {
        await _prefs.setInt(e.key, v);
      } else if (v is double) {
        await _prefs.setDouble(e.key, v);
      } else if (v is String) {
        await _prefs.setString(e.key, v);
      } else if (v is List<String>) {
        await _prefs.setStringList(e.key, v);
      }
    }
    final n = ready.length;
    AppLog.i('memoria', 'Backup ripristinato: $n chiavi${skipped > 0 ? ' ($skipped ignorate)' : ''}');
    reload();
    return n;
  }

  /// Le opzioni del backup senza quelle protette, più quelle protette di questo dispositivo.
  String? _restoredExtras(Object? v) {
    final Map<String, Object?> incoming;
    try {
      incoming = Map<String, Object?>.from(jsonDecode(v as String) as Map);
    } catch (_) {
      return null;
    }
    final dropped = incoming.keys.where(isProtectedOption).toList();
    if (dropped.isNotEmpty) AppLog.w('memoria', 'Backup: opzioni protette ignorate: ${dropped.join(', ')}');
    return jsonEncode({
      for (final e in incoming.entries)
        if (!isProtectedOption(e.key)) e.key: e.value,
      for (final e in _extras.entries)
        if (isProtectedOption(e.key)) e.key: e.value,
    });
  }

  /// Foto: solo voci ben fatte e senza percorsi strani (il controllo vero della cartella è in
  /// LessonPhotos, prima di aprire o cancellare un file).
  String? _restoredPhotos(Object? v) {
    try {
      final list = jsonDecode(v as String) as List;
      return jsonEncode([
        for (final j in list)
          if (LessonPhoto.fromJson(j) case final p? when !hasPathTraversal(p.path)) p.toJson(),
      ]);
    } catch (_) {
      return null;
    }
  }

  /// Rilegge tutto dalla memoria del dispositivo.
  void reload() {
    _schedules.clear();
    _timetable = null;
    excelGrid = null;
    excelName = null;
    excelAt = null;
    excelUrl = null;
    _load();
    notifyListeners();
  }

  // ---------------------------------------------------------------- assenze, voti, foto, studio

  String _newId() => '${DateTime.now().microsecondsSinceEpoch}';

  Future<void> addAbsence({required DateTime date, required String kind, int hour = 1, String note = ''}) async {
    absences.add(AbsenceEntry(id: _newId(), date: dateOnly(date), kind: kind, hour: hour, note: note.trim()));
    absences.sort((a, b) => b.date.compareTo(a.date));
    AppLog.i('assenze', '$kind ${dayKey(date)} ora $hour');
    await _saveList(_kAbsences, absences.map((a) => a.toJson()));
  }

  Future<void> removeAbsence(AbsenceEntry a) async {
    absences.removeWhere((x) => x.id == a.id);
    await _saveList(_kAbsences, absences.map((a) => a.toJson()));
  }

  Future<void> addGrade({
    required DateTime date,
    required String subject,
    required double value,
    double weight = 1,
    String kind = 'scritto',
    String note = '',
  }) async {
    grades.add(Grade(
      id: _newId(),
      date: dateOnly(date),
      subject: subject.trim(),
      value: value,
      weight: weight,
      kind: kind,
      note: note.trim(),
    ));
    grades.sort((a, b) => b.date.compareTo(a.date));
    AppLog.i('voti', '$subject ${Grade.format(value)}');
    _extras['stat.gradesAdded'] = stat('gradesAdded') + 1;
    await _saveList(_kGrades, grades.map((g) => g.toJson()));
    await _prefs.setString(_kExtras, jsonEncode(_extras));
  }

  Future<void> removeGrade(Grade g) async {
    grades.removeWhere((x) => x.id == g.id);
    await _saveList(_kGrades, grades.map((g) => g.toJson()));
  }

  Future<void> addPhoto({required DateTime date, required String subject, required String path}) async {
    photos.add(LessonPhoto(id: _newId(), date: dateOnly(date), subject: subject, path: path));
    _extras['stat.photosAdded'] = stat('photosAdded') + 1;
    unawaited(_prefs.setString(_kExtras, jsonEncode(_extras)));
    photos.sort((a, b) => b.date.compareTo(a.date));
    await _saveList(_kPhotos, photos.map((p) => p.toJson()));
  }

  Future<void> removePhoto(LessonPhoto p) async {
    photos.removeWhere((x) => x.id == p.id);
    await _saveList(_kPhotos, photos.map((p) => p.toJson()));
  }

  Future<void> addStudy(String subject, int minutes) async {
    if (minutes <= 0) return;
    final k = subject.trim().isEmpty ? 'Studio libero' : subject.trim();
    studyMinutes[k] = (studyMinutes[k] ?? 0) + minutes;
    final day = isoDay(DateTime.now());
    studyLog[day] = (studyLog[day] ?? 0) + minutes;
    await _prefs.setString(_kStudyLog, jsonEncode(studyLog));
    AppLog.i('studio', '$k +$minutes min');
    notifyListeners();
    await _prefs.setString(_kStudy, jsonEncode(studyMinutes));
  }

  /// Riscarica il mio orario se è vecchio (per accorgersi dei cambiamenti). true = cambiato.
  Future<bool> refreshMine({Duration olderThan = const Duration(hours: 6)}) async {
    final ref = myMainRef;
    final c = ref == null ? null : cached(ref);
    if (ref == null || c == null || DateTime.now().difference(c.updatedAt) < olderThan) return false;
    final before = scheduleChangesAt;
    try {
      await fetchSchedule(ref);
    } catch (e) {
      AppLog.w('orario', 'Aggiornamento automatico non riuscito: $e');
      return false;
    }
    return scheduleChangesAt != before;
  }

  Future<void> dismissScheduleChanges() async {
    scheduleChanges = null;
    notifyListeners();
    await _prefs.remove(_kChanges);
  }

  Future<void> setTeacherInfo(String name, TeacherInfo info) async {
    if (info.isEmpty) {
      teachers.remove(name);
    } else {
      teachers[name] = info;
    }
    notifyListeners();
    await _prefs.setString(_kTeachers, jsonEncode({for (final e in teachers.entries) e.key: e.value.toJson()}));
  }

  Future<void> setMaterials(String subject, List<String> items) async {
    final clean = items.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (clean.isEmpty) {
      materials.remove(subject);
    } else {
      materials[subject] = clean;
    }
    notifyListeners();
    await _prefs.setString(_kMaterials, jsonEncode(materials));
  }

  Future<void> addWeeklyItem(int weekday, String item) async {
    if (item.trim().isEmpty) return;
    weeklyItems.add(WeeklyItem(weekday, item.trim()));
    await _saveList(_kWeekly, weeklyItems.map((w) => w.toJson()));
  }

  Future<void> removeWeeklyItem(WeeklyItem w) async {
    weeklyItems.remove(w);
    await _saveList(_kWeekly, weeklyItems.map((w) => w.toJson()));
  }

  Future<void> addCountdown(String name, DateTime date, String emoji) async {
    countdowns.add(CountdownEvent(id: _newId(), name: name.trim(), date: dateOnly(date), emoji: emoji));
    countdowns.sort((a, b) => a.date.compareTo(b.date));
    await _saveList(_kCountdowns, countdowns.map((c) => c.toJson()));
  }

  Future<void> removeCountdown(CountdownEvent c) async {
    countdowns.removeWhere((x) => x.id == c.id);
    await _saveList(_kCountdowns, countdowns.map((c) => c.toJson()));
  }

  /// Opzioni sviluppatore: finge che l'orario sia cambiato (per vedere avviso e notifica).
  void simulateScheduleChanges() {
    scheduleChanges = ['Martedì 3ª ora: Fisica → Chimica (prova)', 'Venerdì 5ª ora: libera → Inglese (prova)'];
    scheduleChangesAt = DateTime.now();
    notifyListeners();
  }

  // ---------------------------------------------------------------- progressi, livelli, account

  /// Nomi di tutte le opzioni salvate (menu sviluppatore nascosto).
  List<String> rawExtrasKeys() => _extras.keys.toList();

  /// Contatore dei progressi (es. stat('views')).
  int stat(String key) => opt('stat.$key', 0);

  /// Aumenta un contatore.
  Future<void> bump(String key, [int by = 1]) => setOpt('stat.$key', stat(key) + by);

  /// Alza un contatore solo se [value] è più alto.
  Future<void> statMax(String key, int value) async {
    if (value > stat(key)) await setOpt('stat.$key', value);
  }

  /// Contatori per nome (es. quante volte hai aperto l'orario di ogni prof). Restano sul dispositivo.
  Map<String, int> statMap(String key) {
    final m = opt<Map>('statmap.$key', const {});
    return {for (final e in m.entries) '${e.key}': (e.value is int ? e.value as int : 0)};
  }

  void _countView(ScheduleRef ref) {
    final kind = ref.prof ? 'prof' : 'class';
    final m = statMap(kind);
    m[ref.name] = (m[ref.name] ?? 0) + 1;
    _extras['statmap.$kind'] = m;
    _extras['stat.views'] = stat('views') + 1;
    _extras['stat.${kind}Views'] = stat('${kind}Views') + 1;
    _extras['stat.${kind}Distinct'] = m.length;
    final top = m.values.fold(0, (a, b) => a > b ? a : b);
    if (top > stat('${kind}Top')) _extras['stat.${kind}Top'] = top;
    unawaited(_prefs.setString(_kExtras, jsonEncode(_extras)));
  }

  /// Da chiamare all'avvio e quando si torna nell'app: giorni attivi, serie, ore di lezione.
  Future<void> markActive([DateTime? at]) async {
    final now = at ?? DateTime.now();
    // isoDay (2026-11-02), non AppStore.dayKey (2026-11-2): deve combaciare con nextStreak.
    final today = isoDay(now);
    final last = opt<String?>('stat.lastDay', null);
    _extras['stat.sessions'] = stat('sessions') + 1;
    if (last != today) {
      final streak = nextStreak(last, stat('streak'), now);
      _extras['stat.days'] = stat('days') + 1;
      _extras['stat.streak'] = streak;
      if (streak > stat('bestStreak')) _extras['stat.bestStreak'] = streak;
      _extras['stat.lastDay'] = today;
    }
    if (now.weekday == DateTime.sunday) _extras['stat.sundays'] = stat('sundays') + (last != today ? 1 : 0);
    final minutes = now.hour * 60 + now.minute;
    if (minutes >= 4 * 60 && minutes < 6 * 60 + 30) _extras['egg.early'] = true;
    // In quale ora di lezione siamo? Si contano le ore diverse di oggi.
    if (now.weekday <= DateTime.saturday) {
      final i = slots.indexWhere((t) => t.start != null && t.end != null && minutes >= t.start! && minutes < t.end!);
      if (i >= 0) {
        final prev = opt<String>('stat.hoursToday', '');
        final parts = prev.split('|');
        final hours = parts.length == 2 && parts.first == today
            ? parts[1].split(',').where((x) => x.isNotEmpty).toSet()
            : <String>{};
        hours.add('$i');
        _extras['stat.hoursToday'] = '$today|${hours.join(',')}';
        if (hours.length > stat('hoursInDay')) _extras['stat.hoursInDay'] = hours.length;
        // Ultima ora di lezione di oggi (secondo il mio orario), una volta al giorno.
        final day = myScheduleOn(now)?.week.days;
        if (day != null && now.weekday - 1 < day.length) {
          final lessons = day[now.weekday - 1].lessons;
          final lastLesson = lessons.lastIndexWhere((l) => !l.isEmpty);
          if (lastLesson >= 0 && i == lastLesson && opt<String?>('stat.lastHourDay', null) != today) {
            _extras['stat.lastHourDay'] = today;
            _extras['stat.lastHourOpens'] = stat('lastHourOpens') + 1;
          }
        }
      }
      // Ricreazione.
      if (calendar.isSchoolDay(now, daysPerWeek: 6) && breaksOf(slots).any((b) => minutes >= b.start && minutes < b.end)) {
        _extras['stat.breakOpens'] = stat('breakOpens') + 1;
      }
      // Nell'ora prima della prima campanella, una volta al giorno.
      final first = slots.isEmpty ? null : slots.first.start;
      if (first != null &&
          minutes >= first - 60 &&
          minutes < first &&
          calendar.isSchoolDay(now, daysPerWeek: 6) &&
          opt<String?>('stat.beforeBellDay', null) != today) {
        _extras['stat.beforeBellDay'] = today;
        _extras['stat.beforeBell'] = stat('beforeBell') + 1;
      }
    }
    notifyListeners();
    await _prefs.setString(_kExtras, jsonEncode(_extras));
  }

  /// Progressi da sincronizzare (solo contatori numerici e obiettivi).
  ProgressData get progressData => ProgressData(
        achievements: opt('ach.done', '').split(',').where((x) => x.isNotEmpty).toSet(),
        counters: {
          for (final e in _extras.entries)
            // La serie di oggi non si unisce (dipende dal giorno): si sincronizza solo la migliore.
            if (e.key.startsWith('stat.') && e.key != 'stat.streak' && e.value is int) e.key.substring(5): e.value as int,
        },
      );

  /// Unisce i progressi arrivati dal server (o da un altro telefono) con quelli di qui.
  /// [resetAt]: se è più nuovo dell'ultimo azzeramento già applicato, prima si cancellano obiettivi, contatori,
  /// segni delle sorprese e oggetti usati del negozio (azzeramento deciso dalla moderazione sul server).
  Future<bool> applyProgress(ProgressData remote, {int resetAt = 0}) async {
    if (resetAt > opt('cloud.resetSeen', 0)) {
      _extras.removeWhere((k, _) =>
          k.startsWith('ach.') || k.startsWith('stat.') || k.startsWith('statmap.') || k.startsWith('egg.') || k.startsWith('shop.eq.'));
      _extras['cloud.resetSeen'] = resetAt;
      _extras['ach.done'] = (remote.achievements.toList()..sort()).join(',');
      for (final e in remote.counters.entries) {
        _extras['stat.${e.key}'] = e.value;
      }
      AppLog.w('cloud', 'Progressi azzerati dalla moderazione');
      notifyListeners();
      await _prefs.setString(_kExtras, jsonEncode(_extras));
      return true;
    }
    final local = progressData;
    final merged = local.merge(remote);
    if (merged.sameAs(local)) return false;
    _extras['ach.done'] = (merged.achievements.toList()..sort()).join(',');
    for (final e in merged.counters.entries) {
      _extras['stat.${e.key}'] = e.value;
    }
    AppLog.i('cloud', 'Progressi uniti: ${merged.achievements.length} obiettivi');
    notifyListeners();
    await _prefs.setString(_kExtras, jsonEncode(_extras));
    return true;
  }

  Future<void> setRecoveryCode(String? code) async {
    recoveryCode = code == null || code.trim().isEmpty ? null : code.trim();
    notifyListeners();
    if (recoveryCode == null) {
      await _prefs.remove(_kRecovery);
    } else {
      await _prefs.setString(_kRecovery, recoveryCode!);
    }
  }

  Future<void> setAccountCode(String? code) async {
    accountCode = code == null || code.trim().isEmpty ? null : code.trim();
    if (accountCode != null) {
      _extras['cloud.since'] ??= DateTime.now().toIso8601String();
    } else {
      _extras.remove('cloud.since');
      _extras.remove('cloud.verifiedAt');
    }
    AppLog.i('cloud', accountCode == null ? 'Account scollegato' : 'Account collegato');
    notifyListeners();
    await _prefs.setString(_kExtras, jsonEncode(_extras));
    if (accountCode == null) {
      await _prefs.remove(_kAccount);
    } else {
      await _prefs.setString(_kAccount, accountCode!);
    }
  }

  /// Scrive una chiave grezza della memoria (menu sviluppatore nascosto). null = cancella.
  Future<void> setRawPref(String key, Object? value) async {
    if (value == null) {
      await _prefs.remove(key);
    } else if (value is bool) {
      await _prefs.setBool(key, value);
    } else if (value is int) {
      await _prefs.setInt(key, value);
    } else if (value is double) {
      await _prefs.setDouble(key, value);
    } else if (value is List) {
      await _prefs.setStringList(key, [for (final x in value) '$x']);
    } else {
      await _prefs.setString(key, '$value');
    }
    AppLog.w('memoria', 'Chiave scritta a mano: $key');
    reload();
  }

  /// Rimette le opzioni come appena installata (non tocca orari, agenda, voti, tema, soprannomi).
  Future<void> resetOptions() async {
    const keep = ['ach.', 'egg.', 'ab.', 'credits.', 'stat.', 'statmap.', 'cloud.', 'mis.', 'event.', 'ann.', 'social.', 'shop.'];
    _extras.removeWhere((k, _) => !keep.any(k.startsWith));
    appEnglish = false;
    await setNotifyMinutes(null);
    AppLog.i('opzioni', 'Opzioni ripristinate');
    notifyListeners();
    await _prefs.setString(_kExtras, jsonEncode(_extras));
  }

  Future<void> setLanguage(String lang) async {
    appEnglish = lang == 'en';
    await setOpt('lang', lang == 'it' ? null : lang);
  }

  Future<void> _saveList(String key, Iterable<Map<String, dynamic>> items) async {
    notifyListeners();
    await _prefs.setString(key, jsonEncode(items.toList()));
  }

  Future<void> setBetaUpdates(bool v) async {
    betaUpdates = v;
    AppLog.i('aggiornamenti', 'Canale: ${v ? 'Beta' : 'Stabile'}');
    notifyListeners();
    await _prefs.setBool(_kBeta, v);
  }

  Future<void> setNotifyMinutes(int? minutes) async {
    notifyMinutes = minutes;
    notifyListeners();
    await _prefs.setInt(_kNotify, minutes ?? -1);
  }

  Future<void> setDevMode(bool v) async {
    devMode = v;
    if (!v && betaUpdates) await setBetaUpdates(false);
    AppLog.i('dev', v ? 'Opzioni sviluppatore attivate' : 'Opzioni sviluppatore disattivate');
    notifyListeners();
    await _prefs.setBool(_kDevMode, v);
  }

  Future<void> setThemeMode(ThemeMode m) async {
    themeMode = m;
    notifyListeners();
    await _prefs.setString(_kTheme, m.name);
  }

  Future<void> setPreferGrid(bool v) async {
    preferGrid = v;
    notifyListeners();
    await _prefs.setBool(_kGrid, v);
  }

  void _prune() {
    final extra = _schedules.values.where((s) => !s.favorite).toList()
      ..sort((a, b) => b.lastOpened.compareTo(a.lastOpened));
    for (final s in extra.skip(_maxRecents)) {
      _schedules.remove(s.ref.key);
    }
  }
}

/// Ordina "1a, 1b, 2a, 10c" in modo naturale.
int compareClassi(String a, String b) {
  int lead(String s) => int.tryParse(RegExp(r'^\d+').firstMatch(s.trim())?.group(0) ?? '') ?? 99;
  final c = lead(a).compareTo(lead(b));
  return c != 0 ? c : a.toLowerCase().compareTo(b.toLowerCase());
}

/// Rende disponibile lo store a tutto l'albero dei widget.
class StoreScope extends InheritedNotifier<AppStore> {
  const StoreScope({super.key, required AppStore store, required super.child})
      : super(notifier: store);

  /// Si registra per i cambiamenti (usare in build).
  static AppStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StoreScope>()!.notifier!;

  /// Solo lettura, senza ricostruzioni (usare nei callback).
  static AppStore read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<StoreScope>()!.notifier!;
}

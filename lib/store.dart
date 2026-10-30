import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'models.dart';
import 'timetable.dart';
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

/// Stato dell'app + persistenza locale (localStorage sul web,
/// SharedPreferences su Android e Windows).
class AppStore extends ChangeNotifier {
  AppStore._(this._prefs, this._api);

  static Future<AppStore> create({EasyLessonApi? api}) async {
    final prefs = await SharedPreferences.getInstance();
    final store = AppStore._(prefs, api ?? EasyLessonApi());
    store._load();
    unawaited(store.refreshLists(onlyIfStale: true));
    return store;
  }

  final SharedPreferences _prefs;
  final EasyLessonApi _api;

  static const _kTheme = 'el.theme';
  static const _kThemeId = 'el.themeId';
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
  static const _maxRecents = 8;

  ThemeMode themeMode = ThemeMode.system;

  /// Tema scelto nella pagina Temi (vedi ui/theme.dart).
  String themeId = 'auto';
  List<String> _serverClassi = [];
  List<String> _serverDocenti = [];
  List<TimeSlot> slots = [];

  // Orario importato da file Excel (ha la precedenza sul server).
  Timetable? _timetable;
  String? excelName;
  DateTime? excelAt;
  String? excelUrl;

  bool get usingExcel => _timetable != null;
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

  ScheduleRef? get myRef => _mineKey == null ? null : ScheduleRef.fromKey(_mineKey!);

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
    teacherSubjectOverrides
      ..clear()
      ..addAll(readMap(_kTeacherSubjects));
    final xlsx = _prefs.getString(_kXlsx);
    if (xlsx != null) {
      try {
        final m = jsonDecode(xlsx) as Map<String, dynamic>;
        _timetable = Timetable.parse([
          for (final r in m['grid'] as List) [for (final c in r as List) c.toString()],
        ]);
        excelName = m['name'] as String?;
        excelAt = DateTime.tryParse('${m['at']}');
        excelUrl = m['url'] as String?;
      } catch (_) {/* file salvato non più leggibile */}
    }
    _oreLabels = _prefs.getStringList(_kOre) ?? [];
    slots = slotsFrom(_oreLabels);
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
    }
    try {
      final ore = await _api.ore();
      if (ore.isNotEmpty) {
        _oreLabels = ore;
        slots = slotsFrom(ore);
        await _prefs.setStringList(_kOre, ore);
      }
    } catch (_) {/* si usano le fasce salvate */}
    listsLoading = false;
    notifyListeners();
  }

  /// Scarica l'orario e lo salva in locale. Lancia un'eccezione se non riesce.
  Future<void> fetchSchedule(ScheduleRef ref) async {
    final Map<String, dynamic> raw;
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
    final grid = readXlsx(bytes);
    final tt = Timetable.parse(grid); // lancia FormatException se il formato non va
    // Si salvano solo le celle utili (niente righe vuote in fondo).
    final trimmed = [
      for (final r in grid) [...r],
    ];
    while (trimmed.isNotEmpty && trimmed.last.every((c) => c.isEmpty)) {
      trimmed.removeLast();
    }
    _timetable = tt;
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
    await _prefs.remove(_kXlsx);
    notifyListeners();
    unawaited(refreshLists());
  }

  void touch(ScheduleRef ref) {
    final s = _schedules[ref.key];
    if (s == null) return;
    s.lastOpened = DateTime.now();
    _saveSchedules();
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
    themeId = id;
    notifyListeners();
    await _prefs.setString(_kThemeId, id);
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

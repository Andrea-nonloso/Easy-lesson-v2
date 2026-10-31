import 'models.dart';

/// Sezioni del file Excel della scuola.
enum Section { docenti, sostegno, laboratori }

class TimetableEntry {
  const TimetableEntry(this.section, this.name, this.day, this.hour, this.value);

  final Section section;

  /// Prima colonna: docente ("A026 Rossi"), docente di sostegno o laboratorio.
  final String name;
  final int day;
  final int hour;

  /// Contenuto della cella: di solito la classe ("3B BS").
  final String value;
}

/// Orario completo letto dal file Excel della scuola.
///
/// Formato atteso (come "orarioLezioni.xlsx"):
/// - una riga con i giorni (Lunedì … Venerdì, celle unite) e sotto una riga
///   con le ore in numeri romani (I … VII);
/// - una riga per docente: nome in colonna A, classe nelle celle giorno/ora;
/// - una riga titolo con "sostegno" apre la sezione dei docenti di sostegno;
/// - una riga titolo con "laboratori" apre la sezione dei laboratori.
///
/// Dart puro, riusabile da un tool a riga di comando.
class Timetable {
  Timetable._(this.entries, this.days, this.hours) {
    for (final e in entries) {
      if (!isClassName(e.value)) continue;
      final k = classKey(e.value);
      // Si preferisce la grafia usata nella sezione docenti ("5A Inf" e non "5A INF").
      if (e.section == Section.docenti) {
        _classNames.putIfAbsent(k, () => e.value);
      }
      (_byClass[k] ??= []).add(e);
    }
    for (final e in entries) {
      if (isClassName(e.value)) _classNames.putIfAbsent(classKey(e.value), () => e.value);
      if (e.section != Section.laboratori) (_byTeacher[e.name] ??= []).add(e);
    }
  }

  final List<TimetableEntry> entries;
  final int days;
  final int hours;

  final Map<String, String> _classNames = {};
  final Map<String, List<TimetableEntry>> _byClass = {};
  final Map<String, List<TimetableEntry>> _byTeacher = {};

  static const _roman = {'I': 0, 'II': 1, 'III': 2, 'IV': 3, 'V': 4, 'VI': 5, 'VII': 6, 'VIII': 7, 'IX': 8, 'X': 9};
  static const _dayKeys = ['lunedi', 'martedi', 'mercoledi', 'giovedi', 'venerdi', 'sabato'];

  static String _norm(String s) => s.replaceAll(' ', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

  static String classKey(String s) => _norm(s).toLowerCase();

  static bool isClassName(String s) => RegExp(r'^\d{1,2}\s?[a-z]{1,2}(\s+\S+)?$').hasMatch(classKey(s));

  static int? _dayIndex(String s) {
    final t = _norm(s).toLowerCase().replaceAll('ì', 'i');
    if (t.length < 3) return null;
    for (var i = 0; i < _dayKeys.length; i++) {
      if (_dayKeys[i].startsWith(t) || t == _dayKeys[i]) return i;
    }
    return null;
  }

  factory Timetable.parse(List<List<String>> grid) {
    String cell(List<String> row, int c) => c < row.length ? row[c] : '';

    // Riga dei giorni
    var header = -1;
    for (var i = 0; i < grid.length && header < 0; i++) {
      if (grid[i].where((v) => _dayIndex(v) != null).length >= 2) header = i;
    }
    if (header < 0 || header + 1 >= grid.length) {
      throw const FormatException('Non trovo la riga dei giorni (Lunedì, Martedì…) nel file Excel');
    }
    final dayRow = grid[header];
    final romanRow = grid[header + 1];

    // Colonna -> (giorno, ora)
    final colDay = <int, int>{};
    final colHour = <int, int>{};
    int? current;
    final width = dayRow.length > romanRow.length ? dayRow.length : romanRow.length;
    for (var c = 0; c < width; c++) {
      final d = _dayIndex(cell(dayRow, c));
      if (d != null) current = d;
      final h = _roman[_norm(cell(romanRow, c)).toUpperCase()];
      if (current != null && h != null) {
        colDay[c] = current;
        colHour[c] = h;
      }
    }
    if (colDay.isEmpty) {
      throw const FormatException('Non trovo le ore (I, II, III…) sotto i giorni nel file Excel');
    }

    final entries = <TimetableEntry>[];
    var section = Section.docenti;
    for (final row in grid.skip(header + 2)) {
      final name = row.isEmpty ? '' : _norm(row[0]);
      if (name.isEmpty) {
        final txt = row.join(' ').toLowerCase();
        if (txt.contains('sostegno')) {
          section = Section.sostegno;
        } else if (txt.contains('laborator')) {
          section = Section.laboratori;
        }
        continue;
      }
      for (final c in colDay.keys) {
        final v = _norm(cell(row, c));
        if (v.isEmpty || _roman.containsKey(v.toUpperCase())) continue;
        entries.add(TimetableEntry(section, name, colDay[c]!, colHour[c]!, v));
      }
    }
    if (entries.isEmpty) throw const FormatException('Il file Excel non contiene lezioni');

    final days = colDay.values.reduce((a, b) => a > b ? a : b) + 1;
    final hours = colHour.values.reduce((a, b) => a > b ? a : b) + 1;
    return Timetable._(entries, days, hours);
  }

  // ------------------------------------------------------------------ elenchi

  List<String> get classi => _classNames.values.toList();

  /// Docenti (sezione docenti e sostegno), ordinati per cognome.
  List<String> get docenti => _byTeacher.keys.toList()
    ..sort((a, b) {
      final c = teacherLabel(a).toLowerCase().compareTo(teacherLabel(b).toLowerCase());
      return c != 0 ? c : a.compareTo(b);
    });

  /// Codici materia presenti nel file, con i rispettivi docenti.
  Map<String, List<String>> get teachersByCode {
    final out = <String, List<String>>{};
    for (final t in docenti) {
      final c = teacherCode(t);
      if (c != null) (out[c] ??= []).add(t);
    }
    return out;
  }

  // ------------------------------------------------------------------ chi c'è dove

  late final Map<int, List<TimetableEntry>> _at = () {
    final m = <int, List<TimetableEntry>>{};
    for (final e in entries) {
      (m[e.day * 100 + e.hour] ??= []).add(e);
    }
    return m;
  }();

  List<TimetableEntry> _entriesAt(int day, int hour) => _at[day * 100 + hour] ?? const [];

  /// Nome della classe come scritto nel file ("3B BS"), o il valore così com'è.
  String className(String value) =>
      value.toUpperCase() == 'POT' ? 'Potenziamento' : (_classNames[classKey(value)] ?? value);

  /// Laboratori presenti nel file, in ordine alfabetico.
  late final List<String> labs = {
    for (final e in entries)
      if (e.section == Section.laboratori) e.name,
  }.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

  /// Classi in un laboratorio a quell'ora (vuoto = libero).
  List<String> labUse(String lab, int day, int hour) => [
        for (final e in _entriesAt(day, hour))
          if (e.section == Section.laboratori && e.name == lab) className(e.value),
      ];

  /// Dove si trova un docente a quell'ora: classi e laboratori (vuoto = non è in classe).
  ({List<String> classes, List<String> labs}) teacherAt(String teacher, int day, int hour) {
    final here = _entriesAt(day, hour).where((e) => e.name == teacher && e.section != Section.laboratori);
    final classes = <String>[];
    final keys = <String>{};
    for (final e in here) {
      final c = className(e.value);
      if (!classes.contains(c)) classes.add(c);
      keys.add(classKey(e.value));
    }
    final labs = <String>{
      for (final e in _entriesAt(day, hour))
        if (e.section == Section.laboratori && keys.contains(classKey(e.value))) e.name,
    }.toList();
    return (classes: classes, labs: labs);
  }

  /// Ore (0 = prima) in cui il docente ha lezione in quel giorno.
  List<int> teacherHours(String teacher, int day) {
    final hs = <int>{
      for (final e in _byTeacher[teacher] ?? const <TimetableEntry>[])
        if (e.day == day) e.hour,
    }.toList()
      ..sort();
    return hs;
  }

  bool has(ScheduleRef ref) => ref.prof ? _byTeacher.containsKey(ref.name) : _byClass.containsKey(classKey(ref.name));

  // ------------------------------------------------------------------ orari

  /// Orario nello stesso formato JSON delle cloud function di Easy Lesson
  /// (giorno0..N con ora1..ora10, lab1..lab10, sostegno, oreGiorno).
  Map<String, dynamic> scheduleJson(ScheduleRef ref) =>
      ref.prof ? _teacherJson(ref.name) : _classJson(ref.name);

  Map<String, dynamic> _classJson(String name) {
    final list = _byClass[classKey(name)] ?? const [];
    final out = <String, dynamic>{};
    for (var d = 0; d < days; d++) {
      final day = <String, dynamic>{};
      final sost = <String>[];
      var last = -1;
      for (var h = 0; h < hours; h++) {
        final here = list.where((e) => e.day == d && e.hour == h);
        final teachers = [for (final e in here) if (e.section == Section.docenti) e.name];
        final labs = [for (final e in here) if (e.section == Section.laboratori) e.name];
        final support = [for (final e in here) if (e.section == Section.sostegno) teacherLabel(e.name)];
        if (teachers.isNotEmpty || labs.isNotEmpty || support.isNotEmpty) last = h;
        day['ora${h + 1}'] = teachers.isEmpty ? '' : '${_subjectOf(teachers)}\n${teachers.map(teacherLabel).join(' · ')}';
        day['lab${h + 1}'] = labs.join(', ');
        sost.add(support.join(', '));
      }
      day['sostegno'] = sost;
      day['oreGiorno'] = last + 1;
      out['giorno$d'] = day;
    }
    return out;
  }

  Map<String, dynamic> _teacherJson(String name) {
    final list = _byTeacher[name] ?? const [];
    final out = <String, dynamic>{};
    for (var d = 0; d < days; d++) {
      final day = <String, dynamic>{};
      var last = -1;
      var count = 0;
      for (var h = 0; h < hours; h++) {
        final here = list.where((e) => e.day == d && e.hour == h).toList();
        final classes = <String>[];
        var support = false;
        for (final e in here) {
          final v = e.value.toUpperCase() == 'POT'
              ? 'Potenziamento'
              : (_classNames[classKey(e.value)] ?? e.value);
          if (!classes.contains(v)) classes.add(v);
          if (e.section == Section.sostegno) support = true;
        }
        final keys = here.map((e) => classKey(e.value)).toSet();
        final labs = <String>{
          for (final k in keys)
            for (final e in _byClass[k] ?? const <TimetableEntry>[])
              if (e.section == Section.laboratori && e.day == d && e.hour == h) e.name,
        };
        if (classes.isNotEmpty) {
          last = h;
          count++;
        }
        day['ora${h + 1}'] = classes.isEmpty ? '' : '${classes.join(' + ')}${support ? '\nSostegno' : ''}';
        day['lab${h + 1}'] = labs.join(', ');
      }
      day['sostegno'] = const <String>[];
      day['oreGiorno'] = last + 1;
      day['nOreProf'] = count;
      out['giorno$d'] = day;
    }
    return out;
  }

  /// Materia di un'ora: quella del primo docente teorico (i codici B sono ITP di laboratorio).
  static String _subjectOf(List<String> teachers) {
    final main = teachers.firstWhere(
      (t) => !(teacherCode(t)?.startsWith('B') ?? false),
      orElse: () => teachers.first,
    );
    return teacherSubject(main) ?? 'Lezione';
  }
}

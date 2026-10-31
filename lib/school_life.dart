import 'agenda.dart' show dateOnly;
import 'models.dart';

/// Vita scolastica: assenze/entrate/uscite, voti, foto delle lezioni, studio.
/// Dart puro (testabile senza Flutter).

/// Settimane di lezione in un anno (per il monte ore annuale).
const schoolWeeks = 33;

/// Limite di assenze per la validità dell'anno (25% del monte ore).
const absenceLimit = 0.25;

String _iso(DateTime d) => '${d.year}-${d.month}-${d.day}';

DateTime _parse(String s) {
  final v = s.split('-').map(int.parse).toList();
  return DateTime(v[0], v[1], v[2]);
}

/// Un'assenza, un'entrata posticipata o un'uscita anticipata.
class AbsenceEntry {
  AbsenceEntry({required this.id, required this.date, required this.kind, this.hour = 1, this.note = ''});

  final String id;
  final DateTime date;

  /// 'assenza' (tutto il giorno), 'entrata' (entro alla [hour]ª ora), 'uscita' (esco dopo la [hour]ª ora).
  final String kind;
  final int hour;
  final String note;

  static const kinds = ['assenza', 'entrata', 'uscita'];

  static String emojiOf(String k) => switch (k) {
        'entrata' => '⏰',
        'uscita' => '🚪',
        _ => '🤒',
      };

  String get emoji => emojiOf(kind);

  String get label => switch (kind) {
        'entrata' => 'Entrata alla $hourª ora',
        'uscita' => 'Uscita dopo la $hourª ora',
        _ => 'Assenza',
      };

  /// Indici delle ore perse (0 = prima ora) in un giorno con [count] ore.
  List<int> lostHours(int count) => switch (kind) {
        'entrata' => [for (var i = 0; i < count && i < hour - 1; i++) i],
        'uscita' => [for (var i = hour; i < count; i++) i],
        _ => [for (var i = 0; i < count; i++) i],
      };

  Map<String, dynamic> toJson() => {'id': id, 'date': _iso(date), 'kind': kind, 'hour': hour, 'note': note};

  static AbsenceEntry? fromJson(dynamic j) {
    try {
      final m = Map<String, dynamic>.from(j as Map);
      return AbsenceEntry(
        id: '${m['id']}',
        date: _parse(m['date'] as String),
        kind: kinds.contains(m['kind']) ? m['kind'] as String : 'assenza',
        hour: (m['hour'] as num?)?.toInt() ?? 1,
        note: m['note'] as String? ?? '',
      );
    } catch (_) {
      return null;
    }
  }
}

/// Ore in cui si è a scuola quel giorno (indici, compresi), dopo entrate/uscite.
/// null = assente tutto il giorno.
(int, int)? attendedRange(List<AbsenceEntry> entries, DateTime day, int count) {
  var from = 0;
  var to = count - 1;
  for (final e in entries) {
    if (e.date != dateOnly(day)) continue;
    switch (e.kind) {
      case 'assenza':
        return null;
      case 'entrata':
        if (e.hour - 1 > from) from = e.hour - 1;
      case 'uscita':
        if (e.hour - 1 < to) to = e.hour - 1;
    }
  }
  return from > to ? null : (from, to);
}

/// Ore di lezione a settimana (ore non vuote).
int weeklyHours(WeekSchedule week) =>
    week.days.fold(0, (n, d) => n + d.lessons.where((l) => !l.isEmpty).length);

/// Riepilogo delle assenze: ore perse in totale e per materia.
class AbsenceStats {
  AbsenceStats({required this.lost, required this.bySubject, required this.yearHours, required this.days});

  final int lost;
  final Map<String, int> bySubject;
  final int yearHours;
  final int days;

  int get limitHours => (yearHours * absenceLimit).floor();
  double get ratio => yearHours == 0 ? 0 : lost / yearHours;
  int get left => limitHours - lost;

  /// Monte ore annuale di una materia.
  static int subjectYearHours(WeekSchedule week, String subject) =>
      week.days.fold(0, (n, d) => n + d.lessons.where((l) => !l.isEmpty && l.title == subject).length) *
      schoolWeeks;
}

/// Calcola le ore perse fino a [until] (compreso) con l'orario [week].
AbsenceStats absenceStats(List<AbsenceEntry> entries, WeekSchedule week, DateTime until) {
  var lost = 0;
  final by = <String, int>{};
  final days = <DateTime>{};
  for (final e in entries) {
    if (e.date.isAfter(dateOnly(until))) continue;
    final wd = e.date.weekday - 1;
    if (wd >= week.days.length) continue;
    final lessons = week.days[wd].lessons;
    for (final i in e.lostHours(lessons.length)) {
      if (i >= lessons.length || lessons[i].isEmpty) continue;
      lost++;
      by[lessons[i].title] = (by[lessons[i].title] ?? 0) + 1;
    }
    if (e.kind == 'assenza') days.add(e.date);
  }
  return AbsenceStats(lost: lost, bySubject: by, yearHours: weeklyHours(week) * schoolWeeks, days: days.length);
}

// ---------------------------------------------------------------------------
// Voti

class Grade {
  Grade({
    required this.id,
    required this.date,
    required this.subject,
    required this.value,
    this.weight = 1,
    this.kind = 'scritto',
    this.note = '',
  });

  final String id;
  final DateTime date;
  final String subject;
  final double value;
  final double weight;

  /// 'scritto', 'orale', 'pratico'.
  final String kind;
  final String note;

  static const kinds = ['scritto', 'orale', 'pratico'];

  /// "7½", "6+", "8-" come sul registro.
  static String format(double v) {
    final whole = v.floor();
    final frac = v - whole;
    if (frac.abs() < 0.01) return '$whole';
    if ((frac - 0.25).abs() < 0.01) return '$whole+';
    if ((frac - 0.5).abs() < 0.01) return '$whole½';
    if ((frac - 0.75).abs() < 0.01) return '${whole + 1}-';
    return v.toStringAsFixed(2);
  }

  /// Legge "7", "7.5", "7,5", "7½", "6+", "8-", "6/7".
  static double? parse(String s) {
    var t = s.trim().replaceAll(',', '.').replaceAll(' ', '');
    if (t.isEmpty) return null;
    final slash = RegExp(r'^(\d+)/(\d+)$').firstMatch(t);
    if (slash != null) return (int.parse(slash.group(1)!) + int.parse(slash.group(2)!)) / 2;
    double extra = 0;
    if (t.endsWith('½')) {
      extra = 0.5;
      t = t.substring(0, t.length - 1);
    } else if (t.endsWith('+')) {
      extra = 0.25;
      t = t.substring(0, t.length - 1);
    } else if (t.endsWith('-')) {
      extra = -0.25;
      t = t.substring(0, t.length - 1);
    }
    final v = double.tryParse(t);
    if (v == null) return null;
    final r = v + extra;
    return r < 0 || r > 10 ? null : r;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': _iso(date),
        'subject': subject,
        'value': value,
        'weight': weight,
        'kind': kind,
        'note': note,
      };

  static Grade? fromJson(dynamic j) {
    try {
      final m = Map<String, dynamic>.from(j as Map);
      return Grade(
        id: '${m['id']}',
        date: _parse(m['date'] as String),
        subject: m['subject'] as String? ?? '',
        value: (m['value'] as num).toDouble(),
        weight: (m['weight'] as num?)?.toDouble() ?? 1,
        kind: m['kind'] as String? ?? 'scritto',
        note: m['note'] as String? ?? '',
      );
    } catch (_) {
      return null;
    }
  }
}

/// Media ponderata (null se non ci sono voti).
double? average(Iterable<Grade> grades) {
  var sum = 0.0;
  var w = 0.0;
  for (final g in grades) {
    sum += g.value * g.weight;
    w += g.weight;
  }
  return w == 0 ? null : sum / w;
}

/// Voto che serve nella prossima prova (peso [weight]) per arrivare a [target] di media.
/// null se non ci sono voti; può essere > 10 (impossibile) o < 0 (già fatto).
double? neededFor(Iterable<Grade> grades, double target, {double weight = 1}) {
  var sum = 0.0;
  var w = 0.0;
  for (final g in grades) {
    sum += g.value * g.weight;
    w += g.weight;
  }
  if (w == 0) return target;
  return (target * (w + weight) - sum) / weight;
}

// ---------------------------------------------------------------------------
// Foto delle lezioni

class LessonPhoto {
  LessonPhoto({required this.id, required this.date, required this.subject, required this.path});

  final String id;
  final DateTime date;
  final String subject;

  /// File nella cartella dell'app.
  final String path;

  Map<String, dynamic> toJson() => {'id': id, 'date': _iso(date), 'subject': subject, 'path': path};

  static LessonPhoto? fromJson(dynamic j) {
    try {
      final m = Map<String, dynamic>.from(j as Map);
      return LessonPhoto(
        id: '${m['id']}',
        date: _parse(m['date'] as String),
        subject: m['subject'] as String? ?? '',
        path: m['path'] as String,
      );
    } catch (_) {
      return null;
    }
  }
}

// ---------------------------------------------------------------------------
// Settimana A/B

/// true se la settimana di [d] è una settimana "B" (alternate, a partire da [anchorB]).
bool isWeekB(DateTime d, DateTime anchorB) {
  DateTime monday(DateTime x) => DateTime.utc(x.year, x.month, x.day).subtract(Duration(days: x.weekday - 1));
  final weeks = monday(d).difference(monday(anchorB)).inDays ~/ 7;
  return weeks.isEven;
}

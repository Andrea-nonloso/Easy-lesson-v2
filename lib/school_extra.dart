import 'agenda.dart';
import 'models.dart';
import 'school_life.dart';
import 'i18n.dart';

/// 2.6: orario cambiato, piano di studio, periodi e pagella, crediti, prof,
/// materiale e promemoria settimanali, conti alla rovescia. Dart puro (testato).

String _iso(DateTime d) => '${d.year}-${d.month}-${d.day}';

DateTime _parse(String s) {
  final v = s.split('-').map(int.parse).toList();
  return DateTime(v[0], v[1], v[2]);
}

// ---------------------------------------------------------------------------
// Orario cambiato

/// Differenze tra due orari ("Martedì 3ª ora: Fisica → Chimica"). Vuota se uguali.
List<String> scheduleDiff(WeekSchedule before, WeekSchedule after) {
  final out = <String>[];
  final days = before.days.length > after.days.length ? before.days.length : after.days.length;
  String what(Lesson? l) {
    if (l == null || l.isEmpty) return 'libera';
    return l.lab.isEmpty ? l.rawTitle : '${l.rawTitle} (${l.lab})';
  }

  for (var d = 0; d < days; d++) {
    final a = d < before.days.length ? before.days[d].lessons : const <Lesson>[];
    final b = d < after.days.length ? after.days[d].lessons : const <Lesson>[];
    final n = a.length > b.length ? a.length : b.length;
    for (var h = 0; h < n; h++) {
      final x = h < a.length ? a[h] : null;
      final y = h < b.length ? b[h] : null;
      final wx = what(x), wy = what(y);
      if (wx == wy) {
        // Stessa materia ma docente diverso.
        final tx = x == null || x.rawLines.length < 2 ? '' : x.rawLines[1];
        final ty = y == null || y.rawLines.length < 2 ? '' : y.rawLines[1];
        if (tx != ty && tx.isNotEmpty && ty.isNotEmpty) {
          out.add('${d < dayNames.length ? dayNames[d] : '${tr('Giorno', 'Day')} ${d + 1}'} ${tr('${h + 1}ª ora', 'period ${h + 1}')} ($wx): $tx → $ty');
        }
        continue;
      }
      out.add('${d < dayNames.length ? dayNames[d] : '${tr('Giorno', 'Day')} ${d + 1}'} ${tr('${h + 1}ª ora', 'period ${h + 1}')}: $wx → $wy');
    }
  }
  return out;
}

// ---------------------------------------------------------------------------
// Piano di studio

/// Un pezzo di ripasso: la verifica, il giorno, quale parte (1 di 3...).
class StudyStep {
  const StudyStep(this.item, this.day, this.part, this.of);
  final AgendaItem item;
  final DateTime day;
  final int part;
  final int of;

  String get label => '${item.subject.isEmpty ? item.label : item.subject} '
      '(${item.label.toLowerCase()} ${friendlyDate(item.date, day).toLowerCase()}) · $part/$of';
}

/// Divide il ripasso di verifiche e interrogazioni sui [days] giorni prima (da oggi in poi).
List<StudyStep> studyPlan(List<AgendaItem> agenda, DateTime now, {int days = 3, int horizon = 14}) {
  final today = dateOnly(now);
  final out = <StudyStep>[];
  for (final a in agenda) {
    if (a.done || (a.kind != 'verifica' && a.kind != 'interrogazione')) continue;
    final until = daysBetweenDates(today, a.date);
    if (until <= 0 || until > horizon) continue;
    // Gli ultimi [days] giorni prima della verifica (0 = oggi), mai il giorno stesso.
    final start = until - days < 0 ? 0 : until - days;
    final n = until - start;
    for (var k = start; k < until; k++) {
      out.add(StudyStep(a, DateTime(today.year, today.month, today.day + k), k - start + 1, n));
    }
  }
  out.sort((a, b) => a.day.compareTo(b.day));
  return out;
}

int daysBetweenDates(DateTime a, DateTime b) =>
    DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

// ---------------------------------------------------------------------------
// Periodi (trimestre/pentamestre o quadrimestri) e pagella

/// 'tri' = trimestre fino alle vacanze di Natale; 'quad' = quadrimestre fino al 31 gennaio.
int gradePeriod(DateTime d, {String mode = 'tri'}) {
  // L'anno scolastico inizia a settembre.
  final m = d.month;
  if (m >= 9) return 1;
  if (mode == 'quad') return m == 1 ? 1 : 2;
  return 2; // gennaio-giugno: pentamestre
}

String periodName(int p, {String mode = 'tri'}) =>
    mode == 'quad' ? '$pº quadrimestre' : (p == 1 ? 'Trimestre' : 'Pentamestre');

/// Voto in pagella: arrotondato all'intero (dal ,5 in su si sale).
int reportCardMark(double average) => (average + 0.0001).round().clamp(1, 10);

// ---------------------------------------------------------------------------
// Crediti scolastici (tabella del D.Lgs. 62/2017, allegato A)

/// Fascia di credito (min, max) per la media [m] in un anno (3, 4 o 5). null = non ammesso.
(int, int)? creditBand(double m, int year) {
  const table = <List<(int, int)?>>[
    // M<6, M=6, 6<M≤7, 7<M≤8, 8<M≤9, 9<M≤10
    [null, (7, 8), (8, 9), (9, 10), (10, 11), (11, 12)], // 3º anno
    [null, (8, 9), (9, 10), (10, 11), (11, 12), (12, 13)], // 4º anno
    [(7, 8), (9, 10), (10, 11), (11, 12), (13, 14), (14, 15)], // 5º anno
  ];
  if (year < 3 || year > 5) return null;
  final row = table[year - 3];
  final i = m < 6
      ? 0
      : m <= 6.0001
          ? 1
          : m <= 7
              ? 2
              : m <= 8
                  ? 3
                  : m <= 9
                      ? 4
                      : 5;
  return row[i];
}

// ---------------------------------------------------------------------------
// Prof, materiale, promemoria settimanali, conti alla rovescia

class TeacherInfo {
  TeacherInfo({this.email = '', this.office = '', this.note = ''});
  String email;

  /// Ricevimento (testo libero: "Martedì 10:30-11:30").
  String office;
  String note;

  bool get isEmpty => email.isEmpty && office.isEmpty && note.isEmpty;

  Map<String, dynamic> toJson() => {'email': email, 'office': office, 'note': note};

  static TeacherInfo fromJson(dynamic j) {
    final m = j is Map ? j : const {};
    return TeacherInfo(email: '${m['email'] ?? ''}', office: '${m['office'] ?? ''}', note: '${m['note'] ?? ''}');
  }
}

/// Cosa portare ogni settimana in un certo giorno ("martedì: libro di storia").
class WeeklyItem {
  WeeklyItem(this.weekday, this.item);

  /// 1 = lunedì.
  final int weekday;
  final String item;

  Map<String, dynamic> toJson() => {'w': weekday, 'i': item};

  static WeeklyItem? fromJson(dynamic j) {
    try {
      final m = Map<String, dynamic>.from(j as Map);
      return WeeklyItem((m['w'] as num).toInt(), '${m['i']}');
    } catch (_) {
      return null;
    }
  }
}

/// Materiale da portare per una materia (libri, quaderni).
/// Restituisce le cose da mettere nello zaino quel giorno: materiale delle materie + settimanali.
List<String> extraBagItems(DaySchedule day, int weekday, Map<String, List<String>> materials, List<WeeklyItem> weekly) {
  final out = <String>[];
  for (final l in day.lessons) {
    if (l.isEmpty) continue;
    for (final key in [l.rawTitle, l.title]) {
      for (final m in materials[key] ?? const <String>[]) {
        if (!out.contains(m)) out.add(m);
      }
    }
  }
  for (final w in weekly) {
    if (w.weekday == weekday && !out.contains(w.item)) out.add(w.item);
  }
  return out;
}

class CountdownEvent {
  CountdownEvent({required this.id, required this.name, required this.date, this.emoji = '🎉'});
  final String id;
  final String name;
  final DateTime date;
  final String emoji;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'date': _iso(date), 'emoji': emoji};

  static CountdownEvent? fromJson(dynamic j) {
    try {
      final m = Map<String, dynamic>.from(j as Map);
      return CountdownEvent(
        id: '${m['id']}',
        name: '${m['name']}',
        date: _parse(m['date'] as String),
        emoji: m['emoji'] as String? ?? '🎉',
      );
    } catch (_) {
      return null;
    }
  }
}

// ---------------------------------------------------------------------------
// Grafici

/// Media progressiva dei voti in ordine di data (per il grafico dell'andamento).
List<(DateTime, double)> runningAverage(Iterable<Grade> grades) {
  final list = grades.toList()..sort((a, b) => a.date.compareTo(b.date));
  final out = <(DateTime, double)>[];
  var sum = 0.0;
  var w = 0.0;
  for (final g in list) {
    sum += g.value * g.weight;
    w += g.weight;
    out.add((g.date, sum / w));
  }
  return out;
}

/// Minuti di studio delle ultime [weeks] settimane (lunedì -> minuti), dalla più vecchia.
List<(DateTime, int)> weeklyStudy(Map<String, int> log, DateTime now, {int weeks = 8}) {
  final monday = dateOnly(now).subtract(Duration(days: now.weekday - 1));
  final out = <(DateTime, int)>[];
  for (var w = weeks - 1; w >= 0; w--) {
    final start = DateTime(monday.year, monday.month, monday.day - 7 * w);
    var sum = 0;
    for (var d = 0; d < 7; d++) {
      final day = DateTime(start.year, start.month, start.day + d);
      sum += log[_iso(day)] ?? 0;
    }
    out.add((start, sum));
  }
  return out;
}

String isoDay(DateTime d) => _iso(d);

import 'agenda.dart';
import 'progress.dart' show isoDay;
import 'school_life.dart' show Grade, average;
import 'wellbeing.dart';

/// Riepilogo della settimana e "Wrapped" dell'anno scolastico (3.9). Solo dati sul telefono: niente va al server.

class Recap {
  Recap({
    required this.from,
    required this.to,
    required this.studyMinutes,
    required this.studyDays,
    required this.bestStudyDay,
    required this.grades,
    required this.gradesAvg,
    required this.bestGrade,
    required this.homeworkDone,
    required this.tests,
    required this.habitTicks,
    required this.bestHabit,
    required this.moodAvg,
    required this.topSubject,
  });

  final DateTime from;
  final DateTime to;
  final int studyMinutes;
  final int studyDays;

  /// (giorno, minuti) del giorno con più studio.
  final (DateTime, int)? bestStudyDay;
  final int grades;
  final double? gradesAvg;
  final Grade? bestGrade;
  final int homeworkDone;

  /// Verifiche e interrogazioni nell'agenda in questo periodo.
  final int tests;
  final int habitTicks;

  /// (emoji nome, serie più lunga nel periodo)
  final (String, int)? bestHabit;
  final double? moodAvg;

  /// Materia con più voti nel periodo.
  final String? topSubject;

  bool get isEmpty => studyMinutes == 0 && grades == 0 && homeworkDone == 0 && habitTicks == 0 && moodAvg == null;
}

bool _inRange(DateTime d, DateTime from, DateTime to) {
  final x = dateOnly(d);
  return !x.isBefore(dateOnly(from)) && !x.isAfter(dateOnly(to));
}

/// Calcola il riepilogo tra [from] e [to] (compresi).
Recap computeRecap({
  required DateTime from,
  required DateTime to,
  required Map<String, int> studyLog,
  required Iterable<Grade> grades,
  required Iterable<AgendaItem> agenda,
  required Iterable<Habit> habits,
  required Map<String, MoodEntry> moods,
}) {
  var minutes = 0, days = 0;
  (DateTime, int)? best;
  for (final e in studyLog.entries) {
    final d = DateTime.tryParse(e.key);
    if (d == null || !_inRange(d, from, to) || e.value <= 0) continue;
    minutes += e.value;
    days++;
    if (best == null || e.value > best.$2) best = (d, e.value);
  }

  final gs = [for (final g in grades) if (_inRange(g.date, from, to)) g];
  Grade? top;
  final bySubject = <String, int>{};
  for (final g in gs) {
    if (top == null || g.value > top.value) top = g;
    bySubject[g.subject] = (bySubject[g.subject] ?? 0) + 1;
  }
  final topSubject = bySubject.isEmpty ? null : (bySubject.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first.key;

  final inAgenda = [for (final a in agenda) if (_inRange(a.date, from, to)) a];
  final hw = inAgenda.where((a) => a.done).length;
  final tests = inAgenda.where((a) => a.kind == 'verifica' || a.kind == 'interrogazione').length;

  var ticks = 0;
  (String, int)? bestHabit;
  for (final h in habits) {
    var run = 0, bestRun = 0;
    for (var d = dateOnly(from); !d.isAfter(dateOnly(to)); d = DateTime(d.year, d.month, d.day + 1)) {
      if (h.days.contains(isoDay(d))) {
        ticks++;
        run++;
        if (run > bestRun) bestRun = run;
      } else {
        run = 0;
      }
    }
    if (bestRun > 0 && (bestHabit == null || bestRun > bestHabit.$2)) bestHabit = ('${h.emoji} ${h.name}', bestRun);
  }

  var moodSum = 0, moodN = 0;
  for (final e in moods.entries) {
    final d = DateTime.tryParse(e.key);
    if (d == null || !_inRange(d, from, to)) continue;
    moodSum += e.value.mood;
    moodN++;
  }

  return Recap(
    from: dateOnly(from),
    to: dateOnly(to),
    studyMinutes: minutes,
    studyDays: days,
    bestStudyDay: best,
    grades: gs.length,
    gradesAvg: average(gs),
    bestGrade: top,
    homeworkDone: hw,
    tests: tests,
    habitTicks: ticks,
    bestHabit: bestHabit,
    moodAvg: moodN == 0 ? null : moodSum / moodN,
    topSubject: topSubject,
  );
}

/// Ultimi 7 giorni, oggi compreso.
(DateTime, DateTime) lastWeek(DateTime now) => (dateOnly(now).subtract(const Duration(days: 6)), dateOnly(now));

/// Anno scolastico in corso: dal 1° settembre a oggi (da luglio ad agosto vale quello appena finito).
(DateTime, DateTime) schoolYear(DateTime now) {
  final start = now.month >= 9 ? DateTime(now.year, 9, 1) : DateTime(now.year - 1, 9, 1);
  final end = now.month >= 7 && now.month <= 8 ? DateTime(now.year, 6, 30) : dateOnly(now);
  return (start, end);
}

/// "3 h 20 min", "45 min".
String formatMinutes(int m) => m >= 60 ? '${m ~/ 60} h${m % 60 == 0 ? '' : ' ${m % 60} min'}' : '$m min';

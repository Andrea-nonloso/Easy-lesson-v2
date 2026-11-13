import 'agenda.dart' show dateOnly;
import 'i18n.dart';
import 'progress.dart' show isoDay;
import 'store.dart';

/// Maturità (3.9): data dell'esame, materie con argomenti da spuntare e una lista di cose pratiche.
/// Solo sul telefono, documento "el.exam" (sezione cifrata "scuola" del backup).

const maxExamSubjects = 15;
const maxTopicsPerSubject = 80;

class ExamTopic {
  ExamTopic({required this.id, required this.text, this.done = false});
  final String id;
  String text;
  bool done;
  Map<String, dynamic> toJson() => {'id': id, 't': text, if (done) 'd': 1};
  static ExamTopic? fromJson(Object? j) {
    if (j is! Map || j['id'] is! String || j['t'] is! String) return null;
    final t = j['t'] as String;
    return ExamTopic(id: j['id'] as String, text: t.length > 120 ? t.substring(0, 120) : t, done: j['d'] == 1);
  }
}

class ExamSubject {
  ExamSubject({required this.id, required this.name, List<ExamTopic>? topics}) : topics = topics ?? [];
  final String id;
  String name;
  final List<ExamTopic> topics;
  int get done => topics.where((t) => t.done).length;
  Map<String, dynamic> toJson() => {'id': id, 'n': name, 't': [for (final t in topics) t.toJson()]};
  static ExamSubject? fromJson(Object? j) {
    if (j is! Map || j['id'] is! String || j['n'] is! String) return null;
    return ExamSubject(id: j['id'] as String, name: j['n'] as String, topics: [
      for (final t in (j['t'] is List ? j['t'] as List : const []).take(maxTopicsPerSubject))
        if (ExamTopic.fromJson(t) case final topic?) topic,
    ]);
  }
}

class ExamPlan {
  ExamPlan({this.date, List<ExamSubject>? subjects, Set<String>? checks}) : subjects = subjects ?? [], checks = checks ?? {};

  /// Giorno della prima prova (null = non ancora scelto).
  DateTime? date;
  final List<ExamSubject> subjects;

  /// Voci della lista pratica già fatte (id di [examChecklist]).
  final Set<String> checks;

  bool get isEmpty => date == null && subjects.isEmpty && checks.isEmpty;

  int get topicsTotal => subjects.fold(0, (n, s) => n + s.topics.length);
  int get topicsDone => subjects.fold(0, (n, s) => n + s.done);

  /// Avanzamento 0-1: argomenti spuntati (se ce ne sono), altrimenti la lista pratica.
  double get progress {
    final total = topicsTotal + examChecklist.length;
    return total == 0 ? 0 : (topicsDone + checks.length) / total;
  }

  int? daysLeft(DateTime now) => date == null ? null : dateOnly(date!).difference(dateOnly(now)).inDays;

  /// Argomenti da ripassare al giorno per finire una settimana prima dell'esame.
  double? topicsPerDay(DateTime now) {
    final left = daysLeft(now);
    if (left == null) return null;
    final remaining = topicsTotal - topicsDone;
    if (remaining <= 0) return 0;
    final days = left - 7;
    return days <= 0 ? remaining.toDouble() : remaining / days;
  }

  Map<String, dynamic> toJson() => {
        if (date != null) 'date': isoDay(date!),
        's': [for (final s in subjects) s.toJson()],
        'c': checks.toList()..sort(),
      };

  static ExamPlan fromJson(Object? j) {
    if (j is! Map) return ExamPlan();
    final ids = {for (final c in examChecklist) c.$1};
    return ExamPlan(
      date: DateTime.tryParse('${j['date']}'),
      subjects: [
        for (final s in (j['s'] is List ? j['s'] as List : const []).take(maxExamSubjects))
          if (ExamSubject.fromJson(s) case final subject?) subject,
      ],
      checks: {for (final c in (j['c'] is List ? j['c'] as List : const [])) if (ids.contains(c)) c as String},
    );
  }

  static ExamPlan load(AppStore s) => fromJson(s.doc('exam'));
  Future<void> save(AppStore s) => s.setDoc('exam', isEmpty ? null : toJson());
}

/// Prima prova "di solito": il 18 giugno (si cambia a mano quando esce il calendario del ministero).
DateTime defaultExamDate(DateTime now) {
  final d = DateTime(now.year, 6, 18);
  return dateOnly(now).isAfter(d) ? DateTime(now.year + 1, 6, 18) : d;
}

/// Lista pratica: (id, testo).
List<(String, String)> get examChecklist => [
      ('p1', tr('Ripassare le tipologie della prima prova (A, B, C)', 'Review the first test types (A, B, C)')),
      ('p2', tr('Fare almeno una simulazione della seconda prova', 'Do at least one mock second test')),
      ('p3', tr('Preparare i collegamenti per il colloquio', 'Prepare links between subjects for the oral')),
      ('p4', tr('Scrivere un riassunto delle esperienze PCTO', 'Write a summary of your work experience (PCTO)')),
      ('p5', tr('Completare il Curriculum dello studente', 'Complete the Student CV')),
      ('p6', tr('Ripassare educazione civica', 'Review civics')),
      ('p7', tr('Controllare cosa si può portare (vocabolario, calcolatrice)', 'Check what you can bring (dictionary, calculator)')),
      ('p8', tr('Documento d\'identità valido', 'Valid ID document')),
    ];

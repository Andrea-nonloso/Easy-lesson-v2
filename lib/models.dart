import 'dart:convert';

/// Classe o docente di cui si vuole l'orario.
class ScheduleRef {
  const ScheduleRef(this.name, {required this.prof});

  final String name;
  final bool prof;

  String get key => '${prof ? 'd' : 'c'}:$name';

  String get displayName => prof ? nick(teacherLabel(name)) : nick(name.toUpperCase());

  String get kindLabel {
    if (!prof) return 'Classe';
    final s = teacherSubject(name);
    return s == null ? 'Docente' : 'Docente · $s';
  }

  static ScheduleRef? fromKey(String key) {
    if (key.length < 3 || key[1] != ':') return null;
    return ScheduleRef(key.substring(2), prof: key[0] == 'd');
  }

  @override
  bool operator ==(Object other) => other is ScheduleRef && other.key == key;

  @override
  int get hashCode => key.hashCode;
}

/// Nomi delle classi di concorso usate nell'orario (es. "A026 Rossi" = Matematica).
/// AS2A/AS2C sono ipotesi (lingue straniere): correggile se serve.
const subjectNames = <String, String>{
  'A012': 'Italiano e storia',
  'AS12': 'Italiano e storia',
  'A015': 'Discipline sanitarie',
  'A017': 'Disegno e storia dell\'arte',
  'A020': 'Fisica',
  'A021': 'Geografia',
  'A026': 'Matematica',
  'A027': 'Matematica e fisica',
  'A034': 'Chimica',
  'A037': 'Costruzioni e disegno',
  'A040': 'Elettrotecnica ed elettronica',
  'A041': 'Informatica',
  'A042': 'Meccanica',
  'A044': 'Tecnologie della moda',
  'A045': 'Economia aziendale',
  'A046': 'Diritto ed economia',
  'A047': 'Matematica applicata',
  'A048': 'Scienze motorie',
  'A050': 'Scienze naturali',
  'A051': 'Agraria',
  'AB24': 'Inglese',
  'AS2B': 'Inglese',
  'AA24': 'Francese',
  'AS2A': 'Francese',
  'AC24': 'Spagnolo',
  'AS2C': 'Spagnolo',
  'B003': 'Laboratorio di fisica',
  'B012': 'Laboratorio di chimica',
  'B014': 'Laboratorio costruzioni',
  'B015': 'Laboratorio elettronica',
  'B016': 'Laboratorio informatica',
  'B017': 'Laboratorio meccanica',
  'B018': 'Laboratorio moda',
  '_IRC': 'Religione',
};

final _codeRe = RegExp(r'^(_[A-Z]{2,4}|[A-Z]{1,2}\d[A-Z0-9]{1,3})\s+(.+)$');

/// Codice materia all'inizio del nome docente ("A026 Rossi" → "A026").
String? teacherCode(String raw) => _codeRe.firstMatch(raw.trim())?.group(1);

/// Nome del docente senza codice materia ("A026 Rossi" → "Rossi").
String teacherLabel(String raw) => _codeRe.firstMatch(raw.trim())?.group(2)?.trim() ?? raw.trim();

/// Personalizzazioni dalle impostazioni (caricate dallo store all'avvio).
/// Codice -> materia, ad es. {'AS2A': 'Tedesco'}.
final Map<String, String> subjectOverrides = {};

/// Docente (nome completo come nel file) -> materia, ha la precedenza sul codice.
final Map<String, String> teacherSubjectOverrides = {};

/// Materia associata a un codice (personalizzata o predefinita).
String subjectForCode(String code) => subjectOverrides[code] ?? subjectNames[code] ?? code;

/// Materia del docente: eccezione personale, altrimenti dal codice.
String? teacherSubject(String raw) {
  final o = teacherSubjectOverrides[raw.trim()];
  if (o != null) return o;
  final c = teacherCode(raw);
  return c == null ? null : subjectForCode(c);
}

/// Soprannomi scelti dall'utente: nome originale (materia, docente, classe) -> nome mostrato.
final Map<String, String> nicknames = {};

/// Emoji scelte dall'utente per le materie: nome originale -> emoji.
final Map<String, String> subjectEmojis = {};

/// Nome con il soprannome, se c'è.
String nick(String s) {
  final n = nicknames[s.trim()];
  return n == null || n.trim().isEmpty ? s : n;
}

/// Materia come la vuole vedere l'utente: emoji + soprannome.
String decorateSubject(String s) {
  final e = subjectEmojis[s.trim()];
  final n = nick(s);
  return e == null || e.trim().isEmpty ? n : '${e.trim()} $n';
}

/// Applica soprannomi ed emoji alle righe di un'ora (materia, poi docenti/classi).
List<String> decorateLines(List<String> lines) {
  if (lines.isEmpty || (nicknames.isEmpty && subjectEmojis.isEmpty)) return lines;
  return [
    decorateSubject(lines.first),
    for (final l in lines.skip(1)) l.split(' · ').map(nick).join(' · '),
  ];
}

/// Il server scrive le ore come "A041 Rossi con B016 Bianchi": si trasformano in
/// ["Informatica", "Rossi · Bianchi"], come per i dati letti dal file Excel.
List<String> readableLessonLines(List<String> lines) {
  if (lines.isEmpty) return lines;
  final parts = lines.first
      .split(RegExp(r'\s+con\s+|\s*[,;+]\s*', caseSensitive: false))
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty || parts.any((p) => teacherCode(p) == null)) return lines;
  final main = parts.firstWhere(
    (p) => !teacherCode(p)!.startsWith('B'),
    orElse: () => parts.first,
  );
  return [
    teacherSubject(main) ?? lines.first,
    parts.map(teacherLabel).join(' · '),
    ...lines.skip(1),
  ];
}

/// Una singola ora di lezione.
class Lesson {
  Lesson({
    required this.index,
    required String text,
    required this.lab,
    required this.sostegno,
  }) : rawLines = readableLessonLines(text
            .split(RegExp(r'[\r\n]+'))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty && s.toLowerCase() != 'null')
            .toList());

  /// Indice dell'ora (0 = prima ora).
  final int index;

  /// Righe originali, senza soprannomi né emoji.
  final List<String> rawLines;

  /// Testo dell'ora diviso per righe (materia, docente/classe, ...), con i soprannomi.
  late final List<String> lines = decorateLines(rawLines);

  /// Materia originale (per lo zaino e le ricerche).
  String get rawTitle => rawLines.isEmpty ? '' : rawLines.first;
  final String lab;
  final List<String> sostegno;

  bool get isEmpty => lines.isEmpty;
  String get title => lines.isEmpty ? '' : lines.first;
  List<String> get details => lines.length > 1 ? lines.sublist(1) : const [];

  /// Due ore consecutive con la stessa firma vengono unite nella vista giorno.
  String get signature => '${lines.join('|')}#$lab#${sostegno.join(',')}';
}

class DaySchedule {
  DaySchedule(this.lessons);

  final List<Lesson> lessons;

  bool get isEmpty => lessons.every((l) => l.isEmpty);

  factory DaySchedule.fromJson(Map<String, dynamic> json, {required bool prof}) {
    String s(dynamic v) {
      final t = v?.toString().trim() ?? '';
      return t.toLowerCase() == 'null' ? '' : t;
    }

    int n(dynamic v) => v is int ? v : int.tryParse(s(v)) ?? 0;

    final sost = json['sostegno'] is List ? json['sostegno'] as List : const [];
    final all = <Lesson>[];
    for (var k = 0; k < 10; k++) {
      final rawSost = k < sost.length ? s(sost[k]) : '';
      all.add(Lesson(
        index: k,
        text: s(json['ora${k + 1}']),
        lab: s(json['lab${k + 1}']),
        sostegno: rawSost
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty && e.toLowerCase() != 'null')
            .toList(),
      ));
    }
    var last = -1;
    for (var k = 0; k < all.length; k++) {
      if (!all[k].isEmpty) last = k;
    }
    // Per le classi si rispetta il numero di ore del giorno; per i docenti
    // si tagliano le ore libere finali.
    var count = last + 1;
    if (!prof && n(json['oreGiorno']) > count) count = n(json['oreGiorno']);
    if (count > 10) count = 10;
    return DaySchedule(all.sublist(0, count));
  }
}

class WeekSchedule {
  WeekSchedule(this.days);

  final List<DaySchedule> days;

  bool get isEmpty => days.isEmpty || days.every((d) => d.isEmpty);

  int get maxLessons =>
      days.fold(0, (m, d) => d.lessons.length > m ? d.lessons.length : m);

  factory WeekSchedule.fromJson(Map<String, dynamic> json, {required bool prof}) {
    final days = <DaySchedule>[];
    for (var i = 0; i < 7; i++) {
      final d = json['giorno$i'];
      if (d is! Map) break;
      days.add(DaySchedule.fromJson(Map<String, dynamic>.from(d), prof: prof));
    }
    return WeekSchedule(days);
  }
}

/// Fascia oraria (es. "08:00 - 09:00").
class TimeSlot {
  TimeSlot(this.label, this.start, this.end);

  final String label;
  final int? start; // minuti dalla mezzanotte
  final int? end;

  static String fmt(int? m) =>
      m == null ? '' : '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

  String get startText => fmt(start);
  String get endText => fmt(end);

  static List<TimeSlot> parseAll(List<String> labels) {
    final re = RegExp(r'(\d{1,2})\s*[:.]\s*(\d{2})');
    final starts = <int?>[];
    final ends = <int?>[];
    for (final l in labels) {
      final m = re.allMatches(l).toList();
      int? at(int i) => i < m.length ? int.parse(m[i].group(1)!) * 60 + int.parse(m[i].group(2)!) : null;
      starts.add(at(0));
      ends.add(at(1));
    }
    return [
      for (var i = 0; i < labels.length; i++)
        TimeSlot(
          labels[i],
          starts[i],
          ends[i] ??
              (i + 1 < labels.length ? starts[i + 1] : null) ??
              (starts[i] == null ? null : starts[i]! + 60),
        ),
    ];
  }
}

/// Fasce scritte come "07:50 - 08:40" a partire da minuti (inizio, fine).
List<String> bellLabels(List<(int, int)> bells) =>
    [for (final b in bells) '${TimeSlot.fmt(b.$1)} - ${TimeSlot.fmt(b.$2)}'];

/// Orario delle campanelle dell'IIS Rosselli (usato se il server non fornisce
/// fasce orarie valide). La 7ª ora c'è solo in alcuni giorni.
const defaultOreLabels = [
  '07:50 - 08:40',
  '08:40 - 09:30',
  '09:30 - 10:20',
  '10:30 - 11:30',
  '11:30 - 12:10',
  '12:20 - 13:10',
  '13:10 - 14:00',
];

/// Fasce dal server se tutte hanno un orario leggibile, altrimenti quelle predefinite.
List<TimeSlot> slotsFrom(List<String> labels) {
  final parsed = TimeSlot.parseAll(labels);
  if (parsed.isNotEmpty && parsed.every((s) => s.start != null && s.end != null)) return parsed;
  return TimeSlot.parseAll(defaultOreLabels);
}

/// Ricreazione: pausa tra la fine di un'ora e l'inizio della successiva.
class BreakSlot {
  const BreakSlot(this.afterIndex, this.start, this.end);

  /// Indice dell'ora dopo cui cade la pausa (0 = dopo la 1ª ora).
  final int afterIndex;
  final int start;
  final int end;

  String get label => 'Ricreazione ${TimeSlot.fmt(start)} – ${TimeSlot.fmt(end)}';
}

/// Le pause si ricavano dai "buchi" tra le fasce (es. 10:20 → 10:30).
List<BreakSlot> breaksOf(List<TimeSlot> slots) => [
      for (var i = 0; i + 1 < slots.length; i++)
        if (slots[i].end != null && slots[i + 1].start != null && slots[i + 1].start! > slots[i].end!)
          BreakSlot(i, slots[i].end!, slots[i + 1].start!),
    ];

BreakSlot? breakAfter(List<BreakSlot> breaks, int index) {
  for (final b in breaks) {
    if (b.afterIndex == index) return b;
  }
  return null;
}

/// Estrae i testi degli elementi `<ora>` dall'XML delle fasce orarie.
List<String> parseOreXml(String xml) {
  String decode(String s) => s
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&amp;', '&')
      .trim();
  return RegExp(r'<ora(?:\s[^>]*)?>([\s\S]*?)</ora>')
      .allMatches(xml)
      .map((m) => decode(m.group(1) ?? ''))
      .toList();
}

/// La cloud function restituisce il JSON dell'orario dentro una stringa JSON.
Map<String, dynamic> decodeOrario(String body) {
  dynamic d;
  try {
    d = jsonDecode(body);
    if (d is String) d = jsonDecode(d);
  } catch (_) {
    var s = body.trim().replaceAll(r'\"', '"');
    if (s.length > 1 && s.startsWith('"') && s.endsWith('"')) {
      s = s.substring(1, s.length - 1);
    }
    d = jsonDecode(s);
  }
  if (d is Map) return Map<String, dynamic>.from(d);
  throw const FormatException('Orario non trovato');
}

const dayNames = ['Lunedì', 'Martedì', 'Mercoledì', 'Giovedì', 'Venerdì', 'Sabato', 'Domenica'];
const dayShort = ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'];

/// Indice del giorno corrente nella settimana scolastica, -1 se non c'è scuola.
int todayIndex(DateTime now, int days) => now.weekday <= days ? now.weekday - 1 : -1;

/// Lunedì della settimana mostrata (nel weekend si passa a quella successiva).
DateTime weekStart(DateTime now, int days) {
  final d = DateTime(now.year, now.month, now.day);
  if (now.weekday > days) return d.add(Duration(days: 8 - now.weekday));
  return d.subtract(Duration(days: now.weekday - 1));
}

int? currentSlot(List<TimeSlot> slots, DateTime now) {
  final m = now.hour * 60 + now.minute;
  for (var i = 0; i < slots.length; i++) {
    final s = slots[i];
    if (s.start != null && s.end != null && m >= s.start! && m < s.end!) return i;
  }
  return null;
}

String normalizeSearch(String s) {
  const from = 'àáâäèéêëìíîïòóôöùúûü';
  const to = 'aaaaeeeeiiiioooouuuu';
  final b = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    final i = from.indexOf(ch);
    if (ch.trim().isEmpty || ch == "'" || ch == '’') continue;
    b.write(i >= 0 ? to[i] : ch);
  }
  return b.toString();
}

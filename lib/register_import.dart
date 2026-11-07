import 'agenda.dart' show dateOnly;
import 'school_life.dart';
import 'i18n.dart';

/// Importa assenze, ritardi e uscite dal testo del registro elettronico (app "RF").
///
/// Il testo si prende dagli screenshot con "Copia testo" (Google Lens / Foto / "Seleziona" nella schermata
/// delle app recenti del Pixel) e si incolla in Easy Lesson. Ogni scheda del registro è così:
///   06/10/2026  Ritardi  Entra alle 08:40:00 - Ora di lezione: 2  Non concorre al calcolo
/// Ritardo -> 'entrata' alla N-esima ora; uscita "Ora di lezione: N" -> esce durante la N-esima ora
/// (quindi 'uscita' dopo la (N-1)-esima); assenza -> tutto il giorno.

class RegisterEntry {
  RegisterEntry({required this.date, required this.kind, required this.hour, required this.counts, this.time});
  final DateTime date;

  /// assenza | entrata | uscita (come [AbsenceEntry.kind])
  final String kind;
  final int hour;

  /// "Concorre al calcolo" (false = giustificata e non conta, secondo il registro).
  final bool counts;
  final String? time;

  String get key => '${date.year}-${date.month}-${date.day}-$kind';

  String get label => switch (kind) {
        'entrata' => appEnglish
            ? 'Late${time == null ? '' : ' (in at $time)'} · entry at period $hour'
            : 'Ritardo${time == null ? '' : ' (entra alle $time)'} · entrata alla $hourª ora',
        'uscita' => appEnglish
            ? 'Early exit${time == null ? '' : ' at $time'} · after period $hour'
            : 'Uscita${time == null ? '' : ' alle $time'} · dopo la $hourª ora',
        _ => tr('Assenza', 'Absence'),
      };

  String get note => [
        if (kind == 'entrata') '${tr('ritardo', 'late')}${time == null ? '' : ' $time'}',
        if (kind == 'uscita' && time != null) '${tr('uscita', 'exit')} $time',
        if (!counts) 'non concorre al calcolo',
        'dal registro',
      ].join(' · ');
}

final _date = RegExp(r'(\d{1,2})\s*[/.\-]\s*(\d{1,2})\s*[/.\-]\s*(\d{4})');
final _time = RegExp(r'(\d{1,2})[:.](\d{2})(?:[:.]\d{2})?');
final _hour = RegExp(r'ora\s*di\s*lezione\s*[:.]?\s*(\d{1,2})', caseSensitive: false);

/// Legge tutte le schede dal testo. Le date fuori dal registro (o rotte) si ignorano; doppioni tolti.
List<RegisterEntry> parseRegisterText(String text) {
  final t = text.replaceAll('\r', '\n');
  final matches = _date.allMatches(t).toList();
  final out = <String, RegisterEntry>{};
  for (var i = 0; i < matches.length; i++) {
    final m = matches[i];
    final chunk = t.substring(m.end, i + 1 < matches.length ? matches[i + 1].start : t.length);
    final d = int.parse(m.group(1)!), mo = int.parse(m.group(2)!), y = int.parse(m.group(3)!);
    if (mo < 1 || mo > 12 || d < 1 || d > 31 || y < 2000 || y > 2100) continue;
    final date = DateTime(y, mo, d);
    if (date.month != mo) continue; // es. 31/02
    final low = chunk.toLowerCase();
    final String kind;
    if (low.contains('assenz')) {
      kind = 'assenza';
    } else if (low.contains('ritard') || low.contains('entrat')) {
      kind = 'entrata';
    } else if (low.contains('uscit')) {
      kind = 'uscita';
    } else {
      continue; // rientri o altro
    }
    final tm = _time.firstMatch(chunk);
    final hm = _hour.firstMatch(chunk);
    var hour = hm == null ? (kind == 'entrata' ? 2 : 1) : int.parse(hm.group(1)!);
    // Uscita durante la N-esima ora = in Easy Lesson "esco dopo la (N-1)-esima".
    if (kind == 'uscita') hour = (hour - 1).clamp(1, 12);
    if (kind == 'entrata') hour = hour.clamp(2, 12);
    final e = RegisterEntry(
      date: dateOnly(date),
      kind: kind,
      hour: kind == 'assenza' ? 1 : hour,
      counts: !RegExp(r'non\s*concorre', caseSensitive: false).hasMatch(chunk),
      time: tm == null ? null : '${tm.group(1)!.padLeft(2, '0')}:${tm.group(2)}',
    );
    out.putIfAbsent(e.key, () => e);
  }
  final list = out.values.toList()..sort((a, b) => b.date.compareTo(a.date));
  return list;
}

/// true se in Easy Lesson c'è già una voce dello stesso giorno e tipo.
bool alreadyThere(RegisterEntry e, List<AbsenceEntry> existing) =>
    existing.any((a) => a.kind == e.kind && dateOnly(a.date) == e.date);

import 'models.dart';

/// Crea un calendario .ics (Google Calendar, Outlook, Calendario di Windows)
/// con le lezioni della settimana, ripetute ogni settimana fino a giugno.
/// Dart puro: riusabile anche dal futuro bot.
String buildIcs({
  required ScheduleRef ref,
  required WeekSchedule week,
  required List<TimeSlot> slots,
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  // Settimana scolastica di almeno 5 giorni (lun-ven), anche se l'orario ne ha meno.
  final monday = weekStart(today, week.days.length < 5 ? 5 : week.days.length);
  // Fine anno scolastico: 10 giugno (dell'anno prossimo se siamo da settembre in poi).
  final endYear = today.month >= 9 ? today.year + 1 : today.year;
  final until = '${endYear}0610T235959';
  final stamp = _utc(today.toUtc());
  final breaks = breaksOf(slots);

  final out = StringBuffer()
    ..write('BEGIN:VCALENDAR\r\n')
    ..write('VERSION:2.0\r\n')
    ..write('PRODID:-//Easy Lesson//Orario//IT\r\n')
    ..write('CALSCALE:GREGORIAN\r\n')
    ..write('METHOD:PUBLISH\r\n');
  _line(out, 'X-WR-CALNAME', 'Orario ${ref.displayName}');

  var uid = 0;
  for (var d = 0; d < week.days.length; d++) {
    final lessons = week.days[d].lessons;
    var i = 0;
    while (i < lessons.length) {
      final l = lessons[i];
      // Ore consecutive uguali (senza ricreazione in mezzo) = un solo evento.
      var j = i;
      while (j + 1 < lessons.length &&
          lessons[j + 1].signature == l.signature &&
          breakAfter(breaks, j) == null) {
        j++;
      }
      if (!l.isEmpty && i < slots.length && j < slots.length && slots[i].start != null && slots[j].end != null) {
        final day = monday.add(Duration(days: d));
        final desc = [
          ...l.details,
          if (l.lab.isNotEmpty) 'Laboratorio: ${l.lab}',
          if (l.sostegno.isNotEmpty) 'Sostegno: ${l.sostegno.join(', ')}',
          '${i + 1}ª${j > i ? '–${j + 1}ª' : ''} ora',
        ].join('\n');
        out.write('BEGIN:VEVENT\r\n');
        _line(out, 'UID', 'easylesson-${ref.key.hashCode.toUnsigned(32)}-$d-$i-${uid++}@easylesson');
        _line(out, 'DTSTAMP', stamp);
        _line(out, 'DTSTART', _local(day, slots[i].start!));
        _line(out, 'DTEND', _local(day, slots[j].end!));
        _line(out, 'RRULE', 'FREQ=WEEKLY;UNTIL=$until');
        _line(out, 'SUMMARY', _esc(l.title));
        if (l.lab.isNotEmpty) _line(out, 'LOCATION', _esc(l.lab));
        _line(out, 'DESCRIPTION', _esc(desc));
        out.write('END:VEVENT\r\n');
      }
      i = j + 1;
    }
  }
  out.write('END:VCALENDAR\r\n');
  return out.toString();
}

String _two(int n) => n.toString().padLeft(2, '0');

/// Ora locale "fluttuante": il calendario la mostra nell'ora del dispositivo.
String _local(DateTime day, int minutes) =>
    '${day.year}${_two(day.month)}${_two(day.day)}T${_two(minutes ~/ 60)}${_two(minutes % 60)}00';

String _utc(DateTime t) =>
    '${t.year}${_two(t.month)}${_two(t.day)}T${_two(t.hour)}${_two(t.minute)}${_two(t.second)}Z';

String _esc(String s) => s
    .replaceAll('\\', '\\\\')
    .replaceAll(';', '\\;')
    .replaceAll(',', '\\,')
    .replaceAll('\n', '\\n');

/// Scrive "NOME:valore" spezzando le righe lunghe come vuole lo standard (75 caratteri).
void _line(StringBuffer out, String name, String value) {
  final full = '$name:$value';
  var start = 0;
  var first = true;
  while (start < full.length) {
    final max = first ? 75 : 74;
    var end = start + max < full.length ? start + max : full.length;
    // Non spezzare una coppia surrogata (emoji).
    if (end < full.length && full.codeUnitAt(end - 1) >= 0xD800 && full.codeUnitAt(end - 1) <= 0xDBFF) end--;
    out
      ..write(first ? '' : ' ')
      ..write(full.substring(start, end))
      ..write('\r\n');
    start = end;
    first = false;
  }
}

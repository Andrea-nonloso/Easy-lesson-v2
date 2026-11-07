import 'i18n.dart';
import 'models.dart' show dayShort;

/// Compiti, verifiche e promemoria legati a una materia e a un giorno.
/// Salvati solo sul dispositivo.
class AgendaItem {
  AgendaItem({
    required this.id,
    required this.date,
    required this.kind,
    required this.subject,
    required this.text,
    this.done = false,
  });

  final String id;

  /// Solo la data (ore a mezzanotte).
  final DateTime date;

  /// 'compito' | 'verifica' | 'interrogazione' | 'altro'
  final String kind;
  final String subject;
  final String text;
  bool done;

  static const kinds = ['compito', 'verifica', 'interrogazione', 'altro'];

  static String emojiOf(String kind) => switch (kind) {
        'verifica' => '📝',
        'interrogazione' => '🎤',
        'compito' => '📚',
        _ => '📌',
      };

  static String labelOf(String kind) => switch (kind) {
        'verifica' => tr('Verifica', 'Test'),
        'interrogazione' => 'Interrogazione',
        'compito' => tr('Compiti', 'Homework'),
        _ => 'Promemoria',
      };

  String get emoji => emojiOf(kind);
  String get label => labelOf(kind);

  /// Testo breve per elenchi: "📝 Verifica di Matematica: equazioni".
  String get summary => '$emoji $label${subject.isEmpty ? '' : ' · $subject'}${text.isEmpty ? '' : ': $text'}';

  bool sameSubject(String s) => _norm(subject) == _norm(s);

  /// Senza maiuscole né emoji davanti ("🧮 Matematica" = "matematica").
  static String _norm(String s) => s.trim().toLowerCase().replaceFirst(RegExp(r'^[^\p{L}\p{N}]+', unicode: true), '');

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': '${date.year}-${date.month}-${date.day}',
        'kind': kind,
        'subject': subject,
        'text': text,
        'done': done,
      };

  static AgendaItem? fromJson(dynamic j) {
    try {
      final m = Map<String, dynamic>.from(j as Map);
      final p = (m['date'] as String).split('-').map(int.parse).toList();
      return AgendaItem(
        id: m['id'] as String,
        date: DateTime(p[0], p[1], p[2]),
        kind: m['kind'] as String? ?? 'altro',
        subject: m['subject'] as String? ?? '',
        text: m['text'] as String? ?? '',
        done: m['done'] == true,
      );
    } catch (_) {
      return null;
    }
  }
}

DateTime dateOnly(DateTime t) => DateTime(t.year, t.month, t.day);

/// Prossima data (da oggi in poi) del giorno della settimana [dayIndex] (0 = lunedì).
/// Se è oggi ma la lezione è già finita ([endMinutes]), passa alla settimana dopo.
DateTime nextDateFor(int dayIndex, DateTime now, {int? endMinutes}) {
  var diff = (dayIndex - (now.weekday - 1)) % 7;
  if (diff == 0 && endMinutes != null && now.hour * 60 + now.minute >= endMinutes) diff = 7;
  return DateTime(now.year, now.month, now.day + diff);
}

/// "Oggi", "Domani", "Lun 3/11"
String friendlyDate(DateTime d, DateTime now) {
  final days = dayShort;
  final diff = DateTime.utc(d.year, d.month, d.day).difference(DateTime.utc(now.year, now.month, now.day)).inDays;
  if (diff == 0) return tr('Oggi', 'Today');
  if (diff == 1) return tr('Domani', 'Tomorrow');
  if (diff == -1) return tr('Ieri', 'Yesterday');
  return '${days[d.weekday - 1]} ${d.day}/${d.month}';
}

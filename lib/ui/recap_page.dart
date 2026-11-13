import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../i18n.dart';
import '../log.dart';
import '../native.dart';
import '../recap.dart';
import '../school_life.dart' show Grade;
import '../store.dart';
import '../wellbeing.dart';
import 'achievements.dart' show levelOf, totalXp;
import 'save_file_io.dart' if (dart.library.js_interop) 'save_file_web.dart';
import 'widgets.dart';

// Riepilogo della settimana e Wrapped dell'anno (3.9), con immagine da condividere.

void openRecap(BuildContext context, {bool year = false}) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => RecapPage(year: year)));

/// (emoji, valore grande, etichetta)
typedef RecapTile = (String, String, String);

String _d(DateTime d) => '${d.day}/${d.month}';

List<RecapTile> recapTiles(Recap r, AppStore s, {required bool year}) {
  final moodIdx = r.moodAvg == null ? null : (r.moodAvg!.round() - 1).clamp(0, 4);
  return [
    if (r.studyMinutes > 0) ('⏱️', formatMinutes(r.studyMinutes), tr('di studio in ${r.studyDays} giorni', 'of study over ${r.studyDays} days')),
    if (r.bestStudyDay case final b?) ('🔥', formatMinutes(b.$2), tr('il giorno record (${_d(b.$1)})', 'record day (${_d(b.$1)})')),
    if (r.grades > 0) ('📊', r.gradesAvg!.toStringAsFixed(2), tr('di media su ${r.grades} voti', 'average over ${r.grades} grades')),
    if (r.bestGrade case final g?) ('🏆', Grade.format(g.value), tr('il voto più alto (${g.subject})', 'top grade (${g.subject})')),
    if (year && r.topSubject != null) ('📚', r.topSubject!, tr('la materia con più voti', 'subject with most grades')),
    if (r.homeworkDone > 0) ('✅', '${r.homeworkDone}', tr('compiti fatti', 'homework done')),
    if (r.tests > 0) ('📝', '${r.tests}', tr('verifiche e interrogazioni', 'tests and oral exams')),
    if (r.habitTicks > 0) ('🌱', '${r.habitTicks}', tr('abitudini spuntate', 'habits ticked')),
    if (r.bestHabit case final h?) ('🔗', tr('${h.$2} giorni', '${h.$2} days'), tr('di fila: ${h.$1}', 'in a row: ${h.$1}')),
    if (moodIdx != null) (moodEmojis[moodIdx], r.moodAvg!.toStringAsFixed(1), tr('umore medio (su 5)', 'average mood (out of 5)')),
    if (year) ...[
      ('⭐', '${levelOf(s).level}', tr('livello raggiunto', 'level reached')),
      ('💎', '${totalXp(s)}', 'XP'),
      if (s.stat('bestStreak') > 0) ('📅', '${s.stat('bestStreak')}', tr('giorni di fila con l\'app', 'days in a row with the app')),
      if (s.stat('flashReviewed') > 0) ('🃏', '${s.stat('flashReviewed')}', tr('flashcard ripassate', 'flashcards reviewed')),
      if (s.stat('missionsDone') > 0) ('🎯', '${s.stat('missionsDone')}', tr('missioni completate', 'missions completed')),
    ],
  ];
}

Recap _compute(AppStore s, bool year) {
  final (from, to) = year ? schoolYear(DateTime.now()) : lastWeek(DateTime.now());
  return computeRecap(
    from: from,
    to: to,
    studyLog: s.studyLog,
    grades: s.grades,
    agenda: s.agenda,
    habits: Habits.all(s),
    moods: Mood.all(s),
  );
}

/// Disegna la card (1080×1350, formato delle storie a 4:5).
Future<Uint8List> renderRecapImage({required String title, required String subtitle, required List<RecapTile> tiles}) async {
  const w = 540.0, h = 675.0, scale = 2.0, pad = 34.0;
  final rec = ui.PictureRecorder();
  final c = Canvas(rec)..scale(scale);
  const rect = Rect.fromLTWH(0, 0, w, h);
  c.drawRect(
    rect,
    Paint()
      ..shader = ui.Gradient.linear(Offset.zero, const Offset(w, h), const [Color(0xFF4A148C), Color(0xFF1565C0), Color(0xFF00897B)], const [0, 0.6, 1]),
  );
  // Due cerchi morbidi di sfondo.
  c.drawCircle(const Offset(w - 40, 80), 140, Paint()..color = const Color(0x22FFFFFF));
  c.drawCircle(const Offset(40, h - 60), 110, Paint()..color = const Color(0x18FFFFFF));

  double text(String s, Offset at, double maxW, {double size = 14, FontWeight weight = FontWeight.w400, int lines = 1, Color color = const Color(0xFFFFFFFF)}) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(fontSize: size, fontWeight: weight, color: color, fontFamily: 'Hind', height: 1.15)),
      textDirection: TextDirection.ltr,
      maxLines: lines,
      ellipsis: '…',
    )..layout(maxWidth: maxW);
    tp.paint(c, at);
    return tp.height;
  }

  var y = pad;
  y += text(title, Offset(pad, y), w - pad * 2, size: 32, weight: FontWeight.w800, lines: 2) + 4;
  y += text(subtitle, Offset(pad, y), w - pad * 2, size: 15, color: const Color(0xCCFFFFFF)) + 22;

  const gap = 12.0;
  const cols = 2;
  const tileW = (w - pad * 2 - gap) / cols;
  final shown = tiles.take(10).toList();
  final rows = (shown.length / cols).ceil();
  final tileH = rows == 0 ? 0.0 : ((h - y - 56 - gap * (rows - 1)) / rows).clamp(60.0, 110.0);
  for (var i = 0; i < shown.length; i++) {
    final (emoji, value, label) = shown[i];
    final x = pad + (i % cols) * (tileW + gap);
    final ty = y + (i ~/ cols) * (tileH + gap);
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, ty, tileW, tileH), const Radius.circular(16)), Paint()..color = const Color(0x26FFFFFF));
    text(emoji, Offset(x + 14, ty + 12), 40, size: 22);
    text(value, Offset(x + 50, ty + 10), tileW - 60, size: 24, weight: FontWeight.w800);
    text(label, Offset(x + 14, ty + tileH - 38), tileW - 24, size: 12.5, lines: 2, color: const Color(0xDDFFFFFF));
  }
  text('Easy Lesson', const Offset(pad, h - 40), 200, size: 16, weight: FontWeight.w700);

  final pic = rec.endRecording();
  final img = await pic.toImage((w * scale).toInt(), (h * scale).toInt());
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

class RecapPage extends StatefulWidget {
  const RecapPage({super.key, this.year = false});
  final bool year;

  @override
  State<RecapPage> createState() => _RecapPageState();
}

class _RecapPageState extends State<RecapPage> {
  late bool _year = widget.year;
  bool _busy = false;

  String _title() => _year ? tr('Il mio anno scolastico', 'My school year') : tr('La mia settimana', 'My week');

  Future<void> _share(Recap r, List<RecapTile> tiles) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final png = await renderRecapImage(title: _title(), subtitle: '${_d(r.from)} – ${_d(r.to)}', tiles: tiles);
      final name = _year ? 'easylesson_wrapped.png' : 'easylesson_settimana.png';
      if (!await NativeBridge.shareImage(png, name, text: '${_title()} 📚 Easy Lesson')) {
        final where = await saveBytesFile(name, png, mime: 'image/png', title: tr('Salva l\'immagine', 'Save the image'));
        if (where != null) messenger.showSnackBar(SnackBar(content: Text(tr('Immagine salvata', 'Image saved'))));
      }
    } catch (e, st) {
      AppLog.e('riepilogo', e, st);
      messenger.showSnackBar(SnackBar(content: Text(tr('Immagine non riuscita', 'Image failed'))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final r = _compute(store, _year);
    final tiles = recapTiles(r, store, year: _year);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(tr('Riepilogo', 'Recap'))),
      floatingActionButton: tiles.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _busy ? null : () => _share(r, tiles),
              icon: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.ios_share_rounded),
              label: Text(tr('Condividi', 'Share')),
            ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 96), children: [
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: false, label: Text(tr('Settimana', 'Week')), icon: const Icon(Icons.view_week_rounded)),
                ButtonSegment(value: true, label: Text(tr('Anno (Wrapped)', 'Year (Wrapped)')), icon: const Icon(Icons.auto_awesome_rounded)),
              ],
              selected: {_year},
              onSelectionChanged: (v) => setState(() => _year = v.first),
            ),
            const SizedBox(height: 16),
            Text(_title(), style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            Text('${_d(r.from)} – ${_d(r.to)}', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            if (tiles.isEmpty)
              EmptyState(
                icon: Icons.insights_rounded,
                title: tr('Ancora niente da contare', 'Nothing to count yet'),
                message: tr('Usa il timer di studio, segna voti, compiti e abitudini: qui vedrai come è andata.',
                    'Use the study timer, log grades, homework and habits: you\'ll see how it went here.'),
              )
            else
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.5,
                children: [
                  for (final (emoji, value, label) in tiles)
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Row(children: [
                            Text(emoji, style: const TextStyle(fontSize: 20)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(value,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                            ),
                          ]),
                          Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
                        ]),
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 12),
            Text(tr('🔒 Calcolato sul telefono: nell\'immagine c\'è solo quello che vedi qui.', '🔒 Computed on the phone: the image only has what you see here.'),
                style: theme.textTheme.bodySmall),
          ]),
        ),
      ),
    );
  }
}

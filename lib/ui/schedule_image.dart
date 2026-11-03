import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../log.dart';
import '../models.dart';
import '../store.dart';
import 'fun.dart';
import 'save_file_io.dart' if (dart.library.js_interop) 'save_file_web.dart';
import 'widgets.dart';

/// Disegna l'orario della settimana come immagine PNG (sfondo chiaro, si legge bene
/// anche in una chat). Non usa widget a schermo: si può riusare anche per il bot.
Future<Uint8List> renderScheduleImage({
  required String title,
  required String subtitle,
  required WeekSchedule week,
  required List<TimeSlot> slots,
  double scale = 2,
}) async {
  const pad = 28.0;
  const timeW = 74.0;
  const colW = 176.0;
  const headH = 78.0;
  const dayH = 34.0;
  const rowH = 66.0;
  const gap = 5.0;
  const footH = 34.0;
  final n = week.days.length;
  final rows = week.maxLessons;
  final width = pad * 2 + timeW + n * colW;
  final height = pad * 2 + headH + dayH + rows * rowH + footH;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..scale(scale);
  canvas.drawRect(Rect.fromLTWH(0, 0, width, height), Paint()..color = const Color(0xFFF7F7FA));

  void text(String s, Offset at, double maxW,
      {double size = 13, FontWeight weight = FontWeight.w400, Color color = const Color(0xFF1C1B1F), int lines = 1}) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(fontSize: size, fontWeight: weight, color: color, fontFamily: 'Hind', height: 1.15)),
      textDirection: TextDirection.ltr,
      maxLines: lines,
      ellipsis: '…',
    )..layout(maxWidth: maxW);
    tp.paint(canvas, at);
  }

  text(title, const Offset(pad, pad), width - pad * 2, size: 28, weight: FontWeight.w700);
  text(subtitle, const Offset(pad, pad + 38), width - pad * 2, size: 14, color: const Color(0xFF66656B));

  const top = pad + headH;
  for (var d = 0; d < n; d++) {
    text(d < dayNames.length ? dayNames[d] : 'Giorno ${d + 1}', Offset(pad + timeW + d * colW + 8, top + 6), colW - 16,
        size: 15, weight: FontWeight.w700);
  }

  const gridTop = top + dayH;
  for (var h = 0; h < rows; h++) {
    final y = gridTop + h * rowH;
    text('${h + 1}ª', Offset(pad, y + 10), timeW - 8, size: 15, weight: FontWeight.w700);
    if (h < slots.length && slots[h].start != null) {
      text('${slots[h].startText}\n${slots[h].endText}', Offset(pad, y + 30), timeW - 8,
          size: 11, color: const Color(0xFF66656B), lines: 2);
    }
  }

  for (var d = 0; d < n; d++) {
    final lessons = week.days[d].lessons;
    var i = 0;
    while (i < lessons.length) {
      final l = lessons[i];
      var j = i;
      while (j + 1 < lessons.length && lessons[j + 1].signature == l.signature) {
        j++;
      }
      final rect = Rect.fromLTWH(
        pad + timeW + d * colW + gap,
        gridTop + i * rowH + gap,
        colW - gap * 2,
        (j - i + 1) * rowH - gap * 2,
      );
      final rr = RRect.fromRectAndRadius(rect, const Radius.circular(12));
      if (l.isEmpty) {
        canvas.drawRRect(
          rr,
          Paint()
            ..style = PaintingStyle.stroke
            ..color = const Color(0xFFDDDBE3),
        );
      } else {
        final c = SubjectColors.of(l.title, Brightness.light);
        canvas.drawRRect(rr, Paint()..color = c.bg);
        canvas.drawRRect(
          RRect.fromRectAndCorners(Rect.fromLTWH(rect.left, rect.top, 5, rect.height),
              topLeft: const Radius.circular(12), bottomLeft: const Radius.circular(12)),
          Paint()..color = c.accent,
        );
        final tall = j > i;
        text(l.title, Offset(rect.left + 12, rect.top + 7), rect.width - 18,
            size: 13.5, weight: FontWeight.w700, color: c.fg, lines: tall ? 2 : 1);
        final details = [
          ...l.details,
          if (l.lab.isNotEmpty) '${labInfo(l.lab).emoji} ${l.lab}',
        ].join(' · ');
        if (details.isNotEmpty) {
          text(details, Offset(rect.left + 12, rect.top + (tall ? 44 : 27)), rect.width - 18,
              size: 11, color: c.fg.withAlpha(200), lines: tall ? 3 : 1);
        }
      }
      i = j + 1;
    }
  }

  text('Easy Lesson · IIS Rosselli', Offset(pad, height - pad - 14), width - pad * 2,
      size: 11, color: const Color(0xFF8E8C94));

  final picture = recorder.endRecording();
  final image = await picture.toImage((width * scale).ceil(), (height * scale).ceil());
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return data!.buffer.asUint8List();
}

/// Voce di menu "Salva come immagine".
Future<void> saveScheduleImage(BuildContext context, CachedSchedule cached) async {
  final store = StoreScope.read(context);
  final messenger = ScaffoldMessenger.of(context);
  try {
    final png = await renderScheduleImage(
      title: cached.ref.displayName,
      subtitle: '${cached.ref.kindLabel} · aggiornato ${relativeTime(cached.updatedAt)}',
      week: cached.week,
      slots: store.slots,
    );
    final safe = cached.ref.displayName.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
    final where = await saveBytesFile('orario_$safe.png', png, mime: 'image/png', title: 'Salva l\'immagine');
    if (where == null) return;
    AppLog.i('immagine', 'Orario ${cached.ref.key} salvato come PNG (${png.length} byte)');
    messenger.showSnackBar(SnackBar(content: Text(where.isEmpty ? 'Immagine scaricata' : 'Salvata in $where')));
  } catch (e, st) {
    AppLog.e('immagine', e, st);
    messenger.showSnackBar(SnackBar(content: Text('Immagine non riuscita: $e')));
  }
}

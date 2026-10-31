import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import 'app_menu.dart';
import 'theme.dart';
import 'widgets.dart';

void openStats(BuildContext context, CachedSchedule cached) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => StatsPage(cached: cached)));

/// Numeri della settimana: ore per materia, giorno più pesante, laboratori.
class StatsPage extends StatelessWidget {
  const StatsPage({super.key, required this.cached});

  final CachedSchedule cached;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final week = cached.week;

    final bySubject = <String, int>{};
    final byDay = <int>[];
    var total = 0;
    var labHours = 0;
    final labs = <String, int>{};
    final teachers = <String>{};
    for (final d in week.days) {
      var n = 0;
      for (final l in d.lessons) {
        if (l.isEmpty) continue;
        n++;
        bySubject[l.title] = (bySubject[l.title] ?? 0) + 1;
        if (l.lab.isNotEmpty) {
          labHours++;
          labs[l.lab] = (labs[l.lab] ?? 0) + 1;
        }
        if (!cached.ref.prof && l.details.isNotEmpty) {
          teachers.addAll(l.details.first.split(' · ').map((s) => s.trim()).where((s) => s.isNotEmpty));
        }
      }
      byDay.add(n);
      total += n;
    }
    final subjects = bySubject.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final maxDay = byDay.isEmpty ? 0 : byDay.reduce((a, b) => a > b ? a : b);
    final heaviest = [for (var i = 0; i < byDay.length; i++) if (byDay[i] == maxDay && maxDay > 0) dayNames[i]];

    Widget bar(String label, int value, int max, Color color, {String? suffix}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              SizedBox(
                width: 150,
                child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) => Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      height: 18,
                      width: max == 0 ? 0 : box.maxWidth * value / max,
                      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(width: 44, child: Text(suffix ?? '$value h', textAlign: TextAlign.end)),
            ],
          ),
        );

    Widget stat(String emoji, String value, String label) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: cardColor(context), borderRadius: BorderRadius.circular(18)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(height: 4),
                Text(value, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                Text(label, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        );

    return Scaffold(
      appBar: AppBar(
        title: Text('Statistiche · ${cached.ref.displayName}'),
        actions: const [AppMenuButton(), SizedBox(width: 4)],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Row(
                children: [
                  stat('⏱️', '$total', 'ore a settimana'),
                  const SizedBox(width: 10),
                  stat('🔬', '$labHours', 'ore di laboratorio'),
                  const SizedBox(width: 10),
                  stat(cached.ref.prof ? '🏫' : '👩‍🏫', cached.ref.prof ? '${bySubject.length}' : '${teachers.length}',
                      cached.ref.prof ? 'classi' : 'docenti'),
                ],
              ),
              if (heaviest.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text('😮‍💨 Giorno più pesante: ${heaviest.join(' e ')} ($maxDay ore)',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              ],
              SectionLabel(cached.ref.prof ? 'Ore per classe' : 'Ore per materia'),
              for (final e in subjects)
                bar(e.key, e.value, subjects.first.value, SubjectColors.of(e.key, theme.brightness).accent),
              const SectionLabel('Ore per giorno'),
              for (var i = 0; i < byDay.length; i++)
                bar(i < dayNames.length ? dayNames[i] : 'Giorno ${i + 1}', byDay[i], maxDay,
                    byDay[i] == maxDay ? scheme.primary : scheme.primary.withAlpha(110)),
              if (labs.isNotEmpty) ...[
                const SectionLabel('Laboratori'),
                for (final e in (labs.entries.toList()..sort((a, b) => b.value.compareTo(a.value))))
                  bar(e.key, e.value, labs.values.reduce((a, b) => a > b ? a : b), scheme.tertiary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

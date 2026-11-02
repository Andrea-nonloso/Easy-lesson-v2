import 'package:flutter/material.dart';

import '../mission_engine.dart';
import '../missions.dart';
import '../store.dart';
import 'achievements.dart' show LevelCard;
import 'widgets.dart';

void openMissions(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const MissionsPage()));

String _left(Duration d) {
  if (d.inDays >= 1) return '${d.inDays} g ${d.inHours % 24} h';
  if (d.inHours >= 1) return '${d.inHours} h ${d.inMinutes % 60} min';
  return '${d.inMinutes} min';
}

/// Missioni del giorno e della settimana, con l'evento speciale se c'è.
class MissionsPage extends StatelessWidget {
  const MissionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final now = DateTime.now();
    final daily = Missions.status(store, weekly: false);
    final weekly = Missions.status(store, weekly: true);
    final ev = Missions.activeEvent(store, now);
    Widget header(String title, String sub, List<MissionStatus> list, int bonus) => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Expanded(child: SectionLabel(title)),
              Text(
                '${list.where((m) => m.done).length}/${list.length} · bonus $bonus XP · $sub',
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('Missioni')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: RefreshIndicator(
            onRefresh: () => Missions.refreshEvents(store, force: true),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                const LevelCard(),
                if (ev != null)
                  Card(
                    margin: const EdgeInsets.only(top: 12),
                    color: scheme.tertiaryContainer,
                    child: ListTile(
                      leading: Text(ev.emoji, style: const TextStyle(fontSize: 30)),
                      title: Text(ev.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(
                        '${ev.description.isEmpty ? '' : '${ev.description}\n'}'
                        '${ev.multiplier > 1 ? 'XP delle missioni ×${ev.multiplier.toStringAsFixed(ev.multiplier % 1 == 0 ? 0 : 1)} · ' : ''}'
                        'finisce tra ${_left(ev.ends.difference(now))}',
                      ),
                    ),
                  ),
                header('Oggi', 'nuove tra ${_left(Missions.untilNext(now, weekly: false))}', daily, dailyBonusXp),
                if (daily.isEmpty) const _Empty(),
                for (final m in daily) _MissionTile(m),
                header('Questa settimana', 'nuove tra ${_left(Missions.untilNext(now, weekly: true))}', weekly,
                    weeklyBonusXp),
                if (weekly.isEmpty) const _Empty(),
                for (final m in weekly) _MissionTile(m),
                const SizedBox(height: 12),
                Text(
                  'Le missioni sono uguali per tutti e cambiano a mezzanotte (giornaliere) e il lunedì (settimanali). '
                  'Contano le cose fatte da quando la missione è uscita.',
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(12),
        child: Text('Le missioni arrivano tra un attimo…'),
      );
}

class _MissionTile extends StatelessWidget {
  const _MissionTile(this.m);
  final MissionStatus m;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: m.done ? scheme.primaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Row(
          children: [
            Text(m.done ? '✅' : m.def.emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m.def.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: m.def.goal == 0 ? 1 : m.progress / m.def.goal,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('+${m.xp} XP', style: TextStyle(fontWeight: FontWeight.w800, color: scheme.primary)),
                Text('${m.progress}/${m.def.goal}', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Riquadro compatto per il profilo: quante missioni di oggi sono fatte.
class MissionsSummaryTile extends StatelessWidget {
  const MissionsSummaryTile({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final d = Missions.status(store, weekly: false);
    final w = Missions.status(store, weekly: true);
    final ev = Missions.activeEvent(store);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.flag_outlined, color: scheme.primary),
      title: Text(ev == null ? 'Missioni' : 'Missioni · ${ev.emoji} ${ev.title}'),
      subtitle: Text('Oggi ${d.where((m) => m.done).length}/${d.length} · settimana ${w.where((m) => m.done).length}/${w.length}'),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => openMissions(context),
    );
  }
}

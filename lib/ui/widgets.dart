import 'package:flutter/material.dart';

import '../models.dart';
import 'theme.dart';
import '../i18n.dart';

/// Colori stabili per materia (stessa materia = stesso colore).
class SubjectColors {
  const SubjectColors(this.bg, this.fg, this.accent);
  final Color bg;
  final Color fg;
  final Color accent;

  static const _hues = <double>[145, 205, 262, 330, 24, 45, 175, 228, 292, 355, 95, 12];

  static SubjectColors of(String key, Brightness b) {
    var h = 0;
    for (final c in key.toUpperCase().codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    final hue = _hues[h % _hues.length];
    final dark = b == Brightness.dark;
    return SubjectColors(
      HSLColor.fromAHSL(1, hue, dark ? 0.28 : 0.75, dark ? 0.19 : 0.94).toColor(),
      HSLColor.fromAHSL(1, hue, dark ? 0.45 : 0.55, dark ? 0.90 : 0.20).toColor(),
      HSLColor.fromAHSL(1, hue, 0.62, dark ? 0.62 : 0.46).toColor(),
    );
  }
}

String relativeTime(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'adesso';
  if (d.inMinutes < 60) return tr('${d.inMinutes} min fa', '${d.inMinutes} min ago');
  if (d.inHours < 24) return tr('${d.inHours} h fa', '${d.inHours} h ago');
  if (d.inDays == 1) return tr('ieri', 'yesterday');
  if (d.inDays < 7) return tr('${d.inDays} giorni fa', '${d.inDays} days ago');
  return '${t.day}/${t.month}/${t.year}';
}

class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 44});
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scheme.primary, Color.lerp(scheme.primary, scheme.tertiary, 0.6)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(easyIcon, color: scheme.onPrimary, size: size * 0.62),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 44, color: scheme.onPrimaryContainer),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
              ),
              if (action != null) ...[const SizedBox(height: 24), action!],
            ],
          ),
        ),
      ),
    );
  }
}

class TagChip extends StatelessWidget {
  const TagChip({super.key, required this.icon, required this.label, required this.color, this.dense = false});
  final IconData icon;
  final String label;
  final Color color;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 6 : 8, vertical: dense ? 1 : 3),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: dense ? 12 : 14, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: dense ? 11 : 12.5,
                fontWeight: FontWeight.w500,
                color: color,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Chip per laboratorio e sostegno di una lezione.
List<Widget> lessonTags(Lesson l, Color color, {bool dense = false}) => [
      if (l.lab.isNotEmpty) TagChip(icon: Icons.science_outlined, label: l.lab, color: color, dense: dense),
      for (final s in l.sostegno)
        TagChip(icon: Icons.accessibility_new, label: s, color: color, dense: dense),
    ];

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          letterSpacing: 1.1,
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import 'dev_page.dart';

/// Icona e nome breve di un laboratorio, ricavati dal nome nell'orario
/// (es. "W Chim biennio" → 🧪 Chimica, "E Fisica" → ⚛️ Fisica).
class LabInfo {
  const LabInfo(this.emoji, this.kind);
  final String emoji;
  final String kind;
}

LabInfo labInfo(String lab) {
  final l = ' ${lab.toLowerCase()} ';
  bool has(String s) => l.contains(s);
  if (has('microb') || has('bioc')) return const LabInfo('🔬', 'Microbiologia');
  if (has('chim')) return const LabInfo('🧪', 'Chimica');
  if (has('fisica') || has(' fis ')) return const LabInfo('⚛️', 'Fisica');
  if (has('igiene')) return const LabInfo('🩺', 'Igiene');
  if (has(' inf') || has('turing') || has('caff')) return const LabInfo('💻', 'Informatica');
  if (has('sistemi')) return const LabInfo('🛰️', 'Sistemi e reti');
  if (has('enel') || has('tpsee') || has('elettr')) return const LabInfo('⚡', 'Elettrotecnica');
  if (has('multimed')) return const LabInfo('🎬', 'Multimedia');
  if (has(' pal')) return const LabInfo('🏀', 'Palestra');
  if (has('cad')) return const LabInfo('📐', 'CAD');
  if (has('moda')) return const LabInfo('🧵', 'Moda');
  if (has('ttrg')) return const LabInfo('✏️', 'Disegno tecnico');
  if (has('macc') || has('tma') || has('mecc')) return const LabInfo('⚙️', 'Meccanica');
  return const LabInfo('🔧', 'Laboratorio');
}

/// Docenti presenti in quell'ora (più di uno = compresenza).
int teacherCount(Lesson l) =>
    l.details.isEmpty ? (l.isEmpty ? 0 : 1) : l.details.first.split(' · ').where((s) => s.trim().isNotEmpty).length;

/// Badge del laboratorio con la sua icona. In modalità compatta mostra solo l'icona.
class LabBadge extends StatelessWidget {
  const LabBadge(this.lab, {super.key, this.dense = false});

  final String lab;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final info = labInfo(lab);
    final color = Theme.of(context).colorScheme.tertiary;
    return Tooltip(
      message: '${info.kind} · $lab',
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: dense ? 4 : 7, vertical: dense ? 0 : 1),
        decoration: BoxDecoration(
          color: color.withAlpha(24),
          border: Border.all(color: color.withAlpha(90)),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          dense ? info.emoji : '${info.emoji} $lab',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: color, fontSize: dense ? 10 : 11, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

/// Badge "2 prof" quando nell'ora ci sono più docenti (compresenza).
class CompresenzaBadge extends StatelessWidget {
  const CompresenzaBadge(this.count, {super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Tooltip(
      message: 'Compresenza: $count docenti in quest\'ora',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: color.withAlpha(22),
          border: Border.all(color: color.withAlpha(80)),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          '👥 $count prof',
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Easter egg

const _battute = [
  'Il prof di matematica ha un problema. Anzi, ne ha 40 da assegnare per domani.',
  'La ricreazione dura 10 minuti. La fila alle macchinette 11.',
  'Il lab di chimica: dove le cose esplodono "per scopi didattici". 🧪',
  'Fisica nucleare? Qui al massimo spacchiamo i capelli in quattro. ⚛️',
  'Nessun orario è stato maltrattato durante lo sviluppo di questa app.',
  'Se stai leggendo questo, la 7ª ora non è ancora finita. Coraggio.',
];

/// La vecchia sorpresa: una battuta a caso (ora nelle opzioni sviluppatore).
void showRandomJoke(BuildContext context) {
  final battuta = _battute[math.Random().nextInt(_battute.length)];
  showDialog<void>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('🎉 Easter egg'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🧪 ⚛️ 🔬 💻 ⚡ 🏀 📐 ⚙️', style: TextStyle(fontSize: 26)),
          const SizedBox(height: 14),
          Text(battuta),
          const SizedBox(height: 14),
          const Text('Passa in 1A IT e dì la parola d\'ordine: "Easy Lesson".'),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Ahah, ok')),
      ],
    ),
  );
}

/// Firma in fondo alle impostazioni. 7 tocchi sulla foglia = opzioni sviluppatore.
class CreditsFooter extends StatefulWidget {
  const CreditsFooter({super.key, required this.version});

  final String version;

  @override
  State<CreditsFooter> createState() => _CreditsFooterState();
}

class _CreditsFooterState extends State<CreditsFooter> {
  int _taps = 0;

  void _tap() {
    _taps++;
    final messenger = ScaffoldMessenger.of(context);
    final store = StoreScope.read(context);
    if (_taps < 7) {
      if (_taps >= 4) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            duration: const Duration(milliseconds: 700),
            content: Text(store.devMode
                ? 'Le opzioni sviluppatore sono già attive 😉'
                : 'Ancora ${7 - _taps} tocchi per diventare sviluppatore…'),
          ));
      }
      return;
    }
    _taps = 0;
    messenger.hideCurrentSnackBar();
    if (!store.devMode) {
      store.setDevMode(true);
      messenger.showSnackBar(const SnackBar(content: Text('🧪 Ora sei uno sviluppatore! Opzioni sviluppatore sbloccate')));
    }
    openDevPage(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        children: [
          GestureDetector(
            onTap: _tap,
            child: const Text('🍃', style: TextStyle(fontSize: 22)),
          ),
          const SizedBox(height: 6),
          Text(
            'Fatta da Andrea Bonanno',
            textAlign: TextAlign.center,
            style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            'Venite in 1A IT a farmi i complimenti 😎',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
          const SizedBox(height: 2),
          Text(
            "PS: ringraziate anche Daniele D'Alonzo, che ha creato Easy Lesson 🙏",
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: muted, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 10),
          Text(
            widget.version.isEmpty ? '' : 'Versione ${widget.version}',
            style: theme.textTheme.labelSmall?.copyWith(color: muted),
          ),
        ],
      ),
    );
  }
}

/// "Dove sei adesso": laboratorio della lezione in corso, nella card in alto.
class PlacePill extends StatelessWidget {
  const PlacePill(this.lab, {super.key, required this.color});

  final String lab;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(38),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '📍 ${labInfo(lab).emoji} $lab',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: color, fontSize: 13.5, fontWeight: FontWeight.w700),
      ),
    );
  }
}

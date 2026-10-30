import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// Mette lo sfondo del tema dietro a tutta l'app (usato in MaterialApp.builder).
class AppBackdrop extends StatelessWidget {
  const AppBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    if (p.backdrop == BackdropKind.none) return child;
    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedBackdrop(kind: p.backdrop, base: p.background, colors: p.backdropColors),
        child,
      ],
    );
  }
}

/// Sfondo in movimento lento: macchie di colore, sfumature che ruotano,
/// tinta unita che cambia, stelle o onde. Rispetta "riduci animazioni" del sistema.
class AnimatedBackdrop extends StatefulWidget {
  const AnimatedBackdrop({
    super.key,
    required this.kind,
    required this.base,
    required this.colors,
    this.period = const Duration(seconds: 24),
  });

  final BackdropKind kind;
  final Color base;
  final List<Color> colors;
  final Duration period;

  @override
  State<AnimatedBackdrop> createState() => _AnimatedBackdropState();
}

class _AnimatedBackdropState extends State<AnimatedBackdrop> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.period);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduce) {
      _c.stop();
      _c.value = 0.3;
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _BackdropPainter(widget.kind, widget.base, widget.colors, _c),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _BackdropPainter extends CustomPainter {
  _BackdropPainter(this.kind, this.base, this.colors, this.anim) : super(repaint: anim);

  final BackdropKind kind;
  final Color base;
  final List<Color> colors;
  final Animation<double> anim;

  static final _stars = List.generate(90, (i) {
    final r = math.Random(i * 7919 + 13);
    return (r.nextDouble(), r.nextDouble(), r.nextDouble() * 1.4 + 0.4, r.nextDouble());
  });

  @override
  void paint(Canvas canvas, Size size) {
    final t = anim.value;
    final rect = Offset.zero & size;
    final cols = colors.isEmpty ? [base] : colors;
    canvas.drawRect(rect, Paint()..color = base);

    switch (kind) {
      case BackdropKind.none:
        return;

      case BackdropKind.pulse:
        // Tinta unita che passa lentamente da un colore all'altro
        final pos = t * cols.length;
        final i = pos.floor() % cols.length;
        final f = Curves.easeInOut.transform(pos - pos.floor());
        canvas.drawRect(rect, Paint()..color = Color.lerp(cols[i], cols[(i + 1) % cols.length], f)!);

      case BackdropKind.gradient:
        // Sfumatura che ruota
        final a = t * 2 * math.pi;
        canvas.drawRect(
          rect,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment(math.cos(a), math.sin(a)),
              end: Alignment(-math.cos(a), -math.sin(a)),
              colors: cols,
            ).createShader(rect),
        );

      case BackdropKind.blobs:
        // Macchie di colore che si muovono lentamente
        final r = math.max(size.width, size.height) * 0.55;
        for (var i = 0; i < cols.length; i++) {
          final ph = t * 2 * math.pi;
          final c = Offset(
            size.width * (0.5 + 0.38 * math.sin(ph + i * 2.1)),
            size.height * (0.5 + 0.38 * math.cos(ph * (i.isEven ? 1 : -1) + i * 1.3)),
          );
          canvas.drawCircle(
            c,
            r,
            Paint()
              ..shader = RadialGradient(
                colors: [cols[i].withAlpha(150), cols[i].withAlpha(0)],
              ).createShader(Rect.fromCircle(center: c, radius: r)),
          );
        }

      case BackdropKind.stars:
        // Nebulosa lenta + stelle che brillano
        final nr = math.max(size.width, size.height) * 0.6;
        for (var i = 0; i < cols.length; i++) {
          final ph = t * 2 * math.pi + i * math.pi;
          final c = Offset(size.width * (0.5 + 0.3 * math.cos(ph)), size.height * (0.4 + 0.25 * math.sin(ph)));
          canvas.drawCircle(
            c,
            nr,
            Paint()
              ..shader = RadialGradient(colors: [cols[i].withAlpha(110), cols[i].withAlpha(0)])
                  .createShader(Rect.fromCircle(center: c, radius: nr)),
          );
        }
        final star = Paint();
        for (final (x, y, s, ph) in _stars) {
          final a = 0.25 + 0.75 * (0.5 + 0.5 * math.sin((t * 6 + ph) * 2 * math.pi));
          star.color = Colors.white.withAlpha((a * 255).round());
          canvas.drawCircle(Offset(x * size.width, y * size.height), s, star);
        }

      case BackdropKind.waves:
        // Onde che scorrono dal basso
        for (var i = 0; i < cols.length; i++) {
          final amp = 18.0 + i * 8;
          final yBase = size.height * (0.55 + i * 0.12);
          final ph = t * 2 * math.pi * (i.isEven ? 1 : -1) + i;
          final path = Path()..moveTo(0, size.height);
          for (double x = 0; x <= size.width; x += 8) {
            path.lineTo(x, yBase + amp * math.sin(x / size.width * 2 * math.pi * 1.5 + ph));
          }
          path
            ..lineTo(size.width, size.height)
            ..close();
          canvas.drawPath(path, Paint()..color = cols[i].withAlpha(90));
        }
    }
  }

  @override
  bool shouldRepaint(_BackdropPainter old) =>
      old.kind != kind || old.base != base || old.colors != colors;
}

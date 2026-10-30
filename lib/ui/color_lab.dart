import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../log.dart';
import '../store.dart';
import 'theme.dart';

// ---------------------------------------------------------------------------
// Easter egg: troppi menu dei colori

final List<DateTime> _colorMenuOpens = [];

/// Da chiamare ogni volta che si apre un menu dei colori (pagina Temi,
/// "Il tuo tema", Laboratorio colori). Alla terza volta in 10 minuti
/// mostra 30 secondi di zero personalizzazione, poi lascia proseguire.
Future<void> colorMenuGate(BuildContext context) async {
  final now = DateTime.now();
  _colorMenuOpens
    ..removeWhere((t) => now.difference(t) > const Duration(minutes: 10))
    ..add(now);
  if (_colorMenuOpens.length < 3) return;
  _colorMenuOpens.clear();
  AppLog.i('easter', 'Terzo menu dei colori in 10 minuti: 30 secondi di bianco e nero');
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.white,
    useRootNavigator: true,
    transitionDuration: const Duration(milliseconds: 150),
    pageBuilder: (context, a1, a2) => const _ZeroCustomization(),
  );
}

class _ZeroCustomization extends StatefulWidget {
  const _ZeroCustomization();

  @override
  State<_ZeroCustomization> createState() => _ZeroCustomizationState();
}

class _ZeroCustomizationState extends State<_ZeroCustomization> {
  int _left = 30;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _left--);
      if (_left <= 0) {
        t.cancel();
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const black = Color(0xFF000000);
    return PopScope(
      canPop: false,
      child: Material(
        color: const Color(0xFFFFFFFF),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'È la terza volta che apri un menù per un colore, quindi ora ti guardi '
                    '30 secondi di assolutamente zero personalizzazione. E questo scritto nero su bianco.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: black, fontSize: 22, fontWeight: FontWeight.w700, height: 1.3),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    '$_left',
                    style: const TextStyle(color: black, fontSize: 56, fontWeight: FontWeight.w700),
                  ),
                  const Text('secondi', style: TextStyle(color: black, fontSize: 16)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Valori di un colore

int _r(Color c) => (c.toARGB32() >> 16) & 0xFF;
int _g(Color c) => (c.toARGB32() >> 8) & 0xFF;
int _b(Color c) => c.toARGB32() & 0xFF;

/// "#RRGGBB"
String hexOf(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// RGB come numero decimale (es. #FFFFFF = 16777215).
int decimalOf(Color c) => c.toARGB32() & 0xFFFFFF;

String rgbOf(Color c) => 'rgb(${_r(c)}, ${_g(c)}, ${_b(c)})';

/// Rapporto di contrasto WCAG tra due colori (1 = nessun contrasto, 21 = massimo).
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

Color? _parseHex(String s) {
  var t = s.trim().replaceAll('#', '');
  if (t.length == 3) t = t.split('').map((ch) => '$ch$ch').join();
  if (t.length != 6) return null;
  final v = int.tryParse(t, radix: 16);
  return v == null ? null : Color(0xFF000000 | v);
}

Color? _parseDecimal(String s) {
  final v = int.tryParse(s.trim());
  if (v == null || v < 0) return null;
  return Color(0xFF000000 | (v & 0xFFFFFF)); // accetta anche il valore ARGB intero
}

// ---------------------------------------------------------------------------
// Selettore di colore preciso

/// Dialogo con HEX, decimale, RGB e tonalità/saturazione/luminosità.
Future<Color?> pickExactColor(BuildContext context, {required String title, required Color initial}) =>
    showDialog<Color>(
      context: context,
      builder: (_) => _ColorDialog(title: title, initial: initial),
    );

class _ColorDialog extends StatefulWidget {
  const _ColorDialog({required this.title, required this.initial});

  final String title;
  final Color initial;

  @override
  State<_ColorDialog> createState() => _ColorDialogState();
}

class _ColorDialogState extends State<_ColorDialog> {
  late Color _c = widget.initial.withAlpha(255);
  late HSVColor _hsv = HSVColor.fromColor(_c);
  late final TextEditingController _hex = TextEditingController(text: hexOf(_c));
  late final TextEditingController _dec = TextEditingController(text: '${decimalOf(_c)}');

  @override
  void dispose() {
    _hex.dispose();
    _dec.dispose();
    super.dispose();
  }

  void _set(Color c, {bool fromHex = false, bool fromDec = false, HSVColor? hsv}) {
    setState(() {
      _c = c.withAlpha(255);
      _hsv = hsv ?? HSVColor.fromColor(_c);
    });
    if (!fromHex) _hex.text = hexOf(_c);
    if (!fromDec) _dec.text = '${decimalOf(_c)}';
  }

  Widget _slider(String label, double value, double max, Color active, ValueChanged<double> onChanged,
      {String? shown}) {
    return Row(
      children: [
        SizedBox(width: 28, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))),
        Expanded(
          child: Slider(
            value: value.clamp(0, max).toDouble(),
            max: max,
            activeColor: active,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 44,
          child: Text(shown ?? value.round().toString(), textAlign: TextAlign.end),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final on = ThemeData.estimateBrightnessForColor(_c) == Brightness.dark ? Colors.white : Colors.black;
    int drops(int v) => (v / 255 * 40).round();
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 76,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: _c, borderRadius: BorderRadius.circular(16)),
                child: Text(
                  '${hexOf(_c)}  ·  ${rgbOf(_c)}',
                  style: TextStyle(color: on, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Ricetta: ${drops(_r(_c))} gocce di rosso, ${drops(_g(_c))} di verde e ${drops(_b(_c))} di blu '
                'da ½ ml, su tela di cotone bianco puro 🧵',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _hex,
                      decoration: const InputDecoration(labelText: 'HEX', isDense: true),
                      onChanged: (v) {
                        final c = _parseHex(v);
                        if (c != null) _set(c, fromHex: true);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _dec,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Decimale', isDense: true),
                      onChanged: (v) {
                        final c = _parseDecimal(v);
                        if (c != null) _set(c, fromDec: true);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _slider('R', _r(_c).toDouble(), 255, Colors.red,
                  (v) => _set(Color.fromARGB(255, v.round(), _g(_c), _b(_c)))),
              _slider('G', _g(_c).toDouble(), 255, Colors.green,
                  (v) => _set(Color.fromARGB(255, _r(_c), v.round(), _b(_c)))),
              _slider('B', _b(_c).toDouble(), 255, Colors.blue,
                  (v) => _set(Color.fromARGB(255, _r(_c), _g(_c), v.round()))),
              const Divider(),
              _slider('H', _hsv.hue, 360, _c, (v) {
                final h = _hsv.withHue(v);
                _set(h.toColor(), hsv: h);
              }, shown: '${_hsv.hue.round()}°'),
              _slider('S', _hsv.saturation * 100, 100, _c, (v) {
                final h = _hsv.withSaturation(v / 100);
                _set(h.toColor(), hsv: h);
              }, shown: '${(_hsv.saturation * 100).round()}%'),
              _slider('V', _hsv.value * 100, 100, _c, (v) {
                final h = _hsv.withValue(v / 100);
                _set(h.toColor(), hsv: h);
              }, shown: '${(_hsv.value * 100).round()}%'),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
        FilledButton(onPressed: () => Navigator.pop(context, _c), child: const Text('Usa')),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Laboratorio colori (opzioni sviluppatore)

Future<void> openThemeLab(BuildContext context) async {
  await colorMenuGate(context);
  if (!context.mounted) return;
  await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ThemeLabPage()));
}

/// Tema personalizzato con i valori esatti di ogni colore.
class ThemeLabPage extends StatefulWidget {
  const ThemeLabPage({super.key});

  @override
  State<ThemeLabPage> createState() => _ThemeLabPageState();
}

class _ThemeLabPageState extends State<ThemeLabPage> {
  late Color _seed;
  Color? _bg;
  Color? _card;
  Color? _nav;
  late String _mode;
  late String _name;
  bool _ready = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    final s = StoreScope.read(context);
    _seed = Color(s.customSeed);
    _bg = s.customBg == null ? null : Color(s.customBg!);
    _card = s.customCard == null ? null : Color(s.customCard!);
    _nav = s.customNav == null ? null : Color(s.customNav!);
    _mode = s.customMode;
    _name = s.customName;
    _ready = true;
  }

  Brightness get _brightness => switch (_mode) {
        'light' => Brightness.light,
        'dark' => Brightness.dark,
        _ => MediaQuery.platformBrightnessOf(context),
      };

  AppThemeSpec get _spec => buildCustomSpec(
        name: _name,
        seed: _seed,
        mode: _mode,
        background: _bg,
        card: _card,
        nav: _nav,
      );

  Future<void> _save() async {
    final store = StoreScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    await store.setCustomTheme(seed: _seed.toARGB32(), mode: _mode, oled: false);
    await store.setCustomColors(
      background: _bg?.toARGB32(),
      card: _card?.toARGB32(),
      nav: _nav?.toARGB32(),
    );
    messenger.showSnackBar(const SnackBar(content: Text('Tema salvato e attivato')));
  }

  void _copyCode() {
    String c(Color? x) => x == null ? 'null' : 'Color(0x${x.toARGB32().toRadixString(16).toUpperCase()})';
    final code = "AppThemeSpec(\n"
        "  id: 'nuovo', name: '$_name', seed: ${c(_seed)},\n"
        "  brightness: ${_mode == 'system' ? 'null' : 'Brightness.$_mode'},\n"
        "  background: ${c(_bg)}, card: ${c(_card)}, nav: ${c(_nav)},\n"
        "),";
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Codice del tema copiato')));
  }

  @override
  Widget build(BuildContext context) {
    final preview = buildTheme(_brightness, _spec);
    final pal = preview.extension<AppPalette>()!;
    final scheme = preview.colorScheme;
    final ratio = contrastRatio(scheme.onSurface, pal.background);

    Widget row(String label, String hint, Color shown, bool auto, ValueChanged<Color?> apply, {bool canAuto = true}) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: shown,
            shape: BoxShape.circle,
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          ),
        ),
        title: Text(label),
        subtitle: Text(
          auto ? 'Automatico ($hint) · ${hexOf(shown)}' : '${hexOf(shown)} · ${rgbOf(shown)} · ${decimalOf(shown)}',
        ),
        trailing: canAuto && !auto
            ? IconButton(
                tooltip: 'Torna automatico',
                onPressed: () => setState(() => apply(null)),
                icon: const Icon(Icons.auto_fix_high_rounded),
              )
            : const Icon(Icons.chevron_right_rounded),
        onTap: () async {
          final c = await pickExactColor(context, title: label, initial: shown);
          if (c != null && mounted) setState(() => apply(c));
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laboratorio colori'),
        actions: [
          IconButton(tooltip: 'Copia come codice', onPressed: _copyCode, icon: const Icon(Icons.code_rounded)),
          const SizedBox(width: 4),
          FilledButton(onPressed: _save, child: const Text('Salva')),
          const SizedBox(width: 12),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            children: [
              // Anteprima con il tema in costruzione
              Theme(
                data: preview,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: pal.background,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Anteprima', style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w700, fontSize: 18)),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(18)),
                        child: Text('ADESSO · Matematica',
                            style: TextStyle(color: scheme.onPrimary, fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: pal.card, borderRadius: BorderRadius.circular(18)),
                        child: Text('Card · Informatica 💻', style: TextStyle(color: scheme.onSurface)),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          FilledButton(onPressed: () {}, child: const Text('Bottone')),
                          OutlinedButton(onPressed: () {}, child: const Text('Secondario')),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 44,
                        decoration: BoxDecoration(color: pal.nav, borderRadius: BorderRadius.circular(14)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            for (final i in [Icons.home_rounded, Icons.today_rounded, Icons.search_rounded])
                              Icon(i, color: scheme.onSurfaceVariant),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Contrasto testo/sfondo: ${ratio.toStringAsFixed(1)}:1 '
                '${ratio >= 7 ? '✅ ottimo' : ratio >= 4.5 ? '✅ ok' : '⚠️ poco leggibile'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'system', label: Text('Automatico')),
                  ButtonSegment(value: 'light', label: Text('Chiaro')),
                  ButtonSegment(value: 'dark', label: Text('Scuro')),
                ],
                selected: {_mode},
                onSelectionChanged: (s) => setState(() => _mode = s.first),
              ),
              const SizedBox(height: 8),
              row('Accento', 'dal tema', _seed, false, (c) => _seed = c ?? _seed, canAuto: false),
              row('Sfondo', 'dal tema', pal.background, _bg == null, (c) => _bg = c),
              row('Card', 'dal tema', pal.card, _card == null, (c) => _card = c),
              row('Barra in basso', 'dal tema', pal.nav, _nav == null, (c) => _nav = c),
              const SizedBox(height: 8),
              Text(
                'Tocca un colore per scriverlo in HEX, RGB, decimale o tonalità/saturazione/luminosità. '
                '"Salva" lo applica come "Il tuo tema".',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../i18n.dart';
import '../log.dart';
import '../native.dart';
import '../scanner.dart';
import 'save_file_io.dart' if (dart.library.js_interop) 'save_file_web.dart';
import 'widgets.dart';

// Scanner in PDF (3.9): foto di fogli e appunti → ritaglio, rotazione, filtro → PDF. Niente va in rete.

bool get scannerSupported =>
    !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.windows);

void openScanner(BuildContext context) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ScannerPage()));

class _ScanPage {
  _ScanPage(this.original, this.edit, this.result);
  final Uint8List original;
  ScanEdit edit;
  Uint8List? result;
}

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  final List<_ScanPage> _pages = [];
  bool _busy = false;

  Future<void> _add({required bool camera}) async {
    if (_pages.length >= maxScanPages) return;
    try {
      final picked = await ImagePicker().pickImage(
        source: camera && defaultTargetPlatform == TargetPlatform.android ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 2400,
        imageQuality: 92,
      );
      if (picked == null || !mounted) return;
      final bytes = await picked.readAsBytes();
      final page = _ScanPage(bytes, const ScanEdit(), null);
      if (!mounted) return;
      final ok = await _edit(page);
      if (ok && mounted) setState(() => _pages.add(page));
    } catch (e, st) {
      AppLog.e('scanner', e, st);
    }
  }

  /// Apre l'editor; true = confermato (la pagina è elaborata).
  Future<bool> _edit(_ScanPage page) async {
    final edit = await Navigator.of(context).push<ScanEdit>(
      MaterialPageRoute(builder: (_) => _EditPage(bytes: page.original, start: page.edit)),
    );
    if (edit == null || !mounted) return false;
    setState(() => _busy = true);
    try {
      final out = await compute(processScan, (page.original, edit));
      if (out == null) return false;
      page
        ..edit = edit
        ..result = out;
      return true;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _makePdf() async {
    final messenger = ScaffoldMessenger.of(context);
    final now = DateTime.now();
    final name = 'scansione_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}.pdf';
    setState(() => _busy = true);
    try {
      final pdf = await buildScanPdf([for (final p in _pages) if (p.result != null) p.result!]);
      if (!await NativeBridge.shareImage(pdf, name)) {
        final where = await saveBytesFile(name, pdf, mime: 'application/pdf', title: tr('Salva il PDF', 'Save the PDF'));
        if (where != null) messenger.showSnackBar(SnackBar(content: Text(tr('PDF salvato', 'PDF saved'))));
      }
      AppLog.i('scanner', 'PDF di ${_pages.length} pagine (${pdf.length} byte)');
    } catch (e, st) {
      AppLog.e('scanner', e, st);
      messenger.showSnackBar(SnackBar(content: Text(tr('PDF non riuscito', 'PDF failed'))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Scanner', 'Scanner')),
        actions: [
          if (_pages.isNotEmpty)
            TextButton.icon(
              onPressed: _busy ? null : _makePdf,
              icon: const Icon(Icons.picture_as_pdf_rounded),
              label: Text(tr('Crea PDF', 'Make PDF')),
            ),
        ],
      ),
      floatingActionButton: _pages.length >= maxScanPages
          ? null
          : FloatingActionButton.extended(
              onPressed: _busy ? null : () => _add(camera: true),
              icon: const Icon(Icons.add_a_photo_rounded),
              label: Text(_pages.isEmpty ? tr('Scatta', 'Take photo') : tr('Pagina', 'Page')),
            ),
      body: Stack(children: [
        if (_pages.isEmpty)
          EmptyState(
            icon: Icons.document_scanner_rounded,
            title: tr('Scansiona fogli e appunti', 'Scan sheets and notes'),
            message: tr('Fai una foto per pagina: la ritagli, la raddrizzi e diventa un PDF da mandare o salvare. Tutto resta sul telefono.',
                'Take one photo per page: crop it, straighten it and it becomes a PDF to send or save. Everything stays on the phone.'),
            action: OutlinedButton.icon(
              onPressed: _busy ? null : () => _add(camera: false),
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(tr('Dalla galleria', 'From gallery')),
            ),
          )
        else
          ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            itemCount: _pages.length,
            onReorderItem: (a, b) => setState(() => _pages.insert(b, _pages.removeAt(a))),
            itemBuilder: (context, i) {
              final p = _pages[i];
              return Card(
                key: ObjectKey(p),
                child: ListTile(
                  contentPadding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(width: 56, height: 72, child: Image.memory(p.result!, fit: BoxFit.cover, cacheWidth: 160)),
                  ),
                  title: Text(tr('Pagina ${i + 1}', 'Page ${i + 1}')),
                  subtitle: Text(switch (p.edit.filter) {
                    ScanFilter.document => tr('Documento', 'Document'),
                    ScanFilter.gray => tr('Grigio', 'Grey'),
                    ScanFilter.original => tr('Originale', 'Original'),
                  }),
                  onTap: _busy ? null : () => _edit(p).then((_) => setState(() {})),
                  trailing: IconButton(
                    tooltip: tr('Togli', 'Remove'),
                    onPressed: () => setState(() => _pages.removeAt(i)),
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ),
              );
            },
          ),
        if (_busy) const Positioned.fill(child: ColoredBox(color: Color(0x33000000), child: Center(child: CircularProgressIndicator()))),
      ]),
    );
  }
}

/// Editor di una pagina: ritaglio con i quattro angoli, rotazione, filtro.
class _EditPage extends StatefulWidget {
  const _EditPage({required this.bytes, required this.start});
  final Uint8List bytes;
  final ScanEdit start;

  @override
  State<_EditPage> createState() => _EditPageState();
}

class _EditPageState extends State<_EditPage> {
  late ScanEdit _e = widget.start;
  Size? _imgSize;

  @override
  void initState() {
    super.initState();
    decodeImageFromList(widget.bytes).then((im) {
      if (mounted) setState(() => _imgSize = Size(im.width.toDouble(), im.height.toDouble()));
    });
  }

  void _rotate() => setState(() {
        // Ruotando, il ritaglio gira con l'immagine.
        _e = _e.copyWith(turns: (_e.turns + 1) % 4, left: 1 - _e.bottom, top: _e.left, right: 1 - _e.top, bottom: _e.right);
      });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = _imgSize;
    final rotated = s == null ? null : (_e.turns.isOdd ? Size(s.height, s.width) : s);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(tr('Ritaglia', 'Crop')),
        actions: [
          IconButton(tooltip: tr('Ruota', 'Rotate'), onPressed: _rotate, icon: const Icon(Icons.rotate_right_rounded)),
          IconButton(
            tooltip: tr('Tutta la foto', 'Whole photo'),
            onPressed: () => setState(() => _e = _e.copyWith(left: 0, top: 0, right: 1, bottom: 1)),
            icon: const Icon(Icons.crop_free_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: rotated == null
                ? const Center(child: CircularProgressIndicator())
                : Padding(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: rotated.width / rotated.height,
                        child: LayoutBuilder(builder: (context, box) {
                          final w = box.maxWidth, h = box.maxHeight;
                          Widget handle(double fx, double fy, void Function(double dx, double dy) move) => Positioned(
                                left: fx * w - 18,
                                top: fy * h - 18,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onPanUpdate: (d) => setState(() => move(d.delta.dx / w, d.delta.dy / h)),
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    alignment: Alignment.center,
                                    child: Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                                    ),
                                  ),
                                ),
                              );
                          double c(double v, double lo, double hi) => v.clamp(lo, hi).toDouble();
                          return Stack(clipBehavior: Clip.none, children: [
                            Positioned.fill(child: RotatedBox(quarterTurns: _e.turns, child: Image.memory(widget.bytes, fit: BoxFit.fill))),
                            Positioned.fill(child: CustomPaint(painter: _CropShade(_e, scheme.primary))),
                            handle(_e.left, _e.top, (dx, dy) => _e = _e.copyWith(left: c(_e.left + dx, 0, _e.right - 0.1), top: c(_e.top + dy, 0, _e.bottom - 0.1))),
                            handle(_e.right, _e.top, (dx, dy) => _e = _e.copyWith(right: c(_e.right + dx, _e.left + 0.1, 1), top: c(_e.top + dy, 0, _e.bottom - 0.1))),
                            handle(_e.left, _e.bottom, (dx, dy) => _e = _e.copyWith(left: c(_e.left + dx, 0, _e.right - 0.1), bottom: c(_e.bottom + dy, _e.top + 0.1, 1))),
                            handle(_e.right, _e.bottom, (dx, dy) => _e = _e.copyWith(right: c(_e.right + dx, _e.left + 0.1, 1), bottom: c(_e.bottom + dy, _e.top + 0.1, 1))),
                          ]);
                        }),
                      ),
                    ),
                  ),
          ),
          Container(
            color: scheme.surface,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SegmentedButton<ScanFilter>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: ScanFilter.document, label: Text(tr('Documento', 'Document')), icon: const Icon(Icons.description_outlined)),
                  ButtonSegment(value: ScanFilter.gray, label: Text(tr('Grigio', 'Grey')), icon: const Icon(Icons.filter_b_and_w_rounded)),
                  ButtonSegment(value: ScanFilter.original, label: Text(tr('Originale', 'Original')), icon: const Icon(Icons.image_outlined)),
                ],
                selected: {_e.filter},
                onSelectionChanged: (v) => setState(() => _e = _e.copyWith(filter: v.first)),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(_e),
                icon: const Icon(Icons.check_rounded),
                label: Text(tr('Fatto', 'Done')),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _CropShade extends CustomPainter {
  _CropShade(this.e, this.color);
  final ScanEdit e;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTRB(e.left * size.width, e.top * size.height, e.right * size.width, e.bottom * size.height);
    final shade = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRect(r);
    canvas.drawPath(shade, Paint()..color = const Color(0x99000000));
    canvas.drawRect(r, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color);
  }

  @override
  bool shouldRepaint(_CropShade old) => old.e != e;
}

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../cloud.dart';
import '../live.dart';
import '../native.dart';
import '../social.dart';
import '../stickers.dart';
import '../store.dart';
import '../i18n.dart';

// 3.8: foto, sticker e GIF dei grandi (chat dei grandi e privati). Solo per i 18+ verificati.

/// Un'immagine di un messaggio: la foto (si tocca per vederla grande) o lo sticker (senza fondo).
class AdultImage extends StatelessWidget {
  const AdultImage({super.key, required this.media, required this.kind});
  final String media;
  final String kind;

  @override
  Widget build(BuildContext context) {
    final sticker = kind == 'sticker';
    final store = StoreScope.read(context);
    return FutureBuilder<Uint8List>(
      future: Social.mediaBytes(store, media),
      builder: (context, snap) {
        final size = sticker ? 130.0 : 230.0;
        if (!snap.hasData) {
          return SizedBox(
            width: size,
            height: sticker ? size : size * 0.75,
            child: Center(
              child: snap.hasError
                  ? const Icon(Icons.broken_image_outlined)
                  : const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          );
        }
        final img = Image.memory(snap.data!, gaplessPlayback: true, fit: BoxFit.contain);
        if (sticker) return SizedBox(width: size, height: size, child: img);
        return GestureDetector(
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => Scaffold(
              backgroundColor: Colors.black,
              appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
              body: Center(child: InteractiveViewer(maxScale: 5, child: Image.memory(snap.data!))),
            ),
          )),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: ConstrainedBox(constraints: BoxConstraints(maxWidth: size, maxHeight: size * 1.3), child: img),
          ),
        );
      },
    );
  }
}

/// Sceglie (o scatta) una foto e la carica. Restituisce la chiave da mandare, o null.
/// La foto si rimpicciolisce sul telefono; il server toglie comunque i dati nascosti (posizione, modello…).
Future<String?> pickAndUploadPhoto(BuildContext context) async {
  final store = StoreScope.read(context);
  final mobile = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  ImageSource? source = ImageSource.gallery;
  if (mobile) {
    source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.photo_library_outlined), title: Text(tr('Galleria', 'Gallery')), onTap: () => Navigator.pop(c, ImageSource.gallery)),
          ListTile(leading: const Icon(Icons.photo_camera_outlined), title: Text(tr('Fotocamera', 'Camera')), onTap: () => Navigator.pop(c, ImageSource.camera)),
        ]),
      ),
    );
  }
  if (source == null) return null;
  final picked = await ImagePicker().pickImage(source: source, maxWidth: 1600, maxHeight: 1600, imageQuality: 80);
  if (picked == null) return null;
  final bytes = await picked.readAsBytes();
  return Social.uploadMedia(store, bytes);
}

/// Pannello degli sticker: tocca per mandare, tieni premuto per toglierlo; Importa (file, .wastickers) e,
/// su Android, "Da WhatsApp". Restituisce lo sticker scelto.
Future<Sticker?> showStickerPicker(BuildContext context) => showModalBottomSheet<Sticker>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const _StickerPicker(),
    );

class _StickerPicker extends StatefulWidget {
  const _StickerPicker();
  @override
  State<_StickerPicker> createState() => _StickerPickerState();
}

class _StickerPickerState extends State<_StickerPicker> {
  List<Sticker>? _all;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final l = await StickerStore.list();
    if (mounted) setState(() => _all = List.of(l));
  }

  void _toast(String t) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(t)));

  Future<void> _import() async {
    final res = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const ['webp', 'png', 'gif', 'wastickers', 'zip'],
      withData: true,
    );
    if (res == null) return;
    setState(() => _busy = true);
    final n = await StickerStore.addFiles([for (final f in res.files) if (f.bytes != null) (f.name, f.bytes!)]);
    setState(() => _busy = false);
    await _reload();
    _toast(n == 0 ? tr('Nessuno sticker nuovo (WebP, PNG o GIF fino a 1 MB)', 'No new stickers (WebP, PNG or GIF up to 1 MB)') : tr('Aggiunti $n sticker', 'Added $n stickers'));
  }

  Future<void> _whatsApp() async {
    setState(() => _busy = true);
    try {
      final paths = await NativeBridge.importWhatsAppStickers();
      final n = await StickerStore.addPaths(paths);
      await _reload();
      _toast(paths.isEmpty ? tr('Niente importato', 'Nothing imported') : (n == 0 ? tr('Li avevi già tutti', 'You already had them all') : tr('Aggiunti $n sticker da WhatsApp', 'Added $n stickers from WhatsApp')));
    } catch (e) {
      _toast(tr('Non riesco a leggere la cartella di WhatsApp: scegli i file a mano con "Importa"', 'Can\'t read the WhatsApp folder: pick the files by hand with "Import"'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = _all;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.6,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 4),
            child: Row(children: [
              Expanded(child: Text(tr('Sticker e GIF', 'Stickers and GIFs'), style: Theme.of(context).textTheme.titleMedium)),
              if (NativeBridge.supported)
                TextButton.icon(onPressed: _busy ? null : _whatsApp, icon: const Icon(Icons.download_rounded), label: Text(tr('Da WhatsApp', 'From WhatsApp'))),
              TextButton.icon(onPressed: _busy ? null : _import, icon: const Icon(Icons.add_photo_alternate_outlined), label: Text(tr('Importa', 'Import'))),
            ]),
          ),
          if (_busy) const LinearProgressIndicator(),
          Expanded(
            child: all == null
                ? const Center(child: CircularProgressIndicator())
                : all.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            '${tr('Ancora niente. Importa i tuoi sticker (WebP, PNG, GIF o pacchetti .wastickers)', 'Nothing yet. Import your stickers (WebP, PNG, GIF or .wastickers packs)')}'
                            '${kIsWeb ? '' : tr(', anche dalla cartella di WhatsApp', ', also from the WhatsApp folder')}.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : GridView.extent(
                        maxCrossAxisExtent: 96,
                        padding: const EdgeInsets.all(12),
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        children: [
                          for (final s in all)
                            InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => Navigator.pop(context, s),
                              onLongPress: () async {
                                await StickerStore.remove(s.id);
                                await _reload();
                              },
                              child: Padding(padding: const EdgeInsets.all(4), child: Image.memory(s.bytes, gaplessPlayback: true)),
                            ),
                        ],
                      ),
          ),
          if (kIsWeb)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(tr('Sul web gli sticker restano solo finché la pagina è aperta.', 'On the web, stickers only stay while the page is open.'), style: const TextStyle(fontSize: 12)),
            ),
        ]),
      ),
    );
  }
}

/// Barra per scrivere (chat dei grandi e privati): foto, sticker, testo, invio.
class AdultComposer extends StatefulWidget {
  const AdultComposer({
    super.key,
    required this.chat,
    required this.onSend,
    this.maxLength = 1000,
    this.enabled = true,
  });

  /// Chat per "sta scrivendo" ("adult" o "dm:<id>").
  final String chat;

  /// Manda: testo, oppure (testo vuoto) immagine con il suo tipo.
  final Future<void> Function({String text, String? media, String kind}) onSend;
  final int maxLength;
  final bool enabled;

  @override
  State<AdultComposer> createState() => _AdultComposerState();
}

class _AdultComposerState extends State<AdultComposer> {
  final _text = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _toast(Object e) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(e is CloudException ? e.message : '$e')));

  Future<void> _run(Future<void> Function() f) async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      await f();
    } catch (e) {
      if (mounted) _toast(e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendText() => _run(() async {
        final t = _text.text.trim();
        if (t.isEmpty) return;
        await widget.onSend(text: t);
        _text.clear();
      });

  Future<void> _photo() => _run(() async {
        final key = await pickAndUploadPhoto(context);
        if (key != null) await widget.onSend(text: '', media: key, kind: 'photo');
      });

  Future<void> _sticker() async {
    final store = StoreScope.read(context);
    final s = await showStickerPicker(context);
    if (s == null) return;
    await _run(() async {
      final key = await Social.uploadMedia(store, s.bytes, kind: 'sticker');
      await widget.onSend(text: '', media: key, kind: 'sticker');
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Live.instance,
      builder: (context, _) {
        final on = widget.enabled && !Live.instance.paused && !_sending;
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 8, 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              IconButton(tooltip: tr('Foto', 'Photo'), onPressed: on ? _photo : null, icon: const Icon(Icons.photo_camera_outlined)),
              IconButton(tooltip: tr('Sticker e GIF', 'Stickers and GIFs'), onPressed: on ? _sticker : null, icon: const Icon(Icons.emoji_emotions_outlined)),
              Expanded(
                child: TextField(
                  controller: _text,
                  enabled: widget.enabled,
                  minLines: 1,
                  maxLines: 5,
                  maxLength: widget.maxLength,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(hintText: tr('Scrivi un messaggio', 'Write a message'), counterText: '', border: const OutlineInputBorder()),
                  onSubmitted: (_) => _sendText(),
                  onChanged: (_) => Live.instance.typing(widget.chat),
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filled(
                tooltip: tr('Manda', 'Send'),
                onPressed: on ? _sendText : null,
                icon: _sending
                    ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send_rounded),
              ),
            ]),
          ),
        );
      },
    );
  }
}

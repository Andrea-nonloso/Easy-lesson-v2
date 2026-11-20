import 'package:flutter/material.dart';

import '../cloud.dart';
import '../i18n.dart';
import '../social.dart';
import '../store.dart';
import 'adult_media.dart';

// 3.11: la mia foto profilo. Si vede solo nella chat dei grandi e nei privati, dopo l'ok della moderazione.

class MyPhotoPage extends StatefulWidget {
  const MyPhotoPage({super.key});
  @override
  State<MyPhotoPage> createState() => _MyPhotoPageState();
}

class _MyPhotoPageState extends State<MyPhotoPage> {
  MyPhoto? _me;
  Object? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final me = await Social.myPhoto(StoreScope.read(context));
      if (mounted) {
        setState(() {
          _me = me;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _toast(Object e) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(e is CloudException ? e.message : '$e')));

  Future<void> _run(Future<void> Function() f, String done) async {
    setState(() => _busy = true);
    try {
      await f();
      if (mounted) _toast(done);
      await _load();
    } catch (e) {
      if (mounted) _toast(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _choose() async {
    final store = StoreScope.read(context);
    final bytes = await pickPhotoBytes(context, max: 1024);
    if (bytes == null || !mounted) return;
    await _run(() => Social.uploadMyPhoto(store, bytes), tr('Mandata alla moderazione', 'Sent to moderation'));
  }

  @override
  Widget build(BuildContext context) {
    final me = _me;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(tr('La mia foto', 'My photo'))),
      body: me == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : Padding(padding: const EdgeInsets.all(24), child: Text(_error is CloudException ? (_error as CloudException).message : '$_error')),
            )
          : ListView(padding: const EdgeInsets.all(24), children: [
              Center(child: ProfileAvatar(photo: me.photo, emoji: '🙂', radius: 64)),
              const SizedBox(height: 16),
              Text(
                tr('La foto si vede solo nella chat dei grandi e nei privati, dopo che la moderazione l\'ha controllata. '
                    'Se la togli o la cambi, la moderazione la può ancora vedere per 12 ore.',
                    'Your photo is only shown in the adults\' chat and private messages, after moderation has checked it. '
                    'If you remove or change it, moderation can still see it for 12 hours.'),
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              if (me.pending != null) ...[
                const SizedBox(height: 20),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  ProfileAvatar(photo: me.pending, emoji: '⏳', radius: 28),
                  const SizedBox(width: 12),
                  Flexible(child: Text(tr('Nuova foto: aspetta la moderazione', 'New photo: waiting for moderation'))),
                ]),
              ] else if (me.rejected) ...[
                const SizedBox(height: 20),
                Text(tr('L\'ultima foto non è stata accettata.', 'Your last photo was not accepted.'),
                    textAlign: TextAlign.center, style: TextStyle(color: scheme.error)),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _busy ? null : _choose,
                icon: const Icon(Icons.add_a_photo_outlined),
                label: Text(me.photo == null && me.pending == null ? tr('Scegli una foto', 'Choose a photo') : tr('Cambia foto', 'Change photo')),
              ),
              if (me.photo != null || me.pending != null) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _run(() => Social.deleteMyPhoto(StoreScope.read(context)), tr('Foto tolta', 'Photo removed')),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: Text(tr('Togli la foto', 'Remove photo')),
                ),
              ],
            ]),
    );
  }
}

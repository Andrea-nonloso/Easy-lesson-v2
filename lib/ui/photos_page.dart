import 'package:flutter/material.dart';

import '../models.dart';
import '../school_life.dart';
import '../store.dart';
import 'photos.dart';
import '../i18n.dart';

void openPhotos(BuildContext context, {String? subject}) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PhotosPage(subject: subject)));

/// Scatta (o sceglie) una foto e la attacca alla lezione [subject] del giorno [date].
Future<void> addLessonPhoto(BuildContext context, {required String subject, DateTime? date, bool camera = true}) async {
  final store = StoreScope.read(context);
  final path = await LessonPhotos.take(context, camera: camera);
  if (path == null) return;
  await store.addPhoto(date: date ?? DateTime.now(), subject: subject, path: path);
}

/// Striscia di foto di una materia (nella scheda della lezione).
class PhotoStrip extends StatelessWidget {
  const PhotoStrip({super.key, required this.subject});
  final String subject;

  @override
  Widget build(BuildContext context) {
    if (!LessonPhotos.supported) return const SizedBox();
    final store = StoreScope.of(context);
    final list = store.photos.where((p) => p.subject == subject).toList();
    return SizedBox(
      height: 84,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _AddTile(icon: Icons.photo_camera_outlined, onTap: () => addLessonPhoto(context, subject: subject)),
          _AddTile(
            icon: Icons.photo_library_outlined,
            onTap: () => addLessonPhoto(context, subject: subject, camera: false),
          ),
          for (final p in list)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                onTap: () => _viewPhoto(context, p),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(width: 84, height: 84, child: LessonPhotos.image(p.path)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            ),
            child: Icon(icon, size: 28),
          ),
        ),
      );
}

void _viewPhoto(BuildContext context, LessonPhoto p) {
  final store = StoreScope.read(context);
  Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (c) => Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${p.subject} · ${p.date.day}/${p.date.month}'),
        actions: [
          IconButton(
            tooltip: tr('Elimina', 'Delete'),
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () async {
              await store.removePhoto(p);
              await LessonPhotos.delete(p.path);
              if (c.mounted) Navigator.pop(c);
            },
          ),
        ],
      ),
      body: InteractiveViewer(
        maxScale: 6,
        child: Center(child: LessonPhotos.image(p.path, fit: BoxFit.contain)),
      ),
    ),
  ));
}

class PhotosPage extends StatelessWidget {
  const PhotosPage({super.key, this.subject});
  final String? subject;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final list = store.photos.where((p) => subject == null || p.subject == subject).toList();
    final groups = <String, List<LessonPhoto>>{};
    for (final p in list) {
      (groups['${p.subject}|${p.date.toIso8601String()}'] ??= []).add(p);
    }
    return Scaffold(
      appBar: AppBar(title: Text(subject == null ? tr('Foto delle lezioni', 'Lesson photos') : tr('Foto · $subject', 'Photos · $subject'))),
      body: !LessonPhotos.supported
          ? Center(child: Text(tr('Le foto si possono fare dall\'app Android o Windows', 'Photos can be taken from the Android or Windows app')))
          : list.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      tr('Nessuna foto. Tocca una lezione nell\'orario e fotografa la lavagna o gli appunti 📸', 'No photos. Tap a lesson in the timetable and take a photo of the board or your notes 📸'),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final e in groups.entries) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 6),
                        child: Text(
                          '${e.value.first.subject} · ${dayNames[e.value.first.date.weekday - 1]} '
                          '${e.value.first.date.day}/${e.value.first.date.month}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final p in e.value)
                            InkWell(
                              onTap: () => _viewPhoto(context, p),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: SizedBox(width: 104, height: 104, child: LessonPhotos.image(p.path)),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
    );
  }
}

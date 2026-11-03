import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import 'profile_page.dart';
import 'theme.dart';
import 'widgets.dart';

/// Setup al primo avvio: nome, orario personale, tema preferito, codice (facoltativo).
/// Quattro passi semplici, poi si entra nella home.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _pages = PageController();
  final _nameCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();

  int _step = 0;
  bool _prof = false;
  String _query = '';
  ScheduleRef? _ref;
  String _themeId = 'auto';
  bool _saving = false;

  @override
  void dispose() {
    _pages.dispose();
    _nameCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  bool get _canGoOn => switch (_step) {
        0 => true, // il nome e' facoltativo
        1 => _ref != null,
        _ => true,
      };

  void _next() {
    if (_step < 3) {
      _pages.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    if (_saving) return;
    final store = StoreScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _saving = true;
    });
    try {
      await store.setUsername(_nameCtrl.text);
      await store.setThemeId(_themeId);
      final ref = _ref;
      if (ref != null) {
        await store.fetchSchedule(ref);
        await store.setMine(ref);
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Orario non scaricato ($e): potrai riprovare dalla home'),
      ));
    } finally {
      await store.completeSetup();
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
                  child: Row(
                    children: [
                      const AppLogo(size: 40),
                      const SizedBox(width: 12),
                      Text(
                        'Easy Lesson',
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      for (var i = 0; i < 4; i++)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i <= _step ? scheme.primary : scheme.outlineVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView(
                    controller: _pages,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (i) => setState(() => _step = i),
                    children: [
                      _NameStep(controller: _nameCtrl),
                      _ScheduleStep(
                        prof: _prof,
                        controller: _searchCtrl,
                        query: _query,
                        selected: _ref,
                        onKind: (v) => setState(() {
                          _prof = v;
                          _ref = null;
                        }),
                        onQuery: (v) => setState(() => _query = v),
                        onPick: (r) => setState(() => _ref = r),
                      ),
                      _ThemeStep(
                        selected: _themeId,
                        onPick: (id) {
                          setState(() => _themeId = id);
                          // Anteprima immediata del tema scelto.
                          StoreScope.read(context).setThemeId(id);
                        },
                      ),
                      const _AccountStep(),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Row(
                    children: [
                      if (_step > 0)
                        TextButton(
                          onPressed: () => _pages.previousPage(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOut,
                          ),
                          child: const Text('Indietro'),
                        ),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: _saving || !_canGoOn ? null : _next,
                        icon: _saving
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(strokeWidth: 2.2),
                              )
                            : Icon(_step < 3 ? Icons.arrow_forward_rounded : Icons.check_rounded),
                        label: Text(_step < 3 ? 'Continua' : 'Inizia'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ passo 1

class _NameStep extends StatelessWidget {
  const _NameStep({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
      children: [
        Text('Come ti chiami?', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(
          'Lo useremo solo per il saluto nella home. Puoi anche saltare.',
          style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: controller,
          autofocus: false,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Il tuo nome'),
          onSubmitted: (_) {},
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ passo 2

class _ScheduleStep extends StatelessWidget {
  const _ScheduleStep({
    required this.prof,
    required this.controller,
    required this.query,
    required this.selected,
    required this.onKind,
    required this.onQuery,
    required this.onPick,
  });

  final bool prof;
  final TextEditingController controller;
  final String query;
  final ScheduleRef? selected;
  final ValueChanged<bool> onKind;
  final ValueChanged<String> onQuery;
  final ValueChanged<ScheduleRef> onPick;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final all = prof ? store.docenti : store.classi;
    final q = normalizeSearch(query);
    final results = q.isEmpty
        ? all
        : all.where((n) => normalizeSearch(n).contains(q)).take(30).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Il tuo orario', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                'Scegli la tua classe o il tuo nome: verra scaricato subito e restera disponibile anche offline.',
                style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, icon: Icon(Icons.groups_rounded), label: Text('Classe')),
                  ButtonSegment(value: true, icon: Icon(Icons.person_rounded), label: Text('Docente')),
                ],
                selected: {prof},
                onSelectionChanged: (s) => onKind(s.first),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: prof ? 'Cerca il tuo cognome…' : 'Cerca la tua classe…',
                  prefixIcon: const Icon(Icons.search_rounded),
                ),
                onChanged: onQuery,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: all.isEmpty
              ? Center(
                  child: store.listsLoading
                      ? const CircularProgressIndicator()
                      : FilledButton.tonalIcon(
                          onPressed: () => store.refreshLists(),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Carica gli elenchi'),
                        ),
                )
              : results.isEmpty
              ? Center(
                  child: Text(
                    'Nessun risultato',
                    style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
                  itemCount: results.length,
                  itemBuilder: (context, i) {
                    final name = results[i];
                    final ref = ScheduleRef(name, prof: prof);
                    final isSel = selected == ref;
                    final c = SubjectColors.of(name, theme.brightness);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Material(
                        color: isSel ? scheme.primaryContainer : cardColor(context),
                        borderRadius: BorderRadius.circular(16),
                        child: ListTile(
                          dense: true,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          leading: Icon(prof ? Icons.person_rounded : Icons.groups_rounded, color: c.accent),
                          title: Text(
                            ref.displayName,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          trailing: isSel ? Icon(Icons.check_circle_rounded, color: scheme.primary) : null,
                          onTap: () => onPick(ref),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ passo 3

class _ThemeStep extends StatelessWidget {
  const _ThemeStep({required this.selected, required this.onPick});

  final String selected;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
      children: [
        Text('Scegli il tema', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(
          'Potrai cambiarlo quando vuoi dalla pagina Temi.',
          style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final t in appThemes.where((t) => !t.animated && t.id != 'contrast'))
              _ThemeChip(spec: t, selected: selected == t.id, onTap: () => onPick(t.id)),
          ],
        ),
      ],
    );
  }
}

class _ThemeChip extends StatelessWidget {
  const _ThemeChip({required this.spec, required this.selected, required this.onTap});

  final AppThemeSpec spec;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = spec.brightness == Brightness.dark;
    final bg = spec.background ?? (dark ? const Color(0xFF131313) : const Color(0xFFF4F3F7));

    return Material(
      color: cardColor(context),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant.withAlpha(120),
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: bg,
                  shape: BoxShape.circle,
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Center(
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(color: spec.seed, shape: BoxShape.circle),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                spec.name,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ passo 4

class _AccountStep extends StatelessWidget {
  const _AccountStep();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final has = StoreScope.of(context).accountCode != null;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
      children: [
        Text('Salva i tuoi progressi', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(
          has
              ? 'Fatto! Livello e obiettivi vengono salvati con il tuo codice.'
              : 'Easy Lesson ha livelli, missioni e più di 150 obiettivi. Con un codice segreto li ritrovi anche '
                  'cambiando telefono. Puoi anche saltare e farlo dopo dalle impostazioni.',
          style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        const AccountPanel(compact: true),
        const SizedBox(height: 8),
        const PrivacyLink(),
      ],
    );
  }
}

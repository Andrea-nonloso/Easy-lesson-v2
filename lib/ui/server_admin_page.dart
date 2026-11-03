import 'package:flutter/material.dart';

import '../announcements.dart';
import '../cloud.dart';
import '../log.dart';
import '../mission_engine.dart';
import '../store.dart';

/// Sviluppatore² → Server: numeri, avvisi, eventi delle missioni, pulizia.
/// Usa la sessione data dal server con la password (Cloud.devSession, 12 ore).
class ServerAdminPage extends StatelessWidget {
  const ServerAdminPage({super.key});

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 4,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Server'),
            bottom: const TabBar(isScrollable: true, tabAlignment: TabAlignment.start, tabs: [
              Tab(icon: Icon(Icons.insights_rounded), text: 'Stato'),
              Tab(icon: Icon(Icons.campaign_outlined), text: 'Avvisi'),
              Tab(icon: Icon(Icons.celebration_outlined), text: 'Eventi'),
              Tab(icon: Icon(Icons.flag_outlined), text: 'Segnalazioni'),
            ]),
          ),
          body: const TabBarView(children: [
            _StatsTab(),
            _RowsTab(table: 'announcements'),
            _RowsTab(table: 'events'),
            _ReportsTab(),
          ]),
        ),
      );
}

String _date(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

DateTime _ms(Object? v) => DateTime.fromMillisecondsSinceEpoch(v is num ? v.toInt() : 0);

void _toast(BuildContext context, String s) => ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(s)));

// ---------------------------------------------------------------------------- stato

class _StatsTab extends StatefulWidget {
  const _StatsTab();
  @override
  State<_StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<_StatsTab> {
  late Future<Map<String, dynamic>> _f = Cloud.adminStats();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _f = Cloud.adminStats());
        await _f.catchError((_) => <String, dynamic>{});
      },
      child: FutureBuilder<Map<String, dynamic>>(
        future: _f,
        builder: (context, snap) {
          if (snap.hasError) {
            return ListView(padding: const EdgeInsets.all(24), children: [
              Text('${snap.error}', style: TextStyle(color: scheme.error)),
            ]);
          }
          final s = snap.data;
          if (s == null) return const Center(child: CircularProgressIndicator());
          int n(String k) => (s[k] as num?)?.toInt() ?? 0;
          final mb = n('backupBytes') / 1048576;
          Widget row(IconData i, String t, String v) => ListTile(
                leading: Icon(i, color: scheme.primary),
                title: Text(t),
                trailing: Text(v, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              );
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              row(Icons.dns_outlined, 'Server', '${s['version']} · ${s['runtime'] == 'node' ? 'casa' : 'Cloudflare'}'),
              row(Icons.people_outline_rounded, 'Account', '${n('accounts')}'),
              row(Icons.bolt_rounded, 'Attivi negli ultimi 7 giorni', '${n('active7')}'),
              row(Icons.calendar_month_outlined, 'Attivi negli ultimi 30 giorni', '${n('active30')}'),
              row(Icons.person_add_alt_rounded, 'Nuovi in 7 giorni', '${n('new7')}'),
              row(Icons.cloud_done_outlined, 'Backup online', '${n('backups')} · ${mb.toStringAsFixed(1)} MB'),
              row(Icons.shield_outlined, 'Righe anti-abuso', '${n('limits')}'),
              row(Icons.campaign_outlined, 'Avvisi / eventi / ricompense', '${n('announcements')} / ${n('events')} / ${n('rewards')}'),
              row(Icons.badge_outlined, 'Profili (soprannomi)', '${n('profiles')}'),
              row(Icons.groups_outlined, 'Classi / compiti condivisi', '${n('classes')} / ${n('classItems')}'),
              row(Icons.flag_outlined, 'Segnalazioni aperte', '${n('openReports')}'),
              const Divider(),
              ListTile(
                leading: Icon(Icons.cleaning_services_outlined, color: scheme.primary),
                title: const Text('Pulizia adesso'),
                subtitle: const Text('Account inattivi da 2 anni, impronte IP vecchie, avvisi finiti'),
                onTap: () async {
                  try {
                    final r = await Cloud.adminCleanup();
                    AppLog.i('dev', 'Pulizia del server: $r');
                    if (!context.mounted) return;
                    _toast(context, 'Cancellati ${r['accounts']} account e ${r['limits']} righe');
                    setState(() => _f = Cloud.adminStats());
                  } on CloudException catch (e) {
                    if (context.mounted) _toast(context, e.message);
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------- avvisi ed eventi

class _RowsTab extends StatefulWidget {
  const _RowsTab({required this.table});
  final String table;
  @override
  State<_RowsTab> createState() => _RowsTabState();
}

class _RowsTabState extends State<_RowsTab> {
  late Future<List<Map<String, dynamic>>> _f = _load();
  bool get _ann => widget.table == 'announcements';

  Future<List<Map<String, dynamic>>> _load() async =>
      (await Cloud.adminRows(widget.table))..sort((a, b) => ((b['starts'] as num?) ?? 0).compareTo((a['starts'] as num?) ?? 0));

  Future<void> _reload() async {
    setState(() => _f = _load());
    // L'app si aggiorna subito, senza aspettare il prossimo giro.
    final store = StoreScope.read(context);
    if (_ann) {
      await Announcements.refresh(store, force: true);
    } else {
      await Missions.refreshEvents(store, force: true);
    }
  }

  Future<void> _save(Map<String, dynamic> row) async {
    try {
      await Cloud.adminSave(widget.table, row);
      AppLog.i('dev', 'Server: salvato ${widget.table}/${row['id']}');
      if (mounted) await _reload();
    } on CloudException catch (e) {
      if (mounted) _toast(context, e.message);
    }
  }

  Future<void> _edit([Map<String, dynamic>? row]) async {
    final out = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _ann ? _AnnouncementDialog(row: row) : _EventDialog(row: row),
    );
    if (out != null) await _save(out);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add_rounded),
        label: Text(_ann ? 'Nuovo avviso' : 'Nuovo evento'),
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _f,
          builder: (context, snap) {
            if (snap.hasError) {
              return ListView(padding: const EdgeInsets.all(24), children: [
                Text('${snap.error}', style: TextStyle(color: scheme.error)),
              ]);
            }
            final rows = snap.data;
            if (rows == null) return const Center(child: CircularProgressIndicator());
            if (rows.isEmpty) {
              return ListView(padding: const EdgeInsets.all(32), children: [
                Center(child: Text(_ann ? 'Nessun avviso' : 'Nessun evento')),
              ]);
            }
            return ListView.builder(
              padding: const EdgeInsets.only(bottom: 96),
              itemCount: rows.length,
              itemBuilder: (context, i) {
                final r = rows[i];
                final s = _ms(r['starts']);
                final e = _ms(r['ends']);
                final on = r['enabled'] == 1 || r['enabled'] == true;
                final live = on && !now.isBefore(s) && now.isBefore(e);
                final state = !on ? 'spento' : (live ? 'in corso' : (now.isBefore(s) ? 'in arrivo' : 'finito'));
                final lead = _ann
                    ? Icon(switch (r['level']) {
                        'urgent' => Icons.priority_high_rounded,
                        'warning' => Icons.warning_amber_rounded,
                        _ => Icons.campaign_outlined,
                      }, color: live ? scheme.primary : scheme.outline)
                    : Text('${r['emoji'] ?? '⭐'}', style: const TextStyle(fontSize: 24));
                return ListTile(
                  leading: lead,
                  title: Text('${r['title']}'),
                  subtitle: Text([
                    '$state · ${_date(s)} → ${_date(e)}',
                    if (!_ann) '×${r['multiplier']}${(r['daily'] ?? '').toString().isEmpty ? '' : ' · ${r['daily']}'}',
                    if (_ann && (r['max_version'] ?? r['min_version'] ?? r['platform']) != null)
                      'per: ${r['platform'] ?? 'tutti'} ${r['min_version'] ?? ''}–${r['max_version'] ?? ''}',
                  ].join('\n')),
                  isThreeLine: !_ann,
                  onTap: () => _edit(r),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) async {
                      if (v == 'toggle') {
                        await _save({...r, 'enabled': on ? 0 : 1});
                      } else if (v == 'end') {
                        await _save({...r, 'ends': DateTime.now().millisecondsSinceEpoch});
                      } else if (v == 'delete') {
                        try {
                          await Cloud.adminDelete(widget.table, '${r['id']}');
                          AppLog.i('dev', 'Server: cancellato ${widget.table}/${r['id']}');
                          if (mounted) await _reload();
                        } on CloudException catch (e) {
                          if (context.mounted) _toast(context, e.message);
                        }
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'toggle', child: Text(on ? 'Spegni' : 'Accendi')),
                      if (live) const PopupMenuItem(value: 'end', child: Text('Fallo finire adesso')),
                      const PopupMenuItem(value: 'delete', child: Text('Cancella')),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// Inizio e durata, in comune ai due moduli.
class _When extends StatelessWidget {
  const _When({required this.start, required this.days, required this.onStart, required this.onDays});
  final DateTime start;
  final double days;
  final ValueChanged<DateTime> onStart;
  final ValueChanged<double> onDays;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_rounded),
            title: Text('Dal ${_date(start)}'),
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: start,
                firstDate: DateTime.now().subtract(const Duration(days: 30)),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (d == null || !context.mounted) return;
              final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(start));
              onStart(DateTime(d.year, d.month, d.day, t?.hour ?? 0, t?.minute ?? 0));
            },
          ),
          Text('Durata: ${days < 1 ? '${(days * 24).round()} ore' : '${days.round()} giorni'}'),
          Slider(
            value: days,
            min: 0.25,
            max: 30,
            divisions: 119,
            label: days < 1 ? '${(days * 24).round()} h' : '${days.round()} g',
            onChanged: onDays,
          ),
        ],
      );
}

double _daysOf(Map<String, dynamic>? r, double fallback) {
  if (r == null) return fallback;
  final d = (_ms(r['ends']).difference(_ms(r['starts'])).inMinutes / 1440).clamp(0.25, 30.0);
  return d < 1 ? (d * 4).round() / 4 : d.roundToDouble();
}

class _AnnouncementDialog extends StatefulWidget {
  const _AnnouncementDialog({this.row});
  final Map<String, dynamic>? row;
  @override
  State<_AnnouncementDialog> createState() => _AnnouncementDialogState();
}

class _AnnouncementDialogState extends State<_AnnouncementDialog> {
  late final r = widget.row;
  late final _title = TextEditingController(text: r?['title'] as String? ?? '');
  late final _body = TextEditingController(text: r?['body'] as String? ?? '');
  late final _link = TextEditingController(text: r?['link'] as String? ?? '');
  late final _max = TextEditingController(text: r?['max_version'] as String? ?? '');
  late String _level = r?['level'] as String? ?? 'info';
  late String _platform = r?['platform'] as String? ?? '';
  late DateTime _start = r == null ? DateTime.now() : _ms(r!['starts']);
  late double _days = _daysOf(r, 2);

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(r == null ? 'Nuovo avviso' : 'Modifica avviso'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: _title, decoration: const InputDecoration(labelText: 'Titolo'), maxLength: 80),
              TextField(controller: _body, decoration: const InputDecoration(labelText: 'Testo'), maxLines: 4, minLines: 2),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'info', label: Text('Info')),
                  ButtonSegment(value: 'warning', label: Text('Attenzione')),
                  ButtonSegment(value: 'urgent', label: Text('Urgente')),
                ],
                selected: {_level},
                onSelectionChanged: (v) => setState(() => _level = v.first),
              ),
              if (_level == 'urgent')
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text('Urgente: non si può chiudere finché dura.', style: TextStyle(fontSize: 12)),
                ),
              _When(
                start: _start,
                days: _days,
                onStart: (d) => setState(() => _start = d),
                onDays: (d) => setState(() => _days = d),
              ),
              TextField(controller: _link, decoration: const InputDecoration(labelText: 'Link (facoltativo)', hintText: 'https://…')),
              TextField(
                controller: _max,
                decoration: const InputDecoration(labelText: 'Solo fino alla versione (facoltativo)', hintText: 'es. 2.6.9'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _platform,
                decoration: const InputDecoration(labelText: 'Per'),
                items: const [
                  DropdownMenuItem(value: '', child: Text('Tutti')),
                  DropdownMenuItem(value: 'android', child: Text('Android')),
                  DropdownMenuItem(value: 'windows', child: Text('Windows')),
                  DropdownMenuItem(value: 'web', child: Text('Web')),
                ],
                onChanged: (v) => setState(() => _platform = v ?? ''),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
          FilledButton(
            onPressed: () {
              if (_title.text.trim().isEmpty) return;
              final link = _link.text.trim();
              Navigator.pop(context, <String, dynamic>{
                ...?r,
                'id': r?['id'] ?? 'a${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}',
                'title': _title.text.trim(),
                'body': _body.text.trim(),
                'level': _level,
                'link': link.startsWith('http') ? link : null,
                'starts': _start.millisecondsSinceEpoch,
                'ends': _start.add(Duration(minutes: (_days * 1440).round())).millisecondsSinceEpoch,
                'max_version': _max.text.trim().isEmpty ? null : _max.text.trim(),
                'platform': _platform.isEmpty ? null : _platform,
                'enabled': r?['enabled'] ?? 1,
              });
            },
            child: const Text('Pubblica'),
          ),
        ],
      );
}

class _EventDialog extends StatefulWidget {
  const _EventDialog({this.row});
  final Map<String, dynamic>? row;
  @override
  State<_EventDialog> createState() => _EventDialogState();
}

class _EventDialogState extends State<_EventDialog> {
  late final r = widget.row;
  late final _title = TextEditingController(text: r?['title'] as String? ?? '');
  late final _desc = TextEditingController(text: r?['description'] as String? ?? '');
  late final _emoji = TextEditingController(text: r?['emoji'] as String? ?? '⭐');
  late final _daily = TextEditingController(text: r?['daily'] as String? ?? '');
  late double _x = ((r?['multiplier'] as num?) ?? 2).toDouble().clamp(1, 5);
  late DateTime _start = r == null ? DateTime.now() : _ms(r!['starts']);
  late double _days = _daysOf(r, 7);

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(r == null ? 'Nuovo evento' : 'Modifica evento'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                SizedBox(
                  width: 56,
                  child: TextField(controller: _emoji, decoration: const InputDecoration(labelText: 'Emoji'), maxLength: 4),
                ),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: _title, decoration: const InputDecoration(labelText: 'Titolo'), maxLength: 60)),
              ]),
              TextField(controller: _desc, decoration: const InputDecoration(labelText: 'Descrizione'), maxLines: 3, minLines: 1),
              const SizedBox(height: 12),
              Text('XP delle missioni ×${_x.toStringAsFixed(_x == _x.roundToDouble() ? 0 : 1)}'),
              Slider(value: _x, min: 1, max: 5, divisions: 8, onChanged: (v) => setState(() => _x = v)),
              _When(
                start: _start,
                days: _days,
                onStart: (d) => setState(() => _start = d),
                onDays: (d) => setState(() => _days = d),
              ),
              TextField(
                controller: _daily,
                decoration: const InputDecoration(
                  labelText: 'Missioni imposte (facoltativo)',
                  hintText: 'id separati da virgola, es. d_study25,d_done',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
          FilledButton(
            onPressed: () {
              if (_title.text.trim().isEmpty) return;
              Navigator.pop(context, <String, dynamic>{
                ...?r,
                'id': r?['id'] ?? 'e${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}',
                'title': _title.text.trim(),
                'description': _desc.text.trim(),
                'emoji': _emoji.text.trim().isEmpty ? '⭐' : _emoji.text.trim(),
                'starts': _start.millisecondsSinceEpoch,
                'ends': _start.add(Duration(minutes: (_days * 1440).round())).millisecondsSinceEpoch,
                'multiplier': _x,
                'daily': _daily.text.replaceAll(' ', '').isEmpty ? null : _daily.text.replaceAll(' ', ''),
                'enabled': r?['enabled'] ?? 1,
              });
            },
            child: const Text('Salva'),
          ),
        ],
      );
}

// ---------------------------------------------------------------------------- segnalazioni

class _ReportsTab extends StatefulWidget {
  const _ReportsTab();
  @override
  State<_ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<_ReportsTab> {
  late Future<List<Map<String, dynamic>>> _f = Cloud.adminReports();

  Future<void> _resolve(Map<String, dynamic> r, String action) async {
    try {
      await Cloud.adminResolve('${r['id']}', action);
      AppLog.i('dev', 'Moderazione: $action ${r['kind']}/${r['target']}');
      if (mounted) setState(() => _f = Cloud.adminReports());
    } on CloudException catch (e) {
      if (mounted) _toast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _f = Cloud.adminReports());
        await _f.catchError((_) => <Map<String, dynamic>>[]);
      },
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _f,
        builder: (context, snap) {
          if (snap.hasError) {
            return ListView(padding: const EdgeInsets.all(24), children: [
              Text('${snap.error}', style: TextStyle(color: scheme.error)),
            ]);
          }
          final list = snap.data;
          if (list == null) return const Center(child: CircularProgressIndicator());
          if (list.isEmpty) {
            return ListView(padding: const EdgeInsets.all(32), children: const [
              Center(child: Text('Nessuna segnalazione aperta 🎉')),
            ]);
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final r = list[i];
              final kind = switch (r['kind']) {
                'item' => 'Compito condiviso',
                'nickname' => 'Soprannome',
                _ => 'Classe',
              };
              final reasons = '${r['reasons'] ?? ''}'.trim();
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$kind · ${r['count']} ${r['count'] == 1 ? 'segnalazione' : 'segnalazioni'} · dal ${_date(_ms(r['first']))}',
                          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                      const SizedBox(height: 4),
                      Text('${r['text']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                      if (reasons.isNotEmpty && reasons != '|') Text('Motivi: $reasons', style: const TextStyle(fontSize: 12.5)),
                      Wrap(
                        spacing: 4,
                        children: [
                          TextButton(onPressed: () => _resolve(r, 'dismiss'), child: const Text('Va bene così')),
                          if (r['kind'] != 'class') TextButton(onPressed: () => _resolve(r, 'hide'), child: const Text('Nascondi')),
                          if (r['kind'] != 'nickname')
                            TextButton(
                              style: TextButton.styleFrom(foregroundColor: scheme.error),
                              onPressed: () => _resolve(r, 'delete'),
                              child: Text(r['kind'] == 'class' ? 'Cancella la classe' : 'Cancella'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

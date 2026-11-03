import 'dart:convert';

/// Sincronizzazione completa tra dispositivi (3.0), sopra il backup online cifrato.
///
/// Unione "a tre vie" per ogni chiave: [base] = impronte dei valori all'ultima sincronizzazione.
///   - cambiata solo qui        -> resta quella di qui (e poi si carica);
///   - cambiata solo dall'altra -> si prende quella dell'altro dispositivo;
///   - cambiata da tutte e due  -> vince l'altro dispositivo (è il backup più recente).
/// Dentro le opzioni (el.extras) si guarda chiave per chiave; contatori stat.* = il più alto,
/// obiettivi = unione. Alcune opzioni sono solo di questo dispositivo e non viaggiano mai.

/// Opzioni che restano su questo dispositivo (stato tecnico, cache, missioni del giorno).
const _localOnly = ['cloud.', 'social.at', 'mis.', 'event.', 'ann.', 'dev.', 'n.live'];

bool isLocalOnlyOption(String k) => _localOnly.any((p) => k == p || k.startsWith(p));

int syncHash(Object? v) => jsonEncode(v).hashCode;

const extrasKey = 'el.extras';

/// Impronte di tutte le chiavi (le opzioni una per una, come "el.extras/<chiave>").
Map<String, int> syncHashes(Map<String, Object?> prefs) {
  final out = <String, int>{};
  for (final e in prefs.entries) {
    if (e.key == extrasKey) {
      for (final x in _extras(e.value).entries) {
        if (!isLocalOnlyOption(x.key)) out['$extrasKey/${x.key}'] = syncHash(x.value);
      }
    } else {
      out[e.key] = syncHash(e.value);
    }
  }
  return out;
}

Map<String, Object?> _extras(Object? v) {
  try {
    final m = v is String ? jsonDecode(v) : v;
    return m is Map ? Map<String, Object?>.from(m) : {};
  } catch (_) {
    return {};
  }
}

class SyncMerge {
  SyncMerge(this.prefs, this.changed);

  /// Il risultato completo (stesse chiavi di "local" più quelle nuove).
  final Map<String, Object?> prefs;

  /// Chiavi (o "el.extras/<chiave>") prese dall'altro dispositivo.
  final List<String> changed;
}

/// Unisce [remote] (l'altro dispositivo) dentro [local].
SyncMerge mergeSync({
  required Map<String, Object?> local,
  required Map<String, Object?> remote,
  required Map<String, int> base,
}) {
  final out = Map<String, Object?>.from(local);
  final changed = <String>[];
  for (final e in remote.entries) {
    final k = e.key;
    if (k == extrasKey) continue;
    if (!local.containsKey(k) || (syncHash(e.value) != base[k] && syncHash(e.value) != syncHash(local[k]))) {
      out[k] = e.value;
      changed.add(k);
    }
  }
  if (remote.containsKey(extrasKey)) {
    final l = _extras(local[extrasKey]);
    final r = _extras(remote[extrasKey]);
    final m = Map<String, Object?>.from(l);
    for (final e in r.entries) {
      final k = e.key;
      if (isLocalOnlyOption(k)) continue;
      final lv = l[k];
      final rv = e.value;
      Object? v = rv;
      if (k.startsWith('stat.') && lv is num && rv is num) {
        v = lv > rv ? lv : rv;
      } else if (k == 'ach.done' && lv is String && rv is String) {
        v = ({...lv.split(','), ...rv.split(',')}.where((x) => x.isNotEmpty).toList()..sort()).join(',');
      } else if (l.containsKey(k) && syncHash(rv) == base['$extrasKey/$k']) {
        continue; // l'altro non l'ha toccata: vale quella di qui
      }
      if (syncHash(v) != syncHash(lv)) {
        m[k] = v;
        changed.add('$extrasKey/$k');
      }
    }
    out[extrasKey] = jsonEncode(m);
  }
  return SyncMerge(out, changed);
}

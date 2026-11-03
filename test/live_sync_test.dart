import 'dart:convert';

import 'package:easy_lesson/live_sync.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('sincronizzazione completa', () {
    final base0 = {
      'el.grades': 'A',
      'el.agenda': 'X',
      'el.extras': jsonEncode({'stat.days': 3, 'ach.done': 'a', 'n.morning': true, 'cloud.device': 'pc'}),
    };

    test('cambi da una parte sola si uniscono, conflitti: vince l altro', () {
      final base = syncHashes(base0);
      final local = {
        ...base0,
        'el.grades': 'A+B', // cambiato qui
        'el.extras': jsonEncode({'stat.days': 5, 'ach.done': 'a,b', 'n.morning': true, 'cloud.device': 'pc'}),
      };
      final remote = {
        ...base0,
        'el.agenda': 'X+Y', // cambiato sul telefono
        'el.theme': 'dark', // nuovo
        'el.extras': jsonEncode({'stat.days': 4, 'ach.done': 'a,c', 'n.morning': false, 'cloud.device': 'telefono'}),
      };
      final m = mergeSync(local: local, remote: remote, base: base);
      expect(m.prefs['el.grades'], 'A+B');
      expect(m.prefs['el.agenda'], 'X+Y');
      expect(m.prefs['el.theme'], 'dark');
      final x = jsonDecode(m.prefs['el.extras']! as String) as Map;
      expect(x['stat.days'], 5); // il più alto
      expect(x['ach.done'], 'a,b,c'); // unione
      expect(x['n.morning'], false); // cambiata solo dall'altro
      expect(x['cloud.device'], 'pc'); // resta di questo dispositivo
      expect(m.changed, containsAll(['el.agenda', 'el.theme', 'el.extras/n.morning']));
      expect(m.changed, isNot(contains('el.grades')));
    });

    test('se l altro non ha toccato niente, non cambia niente', () {
      final base = syncHashes(base0);
      final local = {...base0, 'el.grades': 'nuovo'};
      final m = mergeSync(local: local, remote: base0, base: base);
      expect(m.prefs['el.grades'], 'nuovo');
      expect(m.changed, isEmpty);
    });

    test('opzioni solo locali', () {
      expect(isLocalOnlyOption('cloud.seenAt'), isTrue);
      expect(isLocalOnlyOption('mis.d.key'), isTrue);
      expect(isLocalOnlyOption('stat.days'), isFalse);
      expect(syncHashes({'el.extras': jsonEncode({'cloud.x': 1, 'a': 2})}).keys, ['el.extras/a']);
    });
  });
}

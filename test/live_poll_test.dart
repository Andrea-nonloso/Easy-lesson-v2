// Chat in diretta: ogni secondo mentre la pagina è aperta, mai due richieste insieme, stop alla chiusura.
import 'dart:async';

import 'package:easy_lesson/ui/live_poll.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Probe extends StatefulWidget {
  const _Probe(this.calls, this.slow);
  final List<int> calls;
  final Completer<void>? Function() slow;
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> with LivePoll {
  @override
  void initState() {
    super.initState();
    startLivePoll(const Duration(seconds: 1));
  }

  @override
  Future<void> livePollRefresh() async {
    widget.calls.add(1);
    await widget.slow()?.future;
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

void main() {
  testWidgets('LivePoll: ogni secondo, senza accavallarsi, si ferma alla chiusura', (t) async {
    final calls = <int>[];
    Completer<void>? hang;
    await t.pumpWidget(_Probe(calls, () => hang));
    await t.pump(const Duration(seconds: 3));
    expect(calls.length, 3);
    hang = Completer<void>();
    await t.pump(const Duration(seconds: 3)); // il server non risponde: una sola richiesta in sospeso
    expect(calls.length, 4);
    hang.complete();
    hang = null;
    await t.pump(const Duration(seconds: 1));
    expect(calls.length, 5);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 3));
    expect(calls.length, 5);
  });
}

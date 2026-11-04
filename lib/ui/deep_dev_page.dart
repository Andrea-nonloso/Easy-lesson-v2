import 'package:flutter/material.dart';

import '../store.dart';

/// Ex "Sviluppatore²". Dalla 3.6 il menu vero non è più nell'app: eventi, avvisi, ricompense e server si gestiscono
/// dall'app di moderazione (sessione del proprietario, sul server). Qui resta solo una sorpresa: il gesto apre un PIN
/// che non controlla niente e non chiama il server, e sblocca l'obiettivo segreto `deepDev`.
Future<void> openDeepDevGate(BuildContext context) async {
  final store = StoreScope.read(context);
  final ctrl = TextEditingController();
  final pin = await showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      icon: const Text('🕳️', style: TextStyle(fontSize: 36)),
      title: const Text('Chi va là?'),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        obscureText: true,
        decoration: const InputDecoration(hintText: 'PIN'),
        onSubmitted: (v) => Navigator.pop(c, v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annulla')),
        FilledButton(onPressed: () => Navigator.pop(c, ctrl.text), child: const Text('Entra')),
      ],
    ),
  );
  ctrl.dispose();
  if (pin == null || pin.isEmpty || !context.mounted) return;
  await store.setOpt('ach.deepDev', true);
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (c) => AlertDialog(
      icon: const Text('🐇', style: TextStyle(fontSize: 40)),
      title: const Text('Assurdo.'),
      content: const Text(
        'Sei arrivato fin qui: stai davvero scavando nell\'app.\n\n'
        'Continua a cercare, magari trovi altre cose…\n\n'
        'PS: non ci sono altre cose.',
        textAlign: TextAlign.center,
      ),
      actions: [FilledButton(onPressed: () => Navigator.pop(c), child: const Text('Va bene 😔'))],
    ),
  );
}

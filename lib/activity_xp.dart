import 'progress.dart' show isoDay;
import 'store.dart';

/// XP delle attività della 3.9 (flashcard, quiz, abitudini, maturità…).
/// Finiscono nel contatore "stat.activityXp" (sommato in totalXp e sincronizzato come gli altri), con un tetto
/// giornaliero: così nessuna attività gonfia la classifica della settimana.
const dailyActivityXpCap = 150;

/// Dà fino a [xp] punti (meno, se il tetto di oggi è quasi pieno). Restituisce quanti ne ha dati davvero.
Future<int> awardActivityXp(AppStore s, int xp, {DateTime? now}) async {
  if (xp <= 0) return 0;
  final day = isoDay(now ?? DateTime.now());
  final used = s.opt('axp.day', '') == day ? s.opt<int>('axp.used', 0) : 0;
  final give = xp.clamp(0, dailyActivityXpCap - used);
  if (give <= 0) return 0;
  await s.setOpt('axp.day', day);
  await s.setOpt('axp.used', used + give);
  await s.bump('activityXp', give);
  return give;
}

/// Come [awardActivityXp], ma una volta sola al giorno per [key] (es. "hab:<id>", "mood"):
/// spuntare e togliere la spunta di continuo non dà altre XP.
Future<int> awardActivityXpOnce(AppStore s, String key, int xp, {DateTime? now}) async {
  final day = isoDay(now ?? DateTime.now());
  final raw = s.opt('axp.onceDay', '') == day ? s.opt<List<dynamic>?>('axp.once', null) ?? const [] : const [];
  final keys = [for (final k in raw) '$k'];
  if (keys.contains(key)) return 0;
  await s.setOpt('axp.onceDay', day);
  await s.setOpt('axp.once', [...keys, key]);
  return awardActivityXp(s, xp, now: now);
}

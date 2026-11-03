import 'dart:convert';

import 'cloud.dart';
import 'log.dart';
import 'mission_engine.dart' show missionMetric;
import 'store.dart';

/// Classe, amici, classifica (3.0). Serve l'account; si vede solo soprannome + emoji.
/// Il server: server/src/social.js.

/// Emoji tra cui scegliere l'avatar.
const socialAvatars = [
  '🙂', '😎', '🤓', '🦊', '🐱', '🐶', '🐼', '🐸', '🦉', '🐧', '🦄', '🐙', '🐢', '🦖', '🐝', '🦋',
  '🌵', '🍀', '🌻', '🍕', '🍩', '⚽', '🏀', '🎮', '🎧', '🎸', '🎨', '📚', '🚀', '⭐', '🔥', '⚡',
];

const challengeMetrics = {
  'studied': ('Minuti di studio', '⏱️'),
  'agendaDone': ('Compiti fatti', '✅'),
  'days': ('Giorni con l\'app', '📅'),
};

String _s(Object? v, [String d = '']) => v is String ? v : d;
int _i(Object? v, [int d = 0]) => v is num ? v.toInt() : d;

class SocialProfile {
  SocialProfile(this.j);
  final Map<String, dynamic> j;
  String get nickname => _s(j['nickname']);
  String get avatar => _s(j['avatar'], '🙂');
  String get friendCode => _s(j['friendCode']);
  int get weekXp => _i(j['weekXp']);
  bool get hiddenByModeration => j['hiddenByModeration'] == true;
  int get strikes => _i(j['strikes']);
  int get unreadNotices => _i(j['unreadNotices']);

  /// Messaggio se è sospeso da classe e amici (null = no).
  String? get suspension => j['suspension'] is String ? j['suspension'] as String : null;
}

/// Avviso della moderazione. level: info | warning | final | suspension.
class ModNotice {
  ModNotice(this.j);
  final Map<String, dynamic> j;
  String get id => _s(j['id']);
  String get level => _s(j['level'], 'info');
  String get title => _s(j['title']);
  String get body => _s(j['body']);
  bool get read => j['read'] == true;
  bool get canAppeal => j['canAppeal'] == true;

  /// null | open | accepted | rejected
  String? get appeal => j['appeal'] is String ? j['appeal'] as String : null;
  String? get reply => j['reply'] is String ? j['reply'] as String : null;
  DateTime get createdAt => DateTime.fromMillisecondsSinceEpoch(_i(j['createdAt']));
}

/// Un amico (o una richiesta, o una riga della classifica).
class Friend {
  Friend(this.j);
  final Map<String, dynamic> j;
  String get code => _s(j['code']);
  String get nickname => _s(j['nickname'], 'Utente');
  String get avatar => _s(j['avatar'], '🙂');
  int get level => _i(j['level'], 1);
  int get weekXp => _i(j['weekXp']);
  int get rank => _i(j['rank']);
  bool get me => j['me'] == true;
}

class FriendsData {
  FriendsData(Map<String, dynamic> j)
      : friends = _list(j['friends']),
        incoming = _list(j['incoming']),
        outgoing = _list(j['outgoing']),
        leaderboard = _list(j['leaderboard']);
  final List<Friend> friends, incoming, outgoing, leaderboard;
  static List<Friend> _list(Object? v) => v is List ? [for (final x in v) if (x is Map) Friend(Map<String, dynamic>.from(x))] : [];
}

class ClassSummary {
  ClassSummary(this.j);
  final Map<String, dynamic> j;
  String get id => _s(j['id']);
  String get name => _s(j['name']);
  bool get admin => j['role'] == 'admin';
  int get members => _i(j['members']);
  String get joinCode => _s(j['joinCode']);
}

class ClassMember {
  ClassMember(this.j);
  final Map<String, dynamic> j;
  String get id => _s(j['id']);
  String get nickname => _s(j['nickname'], 'Utente');
  String get avatar => _s(j['avatar'], '🙂');
  int get level => _i(j['level'], 1);
  bool get admin => j['role'] == 'admin';
  bool get moderator => j['role'] == 'moderator';
  bool get me => j['me'] == true;
  bool get owner => j['owner'] == true;
}

class ClassChallenge {
  ClassChallenge(this.j);
  final Map<String, dynamic> j;
  String get id => _s(j['id']);
  String get metric => _s(j['metric']);
  String get title => _s(j['title']);
  int get target => _i(j['target'], 1);
  int get done => _i(j['done']);
  int get players => _i(j['players']);
  bool get active => j['active'] == true;
  bool get auto => j['auto'] == true;
  DateTime get ends => DateTime.fromMillisecondsSinceEpoch(_i(j['ends']));
  double get progress => (done / (target <= 0 ? 1 : target)).clamp(0, 1).toDouble();
  bool get completed => done >= target;
}

class ClassInfo {
  ClassInfo(this.j)
      : members = [for (final m in (j['members'] is List ? j['members'] as List : const [])) if (m is Map) ClassMember(Map<String, dynamic>.from(m))],
        challenges = [
          for (final c in (j['challenges'] is List ? j['challenges'] as List : const [])) if (c is Map) ClassChallenge(Map<String, dynamic>.from(c)),
        ];
  final Map<String, dynamic> j;
  final List<ClassMember> members;
  final List<ClassChallenge> challenges;
  String get id => _s(j['id']);
  String get name => _s(j['name']);
  bool get admin => j['role'] == 'admin';
  bool get moderator => j['role'] == 'moderator';
  String get joinCode => _s(j['joinCode']);
  bool get chatOn => j['chat'] != false;
}

/// Chat rapida: solo frasi pronte; {materia} e {giorno} da elenchi fissi.
class QuickPhrase {
  QuickPhrase(this.j);
  final Map<String, dynamic> j;
  String get id => _s(j['id']);
  String get text => _s(j['text']);
  String get category => _s(j['category'], 'saluti');
  List<String> get slots => [for (final x in (j['slots'] is List ? j['slots'] as List : const [])) '$x'];

  String render({String? subject, String? day}) =>
      text.replaceAll('{materia}', subject ?? '…').replaceAll('{giorno}', day ?? '…');
}

class ChatMessage {
  ChatMessage(this.j);
  final Map<String, dynamic> j;
  String get id => _s(j['id']);
  String get text => _s(j['text']);
  String get author => _s(j['author'], 'Un compagno');
  bool get byMe => j['byMe'] == true;
  bool get canDelete => j['canDelete'] == true;
  DateTime get at => DateTime.fromMillisecondsSinceEpoch(_i(j['at']));
}

class ChatData {
  ChatData(Map<String, dynamic> j)
      : enabled = j['enabled'] != false,
        messages = [for (final m in (j['messages'] is List ? j['messages'] as List : const [])) if (m is Map) ChatMessage(Map<String, dynamic>.from(m))],
        phrases = [for (final p in (j['phrases'] is List ? j['phrases'] as List : const [])) if (p is Map) QuickPhrase(Map<String, dynamic>.from(p))],
        subjects = [for (final x in (j['subjects'] is List ? j['subjects'] as List : const [])) '$x'],
        days = [for (final x in (j['days'] is List ? j['days'] as List : const [])) '$x'];
  final bool enabled;
  final List<ChatMessage> messages;
  final List<QuickPhrase> phrases;
  final List<String> subjects;
  final List<String> days;
}

/// Compito o verifica condiviso con la classe.
class ClassItem {
  ClassItem(this.j);
  final Map<String, dynamic> j;
  String get id => _s(j['id']);
  String get kind => _s(j['kind'], 'other');
  String get subject => _s(j['subject']);
  String get title => _s(j['title']);
  String get day => _s(j['day']);
  DateTime get date => DateTime.tryParse(day) ?? DateTime.now();
  String get author => _s(j['author'], 'Un compagno');
  bool get byMe => j['byMe'] == true;
  int get confirms => _i(j['confirms']);
  bool get confirmedByMe => j['confirmedByMe'] == true;
  bool get canDelete => j['canDelete'] == true;
}

String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Link nel QR per entrare in una classe / aggiungere un amico.
String classLink(String joinCode) => 'easylesson://class?c=${Uri.encodeQueryComponent(joinCode)}';
String friendLink(String friendCode) => 'easylesson://friend?c=${Uri.encodeQueryComponent(friendCode)}';

class Social {
  Social._();

  static Future<Map<String, dynamic>> _j(AppStore s, String method, String path, {Object? body}) async {
    final code = s.accountCode;
    if (code == null) throw CloudException('Serve l\'account Easy Lesson (Profilo → Account)');
    final t = await Cloud.raw(method, path, code: code, body: body);
    try {
      final j = jsonDecode(t);
      return j is Map<String, dynamic> ? j : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  /// null = non ha ancora scelto il soprannome.
  static Future<SocialProfile?> me(AppStore s) async {
    try {
      final p = SocialProfile(await _j(s, 'GET', '/social/me'));
      await s.setOpt('social.nick', p.nickname);
      return p;
    } on CloudException catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  static Future<SocialProfile> saveProfile(AppStore s, String nickname, String avatar) async {
    final p = SocialProfile(await _j(s, 'PUT', '/social/profile', body: {'nickname': nickname, 'avatar': avatar}));
    await s.setOpt('social.nick', p.nickname);
    return p;
  }

  static Future<void> deleteProfile(AppStore s) async {
    await _j(s, 'DELETE', '/social/profile');
    await s.setOpt('social.nick', null);
  }

  static Future<FriendsData> friends(AppStore s) async => FriendsData(await _j(s, 'GET', '/social/friends'));

  /// 'friends' o 'requested'.
  static Future<String> addFriend(AppStore s, String code) async =>
      _s((await _j(s, 'POST', '/social/friends', body: {'code': code}))['status'], 'requested');
  static Future<void> answerFriend(AppStore s, String code, bool accept) =>
      _j(s, 'POST', '/social/friends/${accept ? 'accept' : 'decline'}', body: {'code': code});
  static Future<void> removeFriend(AppStore s, String code) => _j(s, 'DELETE', '/social/friends/${Uri.encodeComponent(code)}');

  static Future<List<ClassSummary>> classes(AppStore s) async {
    final l = (await _j(s, 'GET', '/classes'))['classes'];
    final out = l is List ? [for (final c in l) if (c is Map) ClassSummary(Map<String, dynamic>.from(c))] : <ClassSummary>[];
    await s.setOpt('social.classes', out.map((c) => c.id).join(','));
    return out;
  }

  static Future<ClassSummary> createClass(AppStore s, String name) async =>
      ClassSummary(await _j(s, 'POST', '/classes', body: {'name': name}));
  static Future<String> joinClass(AppStore s, String code) async =>
      _s((await _j(s, 'POST', '/classes/join', body: {'code': code}))['id']);
  static Future<ClassInfo> classInfo(AppStore s, String id) async => ClassInfo(await _j(s, 'GET', '/classes/$id'));
  static Future<void> renameClass(AppStore s, String id, String name) => _j(s, 'PUT', '/classes/$id', body: {'name': name});
  static Future<void> setChat(AppStore s, String id, bool on) => _j(s, 'PUT', '/classes/$id', body: {'chat': on});

  static Future<ChatData> chat(AppStore s, String classId) async => ChatData(await _j(s, 'GET', '/classes/$classId/chat'));
  static Future<void> sendChat(AppStore s, String classId, QuickPhrase p, {String? subject, String? day}) async {
    await _j(s, 'POST', '/classes/$classId/chat', body: {
      'phrase': p.id,
      if (subject != null) 'subject': subject,
      if (day != null) 'day': day,
    });
    await s.bump('chatSent');
  }

  static Future<void> deleteChat(AppStore s, String classId, String id) => _j(s, 'DELETE', '/classes/$classId/chat/$id');
  static Future<void> leaveClass(AppStore s, String id) => _j(s, 'POST', '/classes/$id/leave');
  static Future<String> newJoinCode(AppStore s, String id) async => _s((await _j(s, 'POST', '/classes/$id/code'))['joinCode']);
  static Future<void> member(AppStore s, String classId, String memberId, String action) =>
      _j(s, 'POST', '/classes/$classId/members/$memberId/$action');

  static Future<List<ClassItem>> items(AppStore s, String classId, {DateTime? from}) async {
    final f = isoDate(from ?? DateTime.now().subtract(const Duration(days: 3)));
    final l = (await _j(s, 'GET', '/classes/$classId/items?from=$f'))['items'];
    return l is List ? [for (final i in l) if (i is Map) ClassItem(Map<String, dynamic>.from(i))] : [];
  }

  static Future<void> addItem(AppStore s, String classId,
      {required String kind, required String subject, required String title, required DateTime day}) async {
    await _j(s, 'POST', '/classes/$classId/items', body: {'kind': kind, 'subject': subject, 'title': title, 'day': isoDate(day)});
    await s.bump('classItems');
  }

  static Future<void> deleteItem(AppStore s, String classId, String itemId) => _j(s, 'DELETE', '/classes/$classId/items/$itemId');
  static Future<bool> confirm(AppStore s, String classId, String itemId) async =>
      (await _j(s, 'POST', '/classes/$classId/items/$itemId/confirm'))['confirmedByMe'] == true;

  static Future<void> newChallenge(AppStore s, String classId, {required String metric, required int target, required int days}) =>
      _j(s, 'POST', '/classes/$classId/challenges', body: {'metric': metric, 'target': target, 'days': days});

  /// Avvisi della moderazione e i motivi possibili per contestarli.
  static Future<(List<ModNotice>, Map<String, String>)> notices(AppStore s) async {
    final j = await _j(s, 'GET', '/social/notices');
    final l = j['notices'];
    final reasons = j['reasons'] is Map ? Map<String, String>.from((j['reasons'] as Map).map((k, v) => MapEntry('$k', '$v'))) : <String, String>{};
    return (l is List ? [for (final n in l) if (n is Map) ModNotice(Map<String, dynamic>.from(n))] : <ModNotice>[], reasons);
  }

  static Future<void> readNotice(AppStore s, String id) => _j(s, 'POST', '/social/notices/$id/read');
  static Future<void> appealNotice(AppStore s, String id, String reason) =>
      _j(s, 'POST', '/social/notices/$id/appeal', body: {'reason': reason});

  static Future<void> report(AppStore s, {required String kind, required String target, String reason = ''}) =>
      _j(s, 'POST', '/report', body: {'kind': kind, 'target': target, 'reason': reason});

  /// I numeri che contano per le sfide di classe.
  static Map<String, int> challengeValues(AppStore s) => {for (final m in challengeMetrics.keys) m: missionMetric(s, m)};

  /// XP per la classifica e progressi delle sfide: al massimo ogni 30 minuti, in silenzio.
  /// [xp]/[level] li passa la UI (il calcolo sta in ui/achievements.dart).
  static Future<void> sync(AppStore s, {required int xp, required int level, bool force = false}) async {
    if (s.accountCode == null || s.opt<String?>('social.nick', null) == null) return;
    final last = DateTime.tryParse(s.opt('social.at', ''));
    if (!force && last != null && DateTime.now().difference(last) < const Duration(minutes: 30)) return;
    await s.setOpt('social.at', DateTime.now().toIso8601String());
    try {
      await _j(s, 'PUT', '/social/xp', body: {'xp': xp, 'level': level});
      final values = challengeValues(s);
      for (final id in s.opt('social.classes', '').split(',').where((x) => x.isNotEmpty)) {
        await _j(s, 'POST', '/classes/$id/progress', body: {'values': values});
      }
    } catch (e) {
      AppLog.w('classe', 'Sincronizzazione classe non riuscita: $e');
    }
  }
}

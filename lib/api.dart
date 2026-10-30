import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

class ApiException implements Exception {
  ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Client delle cloud function di Easy Lesson.
///
/// Non dipende da Flutter: si può riusare in un futuro tool a riga di comando
/// (es. un container Docker che genera l'immagine dell'orario).
class EasyLessonApi {
  EasyLessonApi({
    http.Client? client,
    this.baseUrl = 'https://us-central1-easy-lesson.cloudfunctions.net',
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final String baseUrl;

  static const _timeout = Duration(seconds: 30);

  Future<String> _get(String pathAndQuery) async {
    Object lastError = ApiException('Connessione non disponibile');
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final res = await _client.get(Uri.parse('$baseUrl$pathAndQuery')).timeout(_timeout);
        if (res.statusCode == 200) return utf8.decode(res.bodyBytes);
        lastError = ApiException('Il server ha risposto con errore ${res.statusCode}');
        if (res.statusCode >= 400 && res.statusCode < 500) break;
      } on TimeoutException {
        lastError = ApiException('Il server non risponde');
      } catch (_) {
        lastError = ApiException('Connessione non disponibile');
      }
      if (attempt == 0) await Future<void>.delayed(const Duration(seconds: 1));
    }
    throw lastError;
  }

  /// `which` = 'studs' (classi) oppure 'profs' (docenti).
  Future<List<String>> lista(String which) async {
    final d = jsonDecode(await _get('/getListe?lista=$which'));
    if (d is! List) throw ApiException('Risposta non valida dal server');
    return d.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toSet().toList();
  }

  /// Etichette delle fasce orarie (una per ora di lezione).
  Future<List<String>> ore() async => parseOreXml(await _get('/getXmlOre'));

  Future<Map<String, dynamic>> orario(ScheduleRef ref, {required int ore}) async {
    final q = ref.prof
        ? 'prof=${Uri.encodeComponent(ref.name)}'
        : 'classe=${Uri.encodeComponent(ref.name)}';
    final body = await _get('/getOrario?$q&ore=$ore');
    try {
      return decodeOrario(body);
    } on FormatException {
      throw ApiException('Orario non trovato');
    }
  }
}

// Test di regressione per le vulnerabilità dell'audit del 4/11/2026 (security/AUDIT.md).
// Erano "dimostrazioni" (passavano col problema presente); ora passano solo se il problema è risolto.
// Tutto finto: client HTTP finti, account inventato, file temporanei.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:easy_lesson/api.dart';
import 'package:easy_lesson/cloud.dart';
import 'package:easy_lesson/school_life.dart';
import 'package:easy_lesson/store.dart';
import 'package:easy_lesson/ui/photos_io.dart';
import 'package:easy_lesson/ui/share_qr.dart';
import 'package:easy_lesson/xlsx.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _link(Map<String, Object?> prefs) {
  final backup = jsonEncode({'easyLessonBackup': 2, 'prefs': prefs});
  return 'easylesson://import?d=${base64Url.encode(utf8.encode(jsonEncode({'k': 'backup', 'b': backup})))}';
}

List<int> _xlsx(String sheetXml) {
  final xml = utf8.encode(sheetXml);
  final archive = Archive()..addFile(ArchiveFile('xl/worksheets/sheet1.xml', xml.length, xml));
  return ZipEncoder().encode(archive);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const fakeCode = 'AuditOnlyAccount23456';
  late AppStore store;
  late http.Client previousClient;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'el.account': fakeCode,
      'el.classi': <String>['AUDIT'],
      'el.docenti': <String>[],
      'el.ore': <String>[],
      'el.listsAt': DateTime.now().toIso8601String(),
      'el.extras': jsonEncode({'cloud.consent': true, 'stat.xpBonus': 5}),
    });
    previousClient = Cloud.client;
    CloudKeys.forget();
    Cloud.overrideUrl = null;
    store = await AppStore.create(api: EasyLessonApi(client: MockClient((_) async => http.Response('[]', 200))));
    await store.refreshLists();
  });

  tearDown(() {
    Cloud.client = previousClient;
    Cloud.overrideUrl = null;
    CloudKeys.forget();
    LessonPhotos.folderOverride = null;
    store.dispose();
  });

  group('EL-01 backup e server', () {
    test('un backup non cambia server, consenso né regali, ma porta le opzioni normali', () async {
      await importShared(store, _link({
        'el.extras': jsonEncode({
          'dev.cloudUrl': 'https://audit.invalid',
          'cloud.consent': false,
          'stat.xpBonus': 999999,
          'stat.coinBonus': 999999,
          'stat.opens': 3,
        }),
        'el.account': 'AltroAccount999999999',
        'el.themeId': 'audit',
      }));
      expect(store.accountCode, fakeCode);
      expect(store.opt<String?>('dev.cloudUrl', null), isNull);
      expect(store.opt('cloud.consent', false), isTrue);
      expect(store.opt('stat.xpBonus', 0), 5);
      expect(store.opt('stat.coinBonus', 0), 0);
      expect(store.opt('stat.opens', 0), 3);
    });

    test('il token dell\'account va solo al server ufficiale', () async {
      Cloud.overrideUrl = 'https://audit.invalid';
      var called = false;
      Cloud.client = MockClient((_) async {
        called = true;
        return http.Response('{}', 200);
      });
      await expectLater(Cloud.me(fakeCode), throwsA(isA<CloudException>()));
      expect(called, isFalse);
      expect(Cloud.isTrustedServer(Uri.parse('https://audit.invalid/v1/me')), isFalse);
      expect(Cloud.isTrustedServer(Uri.parse('$cloudDefaultUrl/v1/me')), isTrue);
    });

    test('un backup rovinato non scrive niente a metà', () async {
      await expectLater(store.restore('{"easyLessonBackup":2,"prefs":[]}'), throwsFormatException);
      expect(store.opt('cloud.consent', false), isTrue);
    });

    test('il link di un backup chiede conferma (è "rischioso")', () {
      expect(describeShared(_link({'el.themeId': 'x'}))!.risky, isTrue);
      expect(describeShared('spazzatura'), isNull);
    });
  });

  group('EL-02 foto', () {
    late Directory root;
    late Directory photos;
    late File sentinel;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('easylesson-security-');
      photos = await Directory('${root.path}/easylesson_foto').create();
      sentinel = File('${root.path}/sentinella.txt');
      await sentinel.writeAsString('non cancellarmi');
      LessonPhotos.folderOverride = photos;
    });
    tearDown(() => root.delete(recursive: true));

    Future<void> restorePhoto(String path) => store.restore(jsonEncode({
          'easyLessonBackup': 2,
          'prefs': {
            'el.photos': jsonEncode([
              {'id': 'audit', 'date': '2026-11-04', 'subject': 'Audit', 'path': path},
            ]),
          },
        }));

    test('una foto importata non cancella file fuori dalla cartella', () async {
      await restorePhoto(sentinel.path);
      final photo = store.photos.single;
      await store.removePhoto(photo);
      await LessonPhotos.delete(photo.path);
      expect(await sentinel.exists(), isTrue);
    });

    test('un collegamento simbolico nella cartella non porta fuori', () async {
      final link = await Link('${photos.path}/finta.jpg').create(sentinel.path);
      await LessonPhotos.delete(link.path);
      expect(await sentinel.exists(), isTrue);
    }, skip: Platform.isWindows ? 'i link su Windows richiedono permessi' : false);

    test('i percorsi con ".." non entrano proprio nel backup', () async {
      await restorePhoto('${photos.path}/../sentinella.txt');
      expect(store.photos, isEmpty);
      expect(hasPathTraversal(r'C:\foto\..\x'), isTrue);
      expect(hasPathTraversal('/data/foto/1.jpg'), isFalse);
    });

    test('le foto vere dell\'app si cancellano ancora', () async {
      final own = await File('${photos.path}/123.jpg').writeAsBytes([1, 2, 3]);
      expect(await LessonPhotos.isOwnPhoto(own.path), isTrue);
      await LessonPhotos.delete(own.path);
      expect(await own.exists(), isFalse);
    });
  });

  group('EL-03 Excel', () {
    test('una cella lontanissima viene rifiutata prima di allocare', () {
      final bytes = _xlsx('<worksheet><sheetData><row r="99999999">'
          '<c r="A99999999" t="inlineStr"><is><t>audit</t></is></c></row></sheetData></worksheet>');
      expect(() => readXlsx(bytes), throwsFormatException);
    });

    test('troppe colonne o coordinate strane vengono rifiutate', () {
      expect(
        () => readXlsx(_xlsx('<worksheet><sheetData><row r="1"><c r="XFD1" t="inlineStr"><is><t>x</t></is></c>'
            '</row></sheetData></worksheet>')),
        throwsFormatException,
      );
      expect(
        () => readXlsx(_xlsx('<worksheet><sheetData><row r="0"><c r="A0" t="inlineStr"><is><t>x</t></is></c>'
            '</row></sheetData></worksheet>')),
        throwsFormatException,
      );
    });

    test('una "zip bomb" si ferma al limite dei byte decompressi', () {
      final big = Uint8List(3 * 1024 * 1024); // 3 MB di zeri: compressi diventano pochi KB
      final archive = Archive()..addFile(ArchiveFile('xl/worksheets/sheet1.xml', big.length, big));
      final bytes = ZipEncoder().encode(archive);
      expect(bytes.length, lessThan(100 * 1024));
      expect(() => readXlsx(bytes, limits: const XlsxLimits(maxPartBytes: 1024 * 1024)), throwsFormatException);
    });

    test('un indice di testo condiviso negativo non fa danni', () {
      final rows = readXlsx(_xlsx('<worksheet><sheetData><row r="1"><c r="A1" t="s"><v>-1</v></c>'
          '<c r="B1" t="inlineStr"><is><t>ok</t></is></c></row></sheetData></worksheet>'));
      expect(rows.single, ['', 'ok']);
    });

    test('il file di esempio della scuola si legge ancora', () {
      final rows = readXlsx(File('test/fixtures/orario_esempio.xlsx').readAsBytesSync());
      expect(rows.length, greaterThan(100));
    });
  });

  group('EL-04 backup online', () {
    test('i dati sensibili in chiaro (senza parte cifrata) vengono scartati', () async {
      expect(isSensitiveKey('el.photos'), isTrue);
      Cloud.client = MockClient((request) async {
        expect(request.url.path, '/v1/backup');
        return http.Response(
            jsonEncode({
              'easyLessonBackup': 3,
              'prefs': {
                'el.photos': jsonEncode([
                  {'id': 'forged', 'date': '2026-11-04', 'subject': 'Forged', 'path': '/nonexistent/audit'},
                ]),
                'el.extras': jsonEncode({'stat.opens': 42}),
                'el.themeId': 'audit',
              },
            }),
            200);
      });
      await CloudSync.restoreFromServer(store);
      expect(store.photos, isEmpty);
      expect(store.opt('stat.opens', 0), 0);
      // Le parti non sensibili (aspetto, orari) restano in chiaro come prima.
      expect(store.rawPrefs()['el.themeId'], 'audit');
    });
  });

  test('il menu Sviluppatore² non chiama più il server', () {
    // devUnlock/devSession/admin* sono stati tolti da Cloud: se tornano, questo file non compila più
    // insieme a server_admin_page.dart (cancellato). Qui si controlla solo che il file non esista.
    expect(File('lib/ui/server_admin_page.dart').existsSync(), isFalse);
  });
}

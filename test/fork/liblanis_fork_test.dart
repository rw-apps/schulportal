import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' show parse;
import 'package:lanis/fork/demo/demo_portal.dart';
import 'package:lanis/fork/demo/demo_school.dart';
import 'package:liblanis/liblanis.dart';
// Cryptor exportiert liblanis nicht; die App erreicht ihn nur über
// LanisSession.cryptor.
// ignore: implementation_imports
import 'package:liblanis/src/session/cryptor.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

// Korrekturen in der eingebetteten liblanis (packages/liblanis/FORK.md),
// Befunde der Prüfung vom 27.10.26. Alle Seiten und Daten sind erfunden.

/// Erfundene Portal-Antworten; [handler] entscheidet je Anfrage.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  FutureOr<ResponseBody> Function(RequestOptions o) handler;
  final seen = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    seen.add(options);
    if (requestStream != null) await requestStream.drain<void>();
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

/// Demo-Portal mit Zähler und Eingriff je Anfrage.
class _CountingPortal implements HttpClientAdapter {
  _CountingPortal(this.inner);

  final DemoPortal inner;
  final seen = <RequestOptions>[];
  FutureOr<ResponseBody?> Function(RequestOptions o)? intercept;
  Duration loginDelay = Duration.zero;

  int get logins =>
      seen.where((o) => o.uri.host == 'login.schulportal.hessen.de').length;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    seen.add(options);
    if (options.uri.host == 'login.schulportal.hessen.de') {
      await Future<void>.delayed(loginDelay);
    }
    final own = await intercept?.call(options);
    if (own != null) {
      await requestStream?.drain<void>();
      return own;
    }
    return inner.fetch(options, requestStream, cancelFuture);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _text(String s, [int status = 200]) => ResponseBody.fromString(
  s,
  status,
  headers: {
    Headers.contentTypeHeader: ['text/plain; charset=utf-8'],
  },
);

final _account = ClearTextAccount(
  localId: 1,
  schoolID: 1,
  username: 'test.user',
  password: 'x',
  schoolName: 'Testschule',
  accountType: AccountType.student,
);

Future<LanisSession> _session(
  HttpClientAdapter adapter, {
  ClearTextAccount? account,
}) async {
  LanisClient.configure(httpAdapter: adapter);
  addTearDown(LanisClient.reset);
  final session = LanisSession(
    account: account ?? _account,
    config: LanisClient.config!,
    connectionChecker: ConnectionChecker(httpAdapter: adapter),
  );
  await session.prepareDio();
  addTearDown(session.dispose);
  return session;
}

ClearTextAccount _demoAccount(String user) => ClearTextAccount(
  localId: 1,
  schoolID: demoSchoolId,
  username: user,
  password: 'demo',
  schoolName: demoSchoolName,
);

AppletContext _ctx(LanisSession session) {
  final db = LanisDatabase.open();
  addTearDown(db.dispose);
  return AppletContext(
    session: session,
    database: db,
    account: _account,
    accountSettings: TypedSettings.shared(db),
  );
}

/// Verschlüsselt [plain] so, wie das Portal `<encoded>` füllt.
String _encode(Cryptor c, String plain) => c.encryptString(plain);

/// Isolate-Einstieg: exklusive Sperre auf [args].$1, 400 ms halten.
void _holdLock((String, SendPort) args) {
  final (path, port) = args;
  final other = sqlite3.open(path);
  other.execute('BEGIN EXCLUSIVE;');
  other.execute("INSERT OR REPLACE INTO shared_settings VALUES ('a', '1');");
  port.send('locked');
  sleep(const Duration(milliseconds: 400));
  other.execute('COMMIT;');
  other.close();
  port.send('done');
}

class _FailingParser extends AppletParser<String> {
  _FailingParser(AppletContext ctx)
    : super(ctx, Applets.lessons, isConnected: () async => true);

  @override
  Future<String> getHome() async => throw UnknownException('kaputt');
}

void main() {
  group('Befund 2: Zeitlimits der Login-Anfrage', () {
    test('Empfang 30 s, Senden 60 s, Verbindung 8 s', () async {
      final adapter = _FakeAdapter(
        (o) => ResponseBody.fromString(
          '',
          302,
          headers: {
            'location': ['https://connect.schulportal.hessen.de/x'],
          },
        ),
      );
      LanisClient.configure(httpAdapter: adapter);
      addTearDown(LanisClient.reset);
      await LanisSession.getLoginURL(_account, LanisClient.config!);
      final login = adapter.seen.firstWhere(
        (o) => o.uri.host == 'login.schulportal.hessen.de',
      );
      expect(login.receiveTimeout, const Duration(seconds: 30));
      expect(login.sendTimeout, const Duration(seconds: 60));
      expect(login.connectTimeout, const Duration(seconds: 8));
    });
  });

  group('Befund 6: Login-Antwort ohne Weiterleitung', () {
    test('Merkmale je Seite', () {
      expect(
        LanisSession.loginFailure(
          '<div id="authErrorLocktime">42</div>'
          '<form><input type="password" name="password"></form>',
        ),
        isA<LoginTimeoutException>().having((e) => e.time, 'time', '42'),
      );
      // Formular kommt zurück – auch mit Wartungs-Ankündigung darüber.
      expect(
        LanisSession.loginFailure(
          '<p>Am Samstag Wartung von 8 bis 10 Uhr.</p>'
          '<form><input name="user2"><input type="password" name="password">'
          '</form>',
        ),
        isA<WrongCredentialsException>(),
      );
      expect(
        LanisSession.loginFailure('<body>Login fehlgeschlagen</body>'),
        isA<WrongCredentialsException>(),
      );
      expect(
        LanisSession.loginFailure(
          '<body><h1>Wartungsarbeiten</h1><p>Das Schulportal steht Ihnen '
          'aktuell nicht zur Verfügung.</p></body>',
        ),
        isA<LanisDownException>(),
      );
      expect(LanisSession.loginFailure(''), isA<UnknownException>());
      expect(
        LanisSession.loginFailure('<body><p>Proxy-Fehler</p></body>'),
        isA<UnknownException>(),
      );
    });

    test('Wartungsseite mit HTTP 200 ist kein falsches Passwort', () async {
      final adapter = _FakeAdapter(
        (o) => _text('<html><body>Wartung – bitte später.</body></html>'),
      );
      LanisClient.configure(httpAdapter: adapter);
      addTearDown(LanisClient.reset);
      await expectLater(
        LanisSession.getLoginURL(_account, LanisClient.config!),
        throwsA(isA<LanisDownException>()),
      );
    });
  });

  group('Befund 3: eine Anmeldung je Sitzung, Schlüssel nach Handshake', () {
    test('gleichzeitige Aufrufer teilen sich die Anmeldung', () async {
      final portal = _CountingPortal(DemoPortal())
        ..loginDelay = const Duration(milliseconds: 50);
      final s = await _session(portal, account: _demoAccount('demo.lena'));
      await Future.wait([s.authenticate(), s.authenticate(), s.authenticate()]);
      expect(portal.logins, 1);
      expect(s.cryptor.authenticated, isTrue);

      // Danach wieder eine eigene Anmeldung.
      await s.authenticate();
      expect(portal.logins, 2);
    });

    test('falsches Passwort: ein Versuch, alle bekommen den Fehler', () async {
      final portal = _CountingPortal(DemoPortal())
        ..loginDelay = const Duration(milliseconds: 50);
      final s = await _session(portal, account: _demoAccount('jemand'));
      final results = await Future.wait([
        for (var i = 0; i < 3; i++)
          s.authenticate().then<Object?>((_) => null, onError: (Object e) => e),
      ]);
      expect(results, everyElement(isA<WrongCredentialsException>()));
      expect(portal.logins, 1);
    });

    test(
      'Aufruf mit Nutzerdaten meldet sich nach einer ohne selbst an',
      () async {
        final portal = _CountingPortal(DemoPortal())
          ..loginDelay = const Duration(milliseconds: 50);
        final s = await _session(portal, account: _demoAccount('demo.lena'));
        await Future.wait([
          s.authenticate(withoutData: true),
          s.authenticate(),
        ]);
        expect(portal.logins, 2);
        expect(s.userData, isNotEmpty);
      },
    );

    test('Schlüssel wechselt erst nach bestätigtem Handshake', () async {
      final portal = _CountingPortal(DemoPortal());
      final s = await _session(portal, account: _demoAccount('demo.lena'));
      await s.authenticate();
      final first = s.cryptor.key;

      enc.Key? duringHandshake;
      portal.intercept = (o) {
        if (o.uri.queryParameters['f'] == 'rsaHandshake') {
          duringHandshake = s.cryptor.key;
        }
        return null;
      };
      await s.authenticate();
      expect(identical(duringHandshake, first), isTrue);
      expect(identical(s.cryptor.key, first), isFalse);
      final second = s.cryptor.key;

      // Portal bestätigt nicht: alter Schlüssel bleibt, typisierter Fehler.
      portal.intercept = (o) => o.uri.queryParameters['f'] == 'rsaHandshake'
          ? ResponseBody.fromString(
              jsonEncode({'challenge': base64.encode(utf8.encode('x' * 40))}),
              200,
              headers: {
                Headers.contentTypeHeader: ['application/json'],
              },
            )
          : null;
      await expectLater(
        s.authenticate(),
        throwsA(isA<EncryptionCheckFailedException>()),
      );
      expect(identical(s.cryptor.key, second), isTrue);
    });
  });

  group('Befund 4: gescheiterte Neuanmeldung beendet den Abruf', () {
    test('Status error statt fetching', () async {
      final adapter = _FakeAdapter((o) {
        if (o.uri.path == '/ajax_login.php') return _text('');
        return _text('', 503);
      });
      final s = await _session(adapter);
      final parser = _FailingParser(_ctx(s));
      addTearDown(parser.dispose);
      await parser.fetchData();
      expect(parser.latestResponse!.status, FetcherStatus.error);
      expect(
        parser.latestResponse!.error!.exception,
        isA<LanisDownException>(),
      );
    });
  });

  group('Befund 5: Sitzungs-Erhaltung wirft nicht', () {
    test('503 bei ajax_login.php', () async {
      final adapter = _FakeAdapter((o) => _text('', 503));
      final s = await _session(adapter);
      await s.jar.saveFromResponse(
        Uri.parse('https://start.schulportal.hessen.de/'),
        [Cookie('sid', 'abc')],
      );
      await expectLater(s.preventLogout(), completes);
    });
  });

  group('Befund 9: Kursmappe ohne einzelne Bereiche', () {
    Future<DetailedLesson> view(String body) async {
      final adapter = _FakeAdapter((o) => _text(body));
      final s = await _session(adapter);
      final parser = LessonsStudentParser(
        _ctx(s),
        isConnected: () async => true,
      );
      addTearDown(parser.dispose);
      return parser.getDetailedCourseView(
        'meinunterricht.php?a=sus_view&id=77',
      );
    }

    test('ohne #marks und #klausuren', () async {
      final d = await view(
        '<div id="content"><h1>Mathematik 7b</h1></div>'
        '<div class="btn-group"><button class="btn btn-primary '
        'dropdown-toggle btn-md">ABC</button></div>',
      );
      expect(d.name, 'Mathematik 7b');
      expect(d.marks, isEmpty);
      expect(d.exams, isEmpty);
      expect(d.teachers.single.teacherKuerzel, 'ABC');
      expect(d.teachers.single.teacher, isNull);
    });

    test('leeres #klausuren, Kommentare nur aus Kommentarzeilen', () async {
      final d = await view(
        '<div id="content"><h1><small>Kursmappe</small> Deutsch</h1></div>'
        '<div id="marks"><table><tbody>'
        '<tr><td>Test 1</td><td>01.10.2026</td><td>2</td></tr>'
        '<tr><td>Test 2</td><td>08.10.2026 08:00</td><td>3</td></tr>'
        '<tr><td></td><td colspan="2">Kommentar: Gut: weiter so</td></tr>'
        '<tr><td>Test 3</td><td>15.10.2026</td><td>1</td></tr>'
        '<tr><td colspan="3">Zwischenzeile</td></tr>'
        '</tbody></table></div>'
        '<div id="klausuren"></div>',
      );
      expect(d.name, 'Deutsch');
      expect(d.marks.map((m) => m.name), ['Test 1', 'Test 2', 'Test 3']);
      expect(d.marks.map((m) => m.comment), [null, 'Gut: weiter so', null]);
      expect(d.exams, isEmpty);
    });

    test('Seite ohne Überschrift bleibt ein Fehler', () async {
      await expectLater(
        view('<html><body><form><input name="password"></form></body></html>'),
        throwsA(isA<UnknownException>()),
      );
    });
  });

  group('Befund 10: Cryptor', () {
    Cryptor cryptor() => Cryptor()..key = enc.Key.fromSecureRandom(46);

    test('ein kaputtes <encoded> bleibt stehen, der Rest wird lesbar', () {
      final c = cryptor();
      final good = _encode(c, 'Lena');
      // „Salted__“, Salz, dann 5 Byte – keine ganze AES-Blocklänge.
      final broken = base64.encode([
        ...utf8.encode('Salted__'),
        ...List.filled(8, 1),
        ...List.filled(5, 2),
      ]);
      final html =
          '<td><encoded>$good</encoded></td>'
          '<td><encoded>$broken</encoded></td>'
          '<td><encoded>%%%</encoded></td>';
      final out = c.decryptEncodedTags(html);
      expect(out, contains('<td>Lena</td>'));
      expect(out, contains('<encoded>$broken</encoded>'));
      expect(out, contains('<encoded>%%%</encoded>'));
    });

    test('kein Tag lesbar (falscher Schlüssel) wirft wie bisher', () {
      final other = cryptor();
      final html = '<td><encoded>${_encode(other, 'Lena')}</encoded></td>';
      expect(() => cryptor().decryptEncodedTags(html), throwsA(anything));
    });

    test('kurze oder ungesalzene Daten: null statt Absturz', () {
      final k = enc.Key.fromSecureRandom(46);
      expect(Cryptor.decryptWithKey(Uint8List(3), k), isNull);
      expect(Cryptor.decryptWithKey(Uint8List(20), k), isNull);
      expect(
        Cryptor.decryptWithKey(
          Uint8List.fromList([0xff, ...List.filled(30, 1)]),
          k,
        ),
        isNull,
      );
      final c = cryptor();
      expect(c.checkForEqualEncryption(Uint8List(5)), isFalse);
      expect(c.checkForEqualEncryption(Uint8List(40)), isFalse);
    });
  });

  group('Befund 11: ungewöhnliche Profilseite', () {
    late LanisSession s;
    setUp(() async {
      s = await _session(_FakeAdapter((o) => _text('')));
    });

    test('Nutzerdaten: fremde Zeilen überspringen', () {
      final data = s.parseUserData(
        parse(
          '<div class="col-md-12"><table class="table table-striped"><tbody>'
          '<tr><td colspan="2">Persönliche Daten</td></tr>'
          '<tr><td>Klasse:</td><td>07B</td></tr>'
          '<tr><td></td><td>leer</td></tr>'
          '<tr><td>Kurs</td><td>M1</td></tr>'
          '</tbody></table></div>',
        ),
      );
      expect(data, {'klasse': '07B', 'kurs': 'M1'});
    });

    test('Kontoart: unbekannt ist null', () {
      expect(s.parseAccountType(parse('<html></html>')), isNull);
      expect(
        s.parseAccountType(
          parse(
            '<ul class="nav navbar-nav navbar-right"><li><a>'
            '<i class="fa fa-star"></i></a></li></ul>',
          ),
        ),
        isNull,
      );
      expect(
        s.parseAccountType(
          parse(
            '<ul class="nav navbar-nav navbar-right"><li><a>'
            '<i class="fa fa-user-circle"></i></a></li></ul>',
          ),
        ),
        AccountType.parent,
      );
    });
  });

  group('Befund 12: Datenbank wartet auf Sperren', () {
    test('Schreiben wartet, statt „database is locked“', () async {
      final dir = await Directory.systemTemp.createTemp('liblanis_busy');
      addTearDown(() => dir.delete(recursive: true));
      final path = p.join(dir.path, 'lanis.db');
      final db = LanisDatabase.open(
        path: path,
        secretStore: MemorySecretStore(),
      );
      addTearDown(db.dispose);

      // Zweite Verbindung in einem eigenen Isolate (wie der Hintergrundlauf)
      // hält 400 ms eine exklusive Sperre.
      final events = ReceivePort();
      addTearDown(events.close);
      final queue = StreamIterator(events);
      await Isolate.spawn(_holdLock, (path, events.sendPort));
      expect(await queue.moveNext(), isTrue);
      expect(queue.current, 'locked');
      final sw = Stopwatch()..start();
      db.setSharedSetting('b', '2');
      sw.stop();
      expect(await queue.moveNext(), isTrue);
      expect(queue.current, 'done');
      expect(db.getSharedSetting('b'), '2');
      expect(sw.elapsedMilliseconds, greaterThan(100));
    });
  });

  group('Befund 13: Kalenderzeiten', () {
    CalendarEvent event(Map<String, dynamic> times) =>
        CalendarEvent.fromLanisJson({'Id': '1', 'title': 'Test', ...times}, []);

    test('ohne Sekunden und ISO behalten die Uhrzeit', () {
      final a = event({
        'Anfang': '2026-10-27 08:15',
        'Ende': '2026-10-27 09:45:00',
      });
      expect(a.startTime, DateTime(2026, 10, 27, 8, 15));
      expect(a.endTime, DateTime(2026, 10, 27, 9, 45));

      final b = event({
        'start': '2026-10-27T08:15:00+01:00',
        'end': '2026-10-27T09:45:00+01:00',
      });
      expect(b.startTime.isUtc, isFalse);
      expect(b.startTime, DateTime.utc(2026, 10, 27, 7, 15).toLocal());

      final c = event({'Anfang': '27.10.2026 08:15', 'Ende': '2026-10-28'});
      expect(c.startTime, DateTime(2026, 10, 27, 8, 15));
      expect(c.endTime, DateTime(2026, 10, 28));
    });
  });
}

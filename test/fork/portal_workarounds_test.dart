import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' show parse;
import 'package:lanis/fork/db_wal.dart';
import 'package:lanis/fork/lessons_student.dart';
import 'package:lanis/fork/parent_support.dart';
import 'package:lanis/fork/session_guard.dart';
import 'package:lanis/fork/substitutions_fix.dart';
import 'package:lanis/utils/file_operations.dart' show downloadRevalidated;
import 'package:liblanis/liblanis.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

/// Erfundene Portal-Antworten; [handler] entscheidet je Anfrage.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  ResponseBody Function(RequestOptions o) handler;
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

Future<({LanisSession session, _FakeAdapter adapter})> _session(
  ResponseBody Function(RequestOptions o) handler, {
  String? cacheDir,
}) async {
  final adapter = _FakeAdapter(handler);
  LanisClient.configure(httpAdapter: adapter, documentCacheDirectory: cacheDir);
  addTearDown(LanisClient.reset);
  final session = LanisSession(
    account: _account,
    config: LanisClient.config!,
    connectionChecker: ConnectionChecker(httpAdapter: adapter),
  );
  await session.prepareDio();
  addTearDown(session.dispose);
  return (session: session, adapter: adapter);
}

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

void main() {
  group('Vertretungsplan ohne Planseite (substitutions_fix.dart)', () {
    test('Anmeldeseite und leere 302 sind Fehler', () {
      for (final html in [
        '',
        '<html><head><title>Login - Schulportal Hessen</title></head>'
            '<body><form><input name="user2"><input name="password">'
            '</form></body></html>',
      ]) {
        expect(
          () => checkSubstitutionPage(html),
          throwsA(isA<UnknownException>()),
        );
      }
      expect(
        () => checkSubstitutionPage(
          '<title>Fehler - Schulportal Hessen - Testschule</title>',
        ),
        throwsA(isA<UnauthorizedException>()),
      );
    });

    test('Planseite ohne Einträge bleibt ein leerer Plan', () {
      const empty =
          '<html><head><title>Vertretungsplan - Schulportal Hessen - '
          'Testschule</title></head><body><div id="content">'
          '<p>Keine Einträge</p></div></body></html>';
      expect(() => checkSubstitutionPage(empty), returnsNormally);
      expect(SubstitutionsParser.parseDocumentHtml(empty).days, isEmpty);
      for (final html in [
        '<div class="panel" data-tag="27.10.2026" id="tag27_10_2026"></div>',
        '<div id="tag27_10_2026"><table id="vtable27_10_2026"></table></div>',
        '<p>Letzte Aktualisierung: 27.10.2026 um 07:00:00 Uhr</p>',
        '<a href="index.php?logout=all">Abmelden</a>',
      ]) {
        expect(looksLikeSubstitutionPage(html), isTrue, reason: html);
      }
    });

    test(
      'getHome wirft bei leerer Antwort, liest eine echte Planseite',
      () async {
        var body = '';
        final s = await _session((_) => _text(body, 302));
        final parser = ForkSubstitutionsParser(_ctx(s.session));
        addTearDown(parser.dispose);
        await expectLater(parser.getHome(), throwsA(isA<UnknownException>()));

        body =
            '<title>Vertretungsplan - Schulportal Hessen</title>'
            '<div id="tag27_10_2026"><table id="vtable27_10_2026"><thead><tr>'
            '<th data-field="Stunde">Stunde</th><th data-field="Fach">Fach</th>'
            '</tr></thead><tbody><tr><td>3</td><td>M</td></tr></tbody></table>'
            '</div>';
        final plan = await parser.getHome();
        expect(plan.days.single.substitutions.single.fach, 'M');
      },
    );
  });

  group('Kursliste Schüler (lessons_student.dart)', () {
    String mappe(String name, String? href) =>
        '<div><h2>$name</h2>'
        '${href == null ? '' : '<a class="btn btn-primary" href="$href">x</a>'}'
        '<div class="btn-group"><button title="Lehrkraft A (LA)">LA</button>'
        '</div></div>';

    final html =
        '<div id="mappen"><div class="row">'
        '${mappe('Mathematik', 'meinunterricht.php?a=sus_view&id=11')}'
        '${mappe('Kaputt', null)}'
        '${mappe('Deutsch', 'meinunterricht.php?a=sus_view&id=12')}'
        '</div></div>'
        '<table>'
        // Gültig, mit Hausaufgabe ohne .realHomework.
        '<tr class="printable" data-entry="e1"><td><span class="datum">'
        '26.10.2026</span><span class="thema">Brüche</span>'
        '<h3><a href="meinunterricht.php?a=sus_view&id=11">M</a></h3>'
        '<span class="homework"></span></td></tr>'
        // Ohne data-entry: übersprungen.
        '<tr class="printable"><td><span class="datum">27.10.2026</span>'
        '<h3><a href="meinunterricht.php?a=sus_view&id=12">D</a></h3></td></tr>'
        '</table>'
        '<div id="anwesend"><table><thead><tr><th>Kurs</th><th>Fehlstunden</th>'
        '</tr></thead><tbody>'
        '<tr><td><a href="meinunterricht.php?a=sus_view&id=11">M</a></td>'
        '<td>2</td></tr>'
        // Zu kurz: übersprungen.
        '<tr><td><a href="meinunterricht.php?a=sus_view&id=12">D</a></td></tr>'
        '</tbody></table></div>';

    test('kaputte Zeilen werden übersprungen, der Rest bleibt', () {
      final r = parseStudentLessons(parse(html));
      expect(r.skipped, 3);
      expect(r.lessons.map((l) => l.name), ['Mathematik', 'Deutsch']);
      final m = r.lessons.first;
      expect(m.courseID, '11');
      expect(m.currentEntry?.entryID, 'e1');
      expect(m.currentEntry?.topicDate, DateTime(2026, 10, 26));
      expect(m.currentEntry?.homework?.description, '');
      expect(m.attendances, {'fehlstunden': '2'});
      expect(r.lessons.last.currentEntry, isNull);
    });

    test('ohne #mappen bleibt es ein Fehler (Neuanmeldung)', () {
      expect(
        () => parseStudentLessons(parse('<html><body>Login</body></html>')),
        throwsA(isA<UnknownException>()),
      );
      // Leere Kursmappen: keine Kurse, kein Fehler.
      expect(
        parseStudentLessons(
          parse('<div id="mappen"><div class="row"></div></div>'),
        ).lessons,
        isEmpty,
      );
    });
  });

  group('Datei-Adresse (fixedLessonFileUrl)', () {
    const base =
        'https://start.schulportal.hessen.de/meinunterricht.php?a=downloadFile&id=1&e=2';
    test('Sonderzeichen landen kodiert im Parameter f', () {
      for (final name in ['a&b.pdf', 'a#b.pdf', 'a+b.pdf', 'a%20b.pdf']) {
        // So baut liblanis die Adresse (student_parser.dart:238).
        final broken = Uri.parse('$base&f=$name');
        final fixed = fixedLessonFileUrl(broken, name)!;
        expect(fixed.queryParameters['f'], name);
        expect(fixed.queryParameters['id'], '1');
        expect(fixed.fragment, isEmpty);
      }
    });

    test('gewöhnliche Namen bleiben Zeichen für Zeichen gleich', () {
      for (final name in ['Blatt 3.pdf', 'Übung (2).docx']) {
        final u = Uri.parse('$base&f=$name');
        expect(fixedLessonFileUrl(u, name).toString(), u.toString());
      }
      expect(fixedLessonFileUrl(null, 'a&b'), isNull);
    });
  });

  group('Sitzung (session_guard.dart)', () {
    test('Zeitlimits gesetzt, Upload mit langem Limit', () async {
      final s = await _session((_) => _text('ok'));
      guardForkSession(s.session, keepAlive: false);
      expect(s.session.dio.options.receiveTimeout, forkReceiveTimeout);
      expect(s.session.dio.options.sendTimeout, forkSendTimeout);
      expect(s.session.dio.options.connectTimeout, const Duration(seconds: 8));

      await s.session.dio.post(
        'https://start.schulportal.hessen.de/meinunterricht.php',
        data: FormData.fromMap({'a': 'sus_abgabe'}),
      );
      expect(s.adapter.seen.last.receiveTimeout, forkUploadTimeout);
      await s.session.dio.get(
        'https://start.schulportal.hessen.de/startseite.php',
      );
      expect(s.adapter.seen.last.receiveTimeout, forkReceiveTimeout);
    });

    test('Bibliotheks-Timer angehalten, eigene Erhaltung nach Anmeldung, '
        'aus beim Anmeldebeginn und Abmelden', () async {
      final s = await _session((_) => _text('ok'));
      final ka = guardForkSession(s.session)!;
      addTearDown(ka.dispose);
      expect(ka.armed, isFalse);

      // Wie session.dart:145 nach dem Login-Link.
      var libTicks = 0;
      s.session.preventLogoutTimer = Timer.periodic(
        const Duration(seconds: 10),
        (_) => libTicks++,
      );
      final libTimer = s.session.preventLogoutTimer!;
      await s.session.dio.get(
        'https://start.schulportal.hessen.de/startseite.php?a=ajax&f=apps',
      );
      expect(libTimer.isActive, isFalse);
      expect(s.session.preventLogoutTimer, isNull);
      expect(ka.armed, isTrue);
      expect(libTicks, 0);

      // Beginn einer (Neu-)Anmeldung, session.dart:131.
      await s.session.dio.get('https://start.schulportal.hessen.de/');
      expect(ka.armed, isFalse);

      s.session.preventLogoutTimer = Timer.periodic(
        const Duration(seconds: 10),
        (_) {},
      );
      await s.session.dio.get('https://start.schulportal.hessen.de/x.php');
      expect(ka.armed, isTrue);
      await s.session.dio.get(
        'https://start.schulportal.hessen.de/index.php?logout=all',
      );
      expect(ka.armed, isFalse);
    });

    test('Erhaltung schluckt Fehler und läuft nie doppelt', () async {
      var calls = 0;
      final gate = Completer<void>();
      final ka = ForkKeepAlive(() async {
        calls++;
        await gate.future;
        throw LanisDownException();
      });
      final first = ka.tick();
      await ka.tick(); // läuft noch → übersprungen
      gate.complete();
      await first;
      expect(calls, 1);
      ka.dispose();
      await ka.tick();
      expect(calls, 1);
    });

    test(
      'ForkSession hängt den Wächter an die Sitzung des Providers',
      () async {
        final adapter = _FakeAdapter((_) => _text('ok'));
        LanisClient.configure(httpAdapter: adapter);
        addTearDown(LanisClient.reset);
        final c = ProviderContainer(
          overrides: [...LanisClient.overrides, ...forkProviderOverrides()],
        );
        addTearDown(c.dispose);
        final id = await c
            .read(accountsProvider.notifier)
            .add(
              schoolId: 1,
              schoolName: 'Testschule',
              username: 'test.user',
              password: 'x',
            );
        await c.read(activeAccountProvider.notifier).select(id);
        final session = (await c.read(sessionProvider.future))!;
        expect(c.read(sessionProvider.notifier), isA<ForkSession>());
        expect(session.dio.options.receiveTimeout, forkReceiveTimeout);
        expect(
          session.dio.interceptors.whereType<ForkSessionGuard>(),
          hasLength(1),
        );
      },
    );
  });

  test('WAL-Modus wird in der Datei gesetzt (db_wal.dart)', () {
    final dir = Directory.systemTemp.createTempSync('fork_wal');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = p.join(dir.path, 'lanis.db');
    expect(enableWalJournal(path), isNull);
    sqlite3.open(path)
      ..execute('CREATE TABLE t (x INTEGER);')
      ..close();
    expect(enableWalJournal(path), 'wal');
    expect(enableWalJournal(path), 'wal');
    final db = sqlite3.open(path);
    addTearDown(db.close);
    expect(db.select('PRAGMA journal_mode;').first.values.first, 'wal');
  });

  group('Datei-Speicher (downloadRevalidated)', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('fork_files'));
    tearDown(() => dir.deleteSync(recursive: true));

    const url = 'https://start.schulportal.hessen.de/meinunterricht.php?f=a';

    test('alte Kopie wird neu geladen, frische bleibt', () async {
      var content = 'neu';
      final s = await _session(
        (_) => ResponseBody.fromBytes(utf8.encode(content), 200),
        cacheDir: dir.path,
      );
      final storage = StorageManager(
        session: s.session,
        config: LanisClient.config!,
        accountId: 1,
      );
      final cached = File(storage.resolvePath(url, 'a.pdf'))
        ..createSync(recursive: true)
        ..writeAsStringSync('alt');
      final now = DateTime.now();
      cached.setLastModifiedSync(now.subtract(const Duration(minutes: 5)));
      expect(
        File(
          await downloadRevalidated(storage, url, 'a.pdf'),
        ).readAsStringSync(),
        'alt',
      );
      cached.setLastModifiedSync(now.subtract(const Duration(hours: 2)));
      expect(
        File(
          await downloadRevalidated(storage, url, 'a.pdf'),
        ).readAsStringSync(),
        'neu',
      );
      expect(File('${cached.path}.old').existsSync(), isFalse);
    });

    test('scheitert der neue Abruf, kommt die alte Kopie', () async {
      final s = await _session(
        (_) => _text('', 302), // Sitzung weg
        cacheDir: dir.path,
      );
      final storage = StorageManager(
        session: s.session,
        config: LanisClient.config!,
        accountId: 1,
      );
      final cached = File(storage.resolvePath(url, 'a.pdf'))
        ..createSync(recursive: true)
        ..writeAsStringSync('alt');
      cached.setLastModifiedSync(
        DateTime.now().subtract(const Duration(days: 2)),
      );
      final path = await downloadRevalidated(storage, url, 'a.pdf');
      expect(File(path).readAsStringSync(), 'alt');
    });
  });
}

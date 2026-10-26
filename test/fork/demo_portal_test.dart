import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:lanis/fork/demo/demo_entry.dart';
import 'package:lanis/fork/demo/demo_mode.dart';
import 'package:lanis/fork/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' show parse;
import 'package:liblanis/liblanis.dart';
import 'package:lanis/fork/demo/demo_portal.dart';
import 'package:lanis/fork/demo/demo_school.dart';
import 'package:lanis/fork/lessons_parent.dart';
import 'package:lanis/fork/timetable_fix.dart';

// Demo-Portal: Die echten Leser von liblanis und lib/fork laufen gegen
// erfundene Seiten. Dienstag, 27.10.2026, 9:00 Uhr.
final _now = DateTime(2026, 10, 27, 9);

Future<LanisSession> _login(String user) async {
  LanisClient.configure(httpAdapter: DemoPortal(now: () => _now));
  final account = ClearTextAccount(
    localId: 1,
    schoolID: demoSchoolId,
    username: user,
    password: 'demo',
    schoolName: demoSchoolName,
  );
  final s = LanisSession(
    account: account,
    config: LanisClient.config!,
    connectionChecker: ConnectionChecker(
      httpAdapter: LanisClient.config!.httpAdapter,
    ),
  );
  await s.prepareDio();
  await s.authenticate();
  return s;
}

Future<String> _get(LanisSession s, String path) async =>
    '${(await s.dio.get('https://start.schulportal.hessen.de/$path')).data}';

void main() {
  tearDown(LanisClient.reset);

  test('Schülerkonto: Anmeldung mit Handshake, Kontoart, Module', () async {
    final s = await _login('demo.lena');
    expect(s.accountTypeOrNull, AccountType.student);
    expect(s.userData['klasse'], '07B');
    expect(s.cryptor.authenticated, isTrue);
    expect(
      s.travelMenu.map((e) => e['link']),
      containsAll([
        'stundenplan.php',
        'vertretungsplan.php',
        'meinunterricht.php',
      ]),
    );
  });

  test('falscher Benutzer wird abgelehnt', () async {
    await expectLater(
      _login('jemand'),
      throwsA(isA<WrongCredentialsException>()),
    );
  });

  test('Stundenplan mit Zeiten und Parallelkursen', () async {
    final s = await _login('demo.lena');
    final tt = parseTimetableKeepingFirstRow(
      parse(await _get(s, 'stundenplan.php')),
    );
    expect(tt.hours, hasLength(8));
    final monday = tt.planForAll![0];
    expect(monday.first.name, 'D');
    expect(
      '${monday.first.startTime.hour}:${monday.first.startTime.minute}',
      '8:0',
    );
    // Dienstag 5.–6.: drei parallele Kurse im Gesamtplan, einer im eigenen.
    expect(tt.planForAll![1].where((x) => x.stunde == 5), hasLength(3));
    expect(tt.planForOwn![1].where((x) => x.stunde == 5).map((x) => x.name), [
      'REV',
    ]);
  });

  test('Vertretungen heute und am nächsten Schultag', () async {
    final s = await _login('demo.lena');
    final shell = await _get(s, 'vertretungsplan.php');
    final dates = SubstitutionsParser.getSubstitutionDates(shell);
    expect(dates, ['27.10.2026', '28.10.2026']);
    final ajax = <String, String>{};
    for (final d in dates) {
      ajax[d] =
          '${(await s.dio.post(
            'https://start.schulportal.hessen.de/vertretungsplan.php',
            queryParameters: {'a': 'my'},
            data: {'tag': d, 'ganzerPlan': 'true'},
            options: Options(contentType: Headers.formUrlEncodedContentType),
          )).data}';
    }
    final plan = SubstitutionsParser.parseDocumentHtml(shell, ajaxByDate: ajax);
    final all = plan.days.expand((d) => d.substitutions).toList();
    expect(
      all.map((x) => x.art),
      containsAll(['Vertretung', 'Entfall', 'Raumänderung']),
    );
    expect(all.every((x) => x.klasse == '07B'), isTrue);
  });

  test('Kalender: Kategorien und Termine', () async {
    final s = await _login('demo.lena');
    final cats = CalendarParser.parseCategoriesHtml(
      await _get(s, 'kalender.php'),
    );
    expect(cats, hasLength(3));
    final body =
        '${(await s.dio.post('https://start.schulportal.hessen.de/kalender.php', queryParameters: {'f': 'getEvents', 's': '', 'start': '2026-10-01', 'end': '2026-12-31'}, data: 'f=getEvents&start=2026-10-01&end=2026-12-31&s=')).data}';
    final events = CalendarParser.parseEventsJson(body, cats);
    expect(events.map((e) => e.title), contains('Wandertag'));
  });

  test('Eltern: Kinder aus der Eltern-Ansicht, Kursmappe lesbar', () async {
    final s = await _login('demo.eltern');
    expect(s.accountTypeOrNull, AccountType.parent);
    final kids = parseParentLessons(parse(await _get(s, 'meinunterricht.php')));
    expect(kids.single.firstName, 'Jonas');
    final math = kids.single.lessons.firstWhere((l) => l.name == 'Mathematik');
    expect(math.currentEntry?.homework?.description, contains('Nr.'));
    expect(math.courseID, endsWith('&p=${demoJonas.id}'));
    final page = await _get(
      s,
      'meinunterricht.php?a=sus_view&id=${math.courseID}',
    );
    expect(page, contains('Klassenarbeit'));
  });

  test('Nachrichten: verschlüsselte Liste lässt sich entschlüsseln', () async {
    final s = await _login('demo.lena');
    final r = await s.dio.post(
      'https://start.schulportal.hessen.de/nachrichten.php',
      data: {'a': 'headers', 'getType': 'All', 'last': '0'},
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );
    final rows = jsonDecode('${r.data}') as Map;
    final text = s.cryptor.decryptString('${rows['rows']}');
    expect(text, contains('Workbook'));
  });

  test('Empfängersuche findet erfundene Lehrkräfte', () async {
    final s = await _login('demo.lena');
    final r = await s.dio.get(
      'https://start.schulportal.hessen.de/nachrichten.php',
      queryParameters: {'a': 'searchRecipt', 'q': 'klemm'},
    );
    final items = (jsonDecode('${r.data}') as Map)['items'] as List;
    expect(items.single['text'], 'Klemm, Petra (KLM)');
  });

  testWidgets('In der Demo: Hinweis statt Senden', (t) async {
    demoActive = true;
    addTearDown(() => demoActive = false);
    var blocked = false;
    await t.pumpWidget(
      MaterialApp(
        localizationsDelegates: ForkL10n.localizationsDelegates,
        supportedLocales: ForkL10n.supportedLocales,
        locale: const Locale('de'),
        home: Scaffold(
          body: Builder(
            builder: (c) => TextButton(
              onPressed: () => blocked = blockedInDemo(c),
              child: const Text('senden'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('senden'));
    await t.pump();
    expect(blocked, isTrue);
    expect(
      find.text('In der Demo wird nichts gesendet oder geändert.'),
      findsOneWidget,
    );
  });
}

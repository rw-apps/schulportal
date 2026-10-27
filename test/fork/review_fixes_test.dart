import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' show parse;
import 'package:lanis/fork/absence/absence_form.dart';
import 'package:lanis/fork/absence/absence_parser.dart';
import 'package:lanis/fork/absence/absence_view.dart';
import 'package:lanis/fork/absences.dart';
import 'package:lanis/fork/exams.dart';
import 'package:lanis/fork/l10n/l10n.dart';
import 'package:lanis/fork/lessons_parent.dart';
import 'package:lanis/fork/ui/courses/absences_page.dart';
import 'package:lanis/fork/ui/courses/course_detail_model.dart';
import 'package:lanis/fork/ui/courses/courses_model.dart';
import 'package:lanis/fork/ui/courses/grades_model.dart';
import 'package:lanis/fork/ui/courses/grades_view.dart';
import 'package:lanis/fork/ui/messages/compose_model.dart';
import 'package:lanis/fork/ui/messages/compose_page.dart';
import 'package:lanis/fork/ui/plan/plan_model.dart';
import 'package:liblanis/liblanis.dart';

/// Regressionstests zur Prüfung vom 27.10.26. Alle Namen, IDs und Kurse
/// sind erfunden.

Widget _app(Widget home) => MaterialApp(
  localizationsDelegates: ForkL10n.localizationsDelegates,
  supportedLocales: ForkL10n.supportedLocales,
  locale: const Locale('de'),
  home: home,
);

Future<void> _tall(WidgetTester t) async {
  t.view.physicalSize = const Size(1080, 4000);
  t.view.devicePixelRatio = 2.5;
  addTearDown(t.view.reset);
}

class _Backend implements ComposeBackend {
  _Backend(this.directory);

  final List<ReceiverEntry> directory;
  final sent = <List<String>>[];

  @override
  Future<List<ReceiverEntry>> search(String q) async => [
    for (final r in directory)
      if (r.name.toLowerCase().contains(q.toLowerCase())) r,
  ];

  @override
  Future<bool> send({
    required List<String> receivers,
    required String subject,
    required String text,
  }) async {
    sent.add(receivers);
    return true;
  }
}

const _anna = RecipientCandidate(
  kuerzel: 'AAA',
  display: 'Anna Alt',
  lastName: 'Alt',
  firstName: 'Anna',
  subjects: ['Mathematik'],
);

Lesson _lesson(String name, String id, {String kz = 'XX'}) => Lesson(
  courseID: id,
  name: name,
  teachers: [LessonTeacher(teacher: 'Lehr, Kraft', teacherKuerzel: kz)],
  courseURL: Uri.parse('meinunterricht.php?id=$id'),
);

ChildLessons _kid(String id, String name) =>
    ChildLessons(pupilId: id, pupilName: name, lessons: const []);

void main() {
  group('1 Empfänger: ganzes Wort, nie raten', () {
    test('Nachname als ganzes Wort, Form „Nachname, Vorname“', () {
      final hits = matchReceivers(const [
        ReceiverEntry('l-1', 'Altmann, Anna', true),
        ReceiverEntry('l-2', 'Walther, Anna', true),
        ReceiverEntry('l-3', 'Bau, Alt', true),
        ReceiverEntry('l-4', 'Alt, Anna', true),
        ReceiverEntry('l-5', 'Anna Alt', true),
        ReceiverEntry('l-6', 'Bau-Alt, Anna', true),
      ], _anna);
      expect(hits.map((h) => h.id), ['l-4', 'l-5']);
    });

    test('einzelner Treffer nur sicher, wenn auch der Vorname passt', () {
      expect(
        isSureReceiver(const ReceiverEntry('l', 'Alt, Anna', true), _anna),
        isTrue,
      );
      expect(
        isSureReceiver(const ReceiverEntry('l', 'Alt, Bernd', true), _anna),
        isFalse,
      );
      expect(
        isSureReceiver(const ReceiverEntry('l', 'Altmann, Anna', true), _anna),
        isFalse,
      );
    });

    testWidgets('Nur-Nachname-Treffer: Auswahl, Rückfrage mit Portal-Namen', (
      t,
    ) async {
      await _tall(t);
      final b = _Backend(const [ReceiverEntry('l-2', 'Alt, Bernd', true)]);
      await t.pumpWidget(
        _app(ComposePage(candidates: const [_anna], backend: b)),
      );
      await t.tap(find.text('Anna Alt'));
      // Ladekreis an der Kachel läuft, solange die Auswahl offen ist – daher
      // feste Schritte statt pumpAndSettle.
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      expect(
        find.text('Welche Person ist Anna Alt?'),
        findsOneWidget,
        reason: 'nicht still „Alt, Bernd“ übernehmen',
      );
      await t.tap(find.text('Alt, Bernd'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField).at(1), 'Betreff');
      await t.enterText(find.byType(TextField).at(2), 'Text');
      await t.pumpAndSettle();
      final send = find.text('Senden an Anna Alt');
      await t.ensureVisible(send);
      await t.pumpAndSettle();
      // Zwei Tipps im selben Bild: nur EINE Rückfrage (Befund 11).
      await t.tap(send);
      await t.tap(send, warnIfMissed: false);
      await t.pumpAndSettle();
      expect(find.text('Nachricht senden?'), findsOneWidget);
      expect(
        find.textContaining('An Alt, Bernd.'),
        findsOneWidget,
        reason: 'Rückfrage nennt den echten Empfänger des Portals',
      );
      await t.tap(find.text('Senden').last);
      await t.pumpAndSettle();
      expect(b.sent, [
        ['l-2'],
      ]);
    });
  });

  group('2/3 Elternkonto mit zwei Kindern', () {
    final kids = [_kid('100', 'Beispiel, Lena'), _kid('200', 'Beispiel, Tom')];
    final lessons = flattenChildLessons([
      ChildLessons(
        pupilId: '100',
        pupilName: 'Beispiel, Lena',
        lessons: [_lesson('Englisch 06a', '1&p=100', kz: 'WOL')],
      ),
      ChildLessons(
        pupilId: '200',
        pupilName: 'Beispiel, Tom',
        lessons: [
          _lesson('Englisch 08b', '2&p=200', kz: 'WOL'),
          _lesson('Projekt: Text 8', '3&p=200'),
        ],
      ),
    ]);
    const en = PlanLesson(
      subject: 'Englisch',
      short: 'E',
      room: 'R1',
      teacher: 'WOL',
    );
    final plan = KidPlan(
      firstName: 'Lena',
      colorIndex: 0,
      slots: const [PlanSlot(label: '1', start: '08:00', end: '08:45')],
      days: [
        for (var d = 0; d < 5; d++)
          [
            const PlanCell([en]),
          ],
      ],
    );

    test('Vorsatz weg nur für den Abgleich, Plan nur des ersten Kindes', () {
      expect(lessons.first.name, startsWith('Lena: '));
      final items = {
        for (final i in courseItemsFrom(lessons, plan: plan, kids: kids))
          i.id: i,
      };
      final lena = items['1&p=100']!;
      expect(lena.title, 'Lena: Englisch', reason: 'Liste bleibt eindeutig');
      expect(lena.subject, 'Englisch');
      expect(lena.planOrder, isNotNull);
      expect(lena.extra, isFalse);
      final tom = items['2&p=200']!;
      expect(tom.inShownPlan, isFalse);
      expect(tom.planOrder, isNull, reason: 'nicht Lenas Plan zuordnen');
      expect(tom.extra, isFalse, reason: 'nicht alles „Weitere Angebote“');
      expect(items['3&p=200']!.subject, 'Projekt: Text');
      expect(
        nextLessonOf(
          plan,
          const {},
          lena.subject,
          lena.teacherCodes.toSet(),
          DateTime(2026, 10, 19, 7),
        ),
        isNotNull,
      );
    });

    test('ein Kind: Name und Abgleich unverändert', () {
      final one = [_lesson('Projekt: Text 6', '9&p=100')];
      final i = courseItemsFrom(one, plan: plan, kids: [kids.first]).single;
      expect(i.subject, 'Projekt: Text');
      expect(i.inShownPlan, isTrue);
      expect(
        courseNameWithoutKid('Lena: Mathe', '9&p=100', [kids.first]),
        'Lena: Mathe',
      );
    });

    test('Entschuldigung nennt das Kind des Kurses', () {
      const a = AbsenceItem(
        course: '2&p=200',
        entry: 'e',
        subject: 'Tom: Englisch',
        status: 'fehlend',
        excused: false,
      );
      final who = excuseChildAndSubject(a, kids, 'Lena');
      expect(who.child, 'Tom');
      expect(who.subject, 'Englisch');
      const b = AbsenceItem(
        course: '1',
        entry: 'e',
        subject: 'Englisch',
        status: 'fehlend',
        excused: false,
      );
      expect(excuseChildAndSubject(b, const [], 'Lena').child, 'Lena');
    });
  });

  test('4 daysUntil zählt Kalendertage (auch über die Zeitumstellung)', () {
    // 1.3. bis 31.7.2027 einschließlich: 31 + 30 + 31 + 30 + 31 = 153. Der
    // alte Code ergab mit TZ=Europe/Berlin 152 (geprüft 27.10.26); in einer
    // Zeitzone ohne Umstellung zeigt der Test den Fehler nicht.
    expect(daysUntil(DateTime(2027, 3, 1, 23), DateTime(2027, 7, 31)), 153);
    expect(daysUntil(DateTime(2026, 10, 1), DateTime(2027, 1, 31)), 123);
  });

  group('5/6 Noten', () {
    DetailedLesson page() => DetailedLesson(
      courseID: 'x',
      name: 'x',
      teachers: const [],
      history: const [],
      marks: const [],
      exams: const [],
      attendances: const {},
    );

    testWidgets('neue Kurs-ID bei gleicher Anzahl wird geladen; Meldung '
        'auch bei vollem Zwischenspeicher', (t) async {
      final loaded = <String>[];
      var reports = 0;
      GradesSource src(List<CourseItem> courses) => GradesSource(
        account: 'review-fixes',
        courses: courses,
        load: (c, {required firstHalf}) async {
          loaded.add(c.id);
          return page();
        },
        onCurrentLoaded: (_) => reports++,
      );
      const a = CourseItem(id: 'a', title: 'A', fullName: 'A');
      const b = CourseItem(id: 'b', title: 'B', fullName: 'B');
      const c = CourseItem(id: 'c', title: 'C', fullName: 'C');
      Widget view(List<CourseItem> courses) => _app(
        Scaffold(
          body: SingleChildScrollView(
            child: GradesView(
              key: const ValueKey('g'),
              now: DateTime(2026, 10, 19),
              source: src(courses),
            ),
          ),
        ),
      );
      GradesCache.instance.clear();
      await t.pumpWidget(view([a, b]));
      await t.pumpAndSettle();
      expect(loaded, ['a', 'b']);
      expect(reports, 1);
      await t.pumpWidget(view([a, c]));
      await t.pumpAndSettle();
      expect(loaded, ['a', 'b', 'c'], reason: 'gleiche Anzahl, neue ID');
      expect(reports, 2);
      // Gleiche IDs, neues Bild: kein neuer Durchgang (keine Schleife).
      await t.pumpWidget(view([a, c]));
      await t.pumpAndSettle();
      expect(reports, 2);
      // Neue Seite, alles im Zwischenspeicher: trotzdem gemeldet.
      await t.pumpWidget(const SizedBox());
      await t.pumpWidget(view([a, c]));
      await t.pumpAndSettle();
      expect(loaded, hasLength(3));
      expect(reports, 3);
      expect(t.takeException(), isNull);
      GradesCache.instance.clear();
    });
  });

  group('7–10 Abwesenheitsmeldung', () {
    const placeholderHtml = '''
<form id="meldungForm">
  <select name="art">
    <option value="">Bitte wählen</option>
    <option value="krank">als abwesend melden</option>
    <option value="beurlaubt">als beurlaubt melden</option>
    <option value="verspätet">als verspätet melden</option>
  </select>
  <select name="stundenVon">
    <option value="">--</option>
    <option value="1">1. Block (08:00 - 09:30)</option>
    <option value="2" selected>2. Block (09:50 - 11:20)</option>
  </select>
  <select name="stundenBis">
    <option value="1">1. Block</option>
    <option value="2">2. Block</option>
    <option value="3" selected>3. Block</option>
  </select>
</form>''';

    test('Platzhalter übergangen, Vorauswahl des Portals gelesen', () {
      final f = parseAbsenceForm(parse(placeholderHtml))!;
      expect(f.kinds.map((k) => k.value), ['krank', 'beurlaubt', 'verspätet']);
      expect(f.blocks.map((b) => b.value), ['1', '2']);
      expect(f.selectedBlockFrom, '2');
      expect(f.selectedBlockTo, '3');
      final fields = AbsenceDraft(
        pupilIds: const ['1'],
        kind: 'krank',
        from: DateTime(2026, 10, 19),
        to: DateTime(2026, 10, 19),
        blockFrom: '1',
        blockTo: '1',
        comment: '',
      ).toFields(f);
      expect(fields['stundenVon'], '2');
      expect(fields['stundenBis'], '3');
    });

    AbsenceForm form(List<AbsenceBlock> blocks) => AbsenceForm(
      pupils: const [
        AbsencePupil(
          id: '1',
          name: 'Lena Beispiel',
          preselected: true,
          allowed: true,
        ),
      ],
      kinds: const [
        AbsenceChoice('krank', 'als abwesend melden'),
        AbsenceChoice('beurlaubt', 'als beurlaubt melden'),
        AbsenceChoice(absenceKindLate, 'als verspätet melden'),
      ],
      blocks: blocks,
      fromRange: null,
      toRange: null,
      defaultFrom: DateTime(2026, 10, 19),
      defaultTo: DateTime(2026, 10, 19),
      rules: const [],
    );

    testWidgets('Art-Beschriftung; Blockfeld folgt dem Neuladen', (t) async {
      await _tall(t);
      const b1 = AbsenceBlock(value: '1', label: '1. Block');
      const b2 = AbsenceBlock(value: '2', label: '2. Block');
      const b3 = AbsenceBlock(value: '3', label: '3. Block');
      await t.pumpWidget(
        _app(Scaffold(body: AbsenceFormView(form: form([b1, b2, b3])))),
      );
      expect(find.text('Verspätet'), findsOneWidget);
      expect(
        find.text('als beurlaubt melden'),
        findsOneWidget,
        reason: 'nicht „Verspätet“',
      );
      await t.tap(find.text('Verspätet'));
      await t.pumpAndSettle();
      List<String?> shown() => [
        for (final d in t.widgetList<DropdownButton<String>>(
          find.byType(DropdownButton<String>),
        ))
          d.value,
      ];
      expect(shown(), ['1', '3']); // bis = letzter Block
      // Neu geladen ohne Block 3: Feld zeigt den geklemmten Wert (wie
      // gesendet), kein Prüffehler.
      await t.pumpWidget(
        _app(Scaffold(body: AbsenceFormView(form: form([b1, b2])))),
      );
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(shown(), ['1', '2']);
    });

    test(
      'abgelaufene Sitzung: neu anmelden, nur die PRÜFUNG wiederholen',
      () async {
        final bodies = <Map<String, String>>[];
        var reauths = 0;
        final answers = <AbsencePostResult>[
          (status: 200, data: '<html><form id="login"></form></html>'),
          (status: 200, data: '{"success": true}'),
        ];
        final r = await checkAbsenceWith(
          fields: const {'art': 'krank', 'check': '0'},
          post: (body) async {
            bodies.add(body);
            return answers.removeAt(0);
          },
          reauth: () async => reauths++,
        );
        expect(r.ok, isTrue);
        expect(reauths, 1);
        expect(bodies, hasLength(2));
        for (final b in bodies) {
          expect(b['check'], '1', reason: 'nie ohne check=1');
          expect(b.containsKey('save'), isFalse);
        }

        // Weiterleitung zweimal: höchstens ein zweiter Versuch, nicht ok.
        var posts = 0;
        final r2 = await checkAbsenceWith(
          fields: const {'art': 'krank'},
          post: (body) async {
            posts++;
            return (status: 302, data: '');
          },
          reauth: () async {},
        );
        expect(r2.ok, isFalse);
        expect(posts, 2);
      },
    );

    testWidgets('Senden bleibt gesperrt', (t) async {
      await _tall(t);
      await t.pumpWidget(
        _app(
          Scaffold(
            body: AbsenceFormView(
              form: form(const [AbsenceBlock(value: '1', label: '1. Block')]),
            ),
          ),
        ),
      );
      final send = t.widget<FilledButton>(
        find.widgetWithText(
          FilledButton,
          'Absenden (folgt nach gemeinsamem Test)',
        ),
      );
      expect(send.onPressed, isNull);
    });
  });

  test('12 Aufklappen nach Titel und erstem Tag, nicht nach Nummer', () {
    CurrentEntry e(String id, String topic, int day) => CurrentEntry(
      entryID: id,
      topicTitle: topic,
      topicDate: DateTime(2026, 10, day),
      files: const [],
      uploads: const [],
    );
    final before = groupHistory([e('2', 'Unit 2: B', 12), e('1', 'Unit 1', 5)]);
    final open = topicGroupKey(before[1]); // „Unit 1“ aufgeklappt
    final after = groupHistory([
      e('4', 'Unit 3', 19),
      e('3', 'Unit 2: C', 14),
      e('2', 'Unit 2: B', 12),
      e('1', 'Unit 1', 5),
    ]);
    expect(after.indexWhere((g) => topicGroupKey(g) == open), 2);
    expect(
      topicGroupKey(after[1]),
      topicGroupKey(before[0]),
      reason: 'neue Stunde im selben Thema ändert den Schlüssel nicht',
    );
  });

  test('13 Kurskachel ohne id wird übergangen', () {
    final kids = parseParentLessons(
      parse('''
<div class="pupilbox"><h2 data-pupil="100">Beispiel, Lena</h2>
  <div id="mappen100"><div class="row">
    <div><h2>Ohne ID</h2><a class="btn btn-primary" href="meinunterricht.php?a=sus_view">öffnen</a></div>
    <div><h2>Mathematik 6a</h2><a class="btn btn-primary" href="meinunterricht.php?a=sus_view&id=501&p=100">öffnen</a></div>
  </div></div>
</div>'''),
    );
    expect(kids.single.lessons.map((l) => l.courseID), ['501&p=100']);
  });
}

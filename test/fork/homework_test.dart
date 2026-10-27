import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/homework_ledger.dart';
import 'package:lanis/fork/l10n/l10n.dart';
import 'package:lanis/fork/ui/courses/courses_model.dart';
import 'package:lanis/fork/ui/courses/courses_page.dart';
import 'package:lanis/fork/ui/courses/homework_archive.dart';
import 'package:liblanis/liblanis.dart';

// Synthetisch – keine echten Kurse oder Aufgaben.
Lesson _l(
  String id,
  String name,
  String entry,
  String? hw, {
  bool done = false,
}) => Lesson(
  courseID: id,
  name: name,
  teachers: const [],
  courseURL: Uri.parse('meinunterricht.php?a=sus_view&id=$id'),
  currentEntry: CurrentEntry(
    entryID: entry,
    files: const [],
    uploads: const [],
    topicDate: DateTime(2026, 10, 14),
    homework: hw == null ? null : Homework(description: hw, homeWorkDone: done),
  ),
);

Widget _app(Widget child) => MaterialApp(
  localizationsDelegates: ForkL10n.localizationsDelegates,
  supportedLocales: ForkL10n.supportedLocales,
  locale: const Locale('de'),
  home: Scaffold(body: child),
);

void main() {
  final now = DateTime(2026, 10, 18, 10);

  test('Protokoll: speichern, laden, aufräumen', () {
    final r = const HomeworkItem(
      course: 'm',
      entry: '7',
      subject: 'Mathematik',
      text: 'S. 12 Nr. 3',
    ).record(done: now, now: now);
    var l = HomeworkLedger.empty.put(r, now);
    final back = HomeworkLedger.decode(l.encode());
    expect(back['m|7']?.isDone, isTrue);
    expect(back['m|7']?.text, 'S. 12 Nr. 3');
    expect(HomeworkLedger.decode('{kaputt').byKey, isEmpty);
    // Älter als ein gutes Jahr fällt beim nächsten Speichern weg.
    final later = now.add(const Duration(days: HomeworkLedger.keepDays + 1));
    l = l.put(
      const HomeworkItem(
        course: 'e',
        entry: '1',
        subject: 'E',
        text: 'x',
      ).record(now: later),
      later,
    );
    expect(l.byKey.keys, ['e|1']);
  });

  test('Offen und erledigt: Portal, App und wieder geöffnet', () {
    final lessons = [
      _l('m', 'Mathematik 9x', '7', 'S. 12 Nr. 3'),
      _l('e', 'Englisch 9x', '4', 'Vokabeln', done: true), // im Portal abgehakt
      _l('d', 'Deutsch 9x', '9', 'Gedicht lernen'),
      _l('b', 'Biologie 9x', '2', null),
    ];
    var ledger = HomeworkLedger.empty;
    var x = homeworkLists(lessons, ledger, subjectOf: (l) => l.name, now: now);
    expect([for (final h in x.open) h.course], ['m', 'd']);
    expect([for (final h in x.done) h.course], ['e']);

    // In der App abgehakt: Mathe erledigt.
    ledger = ledger.put(x.open.first.record(done: now, now: now), now);
    // Englisch in der App wieder geöffnet – geht dem Portal vor.
    ledger = ledger.put(x.done.first.record(now: now), now);
    // Eine ältere, wieder geöffnete Aufgabe, deren Kurs schon weiter ist.
    ledger = ledger.put(
      HomeworkItem(
        course: 'd',
        entry: '5',
        subject: 'Deutsch',
        text: 'Lesen',
        given: DateTime(2026, 10, 1),
      ).record(now: now),
      now,
    );
    x = homeworkLists(lessons, ledger, subjectOf: (l) => l.name, now: now);
    expect({for (final h in x.open) h.key}, {'e|4', 'd|9', 'd|5'});
    expect([for (final h in x.done) h.key], ['m|7']);
    expect(x.done.single.done, now);
  });

  test('Halbjahreswechsel 1. Februar / 1. August', () {
    expect(halfYearAfter(DateTime(2026, 10, 27)), DateTime(2027, 2, 1));
    expect(halfYearAfter(DateTime(2027, 1, 15)), DateTime(2027, 2, 1));
    expect(halfYearAfter(DateTime(2027, 2, 1)), DateTime(2027, 8, 1));
    expect(halfYearAfter(DateTime(2027, 7, 31)), DateTime(2027, 8, 1));
  });

  test('Ablauf: vier Wochen nach der Frist, spätestens Halbjahr', () {
    // Frist bekannt: 4 Wochen danach.
    expect(
      homeworkExpiry(
        given: DateTime(2026, 10, 20),
        due: DateTime(2026, 10, 21),
      ),
      DateTime(2026, 11, 18),
    );
    // Ohne Frist: Halbjahreswechsel.
    expect(homeworkExpiry(given: DateTime(2026, 10, 20)), DateTime(2027, 2, 1));
    // Frist kurz vor dem Wechsel: der Wechsel kommt zuerst.
    expect(
      homeworkExpiry(given: DateTime(2027, 1, 20), due: DateTime(2027, 1, 22)),
      DateTime(2027, 2, 1),
    );
    // Wieder geöffnet: neu ab diesem Tag.
    expect(
      homeworkExpiry(
        given: DateTime(2026, 10, 20),
        due: DateTime(2026, 10, 21),
        reopened: DateTime(2026, 12, 1),
      ),
      DateTime(2026, 12, 29),
    );
    expect(homeworkExpiry(), isNull);
  });

  test(
    'Abgelaufen: nicht erledigt, eigene Liste; wieder geöffnet zählt neu',
    () {
      // Aufgegeben 14.10. (_l); Frist laut Plan 15.10. → abgelaufen ab 12.11.
      DateTime? due(String course, DateTime? given) =>
          course == 'm' ? DateTime(2026, 10, 15) : null;
      final lessons = [
        _l('m', 'Mathematik 9x', '7', 'S. 12 Nr. 3'),
        _l('d', 'Deutsch 9x', '9', 'Gedicht lernen'),
      ];
      var x = homeworkLists(
        lessons,
        HomeworkLedger.empty,
        subjectOf: (l) => l.name,
        dueOf: due,
        now: DateTime(2026, 11, 11),
      );
      expect([for (final h in x.open) h.course], ['m', 'd']);
      expect(x.open.first.due, DateTime(2026, 10, 15));
      x = homeworkLists(
        lessons,
        HomeworkLedger.empty,
        subjectOf: (l) => l.name,
        dueOf: due,
        now: DateTime(2026, 11, 12),
      );
      expect([for (final h in x.open) h.course], ['d']);
      expect([for (final h in x.expired) h.course], ['m']);
      expect(x.done, isEmpty);
      // Ohne Frist (Deutsch) erst zum Halbjahr.
      x = homeworkLists(
        lessons,
        HomeworkLedger.empty,
        subjectOf: (l) => l.name,
        dueOf: due,
        now: DateTime(2027, 2, 1),
      );
      expect([for (final h in x.expired) h.course], ['m', 'd']);
      // Im Archiv wieder geöffnet (12.11.): wieder offen bis 10.12.
      final reopened = DateTime(2026, 11, 12, 18);
      final ledger = HomeworkLedger.empty.put(
        x.expired.first.record(now: reopened),
        reopened,
      );
      x = homeworkLists(
        lessons,
        ledger,
        subjectOf: (l) => l.name,
        dueOf: due,
        now: DateTime(2026, 12, 1),
      );
      expect([for (final h in x.open) h.course], ['m', 'd']);
      x = homeworkLists(
        lessons,
        ledger,
        subjectOf: (l) => l.name,
        dueOf: due,
        now: DateTime(2026, 12, 11),
      );
      expect([for (final h in x.expired) h.course], ['m']);
    },
  );

  testWidgets('Unterricht: abhaken, Rückgängig, Zugang zum Archiv', (t) async {
    t.view.physicalSize = const Size(1080, 2424);
    t.view.devicePixelRatio = 2.625;
    addTearDown(t.view.reset);
    final done = <String>[];
    final reopened = <String>[];
    const item = CourseItem(
      id: 'm',
      title: 'Mathematik',
      fullName: 'M',
      homework: 'S. 12 Nr. 3',
      entry: '7',
    );
    await t.pumpWidget(
      _app(
        CoursesPage(
          items: const [item],
          homework: HomeworkBoard(
            open: const [
              HomeworkItem(
                course: 'm',
                entry: '7',
                subject: 'Mathematik',
                text: 'S. 12 Nr. 3',
              ),
            ],
            doneCount: 2,
            onDone: (h) => done.add(h.key),
            onReopen: (h) => reopened.add(h.key),
            onOpenArchive: () {},
          ),
        ),
      ),
    );
    expect(find.text('Erledigt (2)'), findsOneWidget);
    await t.tap(find.text('Erledigt'));
    await t.pumpAndSettle(); // Meldung fährt ein
    expect(done, ['m|7']);
    expect(find.text('Als erledigt abgehakt.'), findsOneWidget);
    await t.tap(find.widgetWithText(SnackBarAction, 'Rückgängig'));
    await t.pumpAndSettle();
    expect(reopened, ['m|7']);
  });

  testWidgets('Archiv: erledigte Aufgaben mit „Wieder offen“', (t) async {
    final back = <String>[];
    await t.pumpWidget(
      MaterialApp(
        localizationsDelegates: ForkL10n.localizationsDelegates,
        supportedLocales: ForkL10n.supportedLocales,
        locale: const Locale('de'),
        home: HomeworkArchivePage(
          items: [
            HomeworkItem(
              course: 'm',
              entry: '7',
              subject: 'Mathematik',
              text: 'S. 12 Nr. 3',
              given: DateTime(2026, 10, 14),
              done: now,
            ),
          ],
          onReopen: (h) => back.add(h.key),
        ),
      ),
    );
    expect(find.text('S. 12 Nr. 3'), findsOneWidget);
    expect(find.textContaining('aufgegeben'), findsOneWidget);
    expect(find.textContaining('erledigt So 18.10.'), findsOneWidget);
    await t.tap(find.text('Wieder offen'));
    expect(back, ['m|7']);

    await t.pumpWidget(
      MaterialApp(
        localizationsDelegates: ForkL10n.localizationsDelegates,
        supportedLocales: ForkL10n.supportedLocales,
        locale: const Locale('de'),
        home: HomeworkArchivePage(items: const [], onReopen: (_) {}),
      ),
    );
    expect(find.textContaining('Noch keine erledigten'), findsOneWidget);
  });
}

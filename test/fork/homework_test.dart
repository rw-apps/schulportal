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
    var x = homeworkLists(lessons, ledger, subjectOf: (l) => l.name);
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
    x = homeworkLists(lessons, ledger, subjectOf: (l) => l.name);
    expect({for (final h in x.open) h.key}, {'e|4', 'd|9', 'd|5'});
    expect([for (final h in x.done) h.key], ['m|7']);
    expect(x.done.single.done, now);
  });

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

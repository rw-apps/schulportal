import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/l10n/l10n.dart';
import 'package:lanis/fork/ui/courses/courses_model.dart';
import 'package:lanis/fork/ui/courses/courses_page.dart';
import 'package:lanis/fork/ui/courses/grades_model.dart';
import 'package:lanis/fork/ui/courses/grades_view.dart';
import 'package:liblanis/liblanis.dart';

// Synthetische Kurse und Noten – keine echten Daten.
const _courses = [
  CourseItem(id: 'c1', title: 'Mathematik', fullName: 'Mathe 9x', colorSlot: 1),
  CourseItem(
    id: 'c2',
    title: 'Englisch',
    fullName: 'Englisch 9x',
    colorSlot: 0,
  ),
  CourseItem(id: 'c3', title: 'Biologie', fullName: 'Bio 9x'),
  CourseItem(id: 'c4', title: 'Chor', fullName: 'Chor AG', extra: true),
];

DetailedLesson _page(
  String id,
  List<LessonMark> marks, {
  bool second = false,
}) => DetailedLesson(
  courseID: id,
  name: id,
  teachers: const [],
  history: const [],
  marks: marks,
  exams: const [],
  attendances: const {},
  semester1URL: second
      ? Uri.parse('meinunterricht.php?a=sus_view&id=$id&halb=1')
      : null,
);

LessonMark _m(String name, String mark, {String? comment}) =>
    LessonMark(name: name, date: '01.10.2026', mark: mark, comment: comment);

Widget _app(Widget child) => MaterialApp(
  localizationsDelegates: ForkL10n.localizationsDelegates,
  supportedLocales: ForkL10n.supportedLocales,
  locale: const Locale('de'),
  home: Scaffold(body: child),
);

void main() {
  setUp(GradesCache.instance.clear);

  test('Übersicht: Reihenfolge, ohne Noten, Fehler, Halbjahr', () {
    final o = gradesOverview(
      _courses,
      {
        'c1': _page('c1', [_m('Test', '2'), _m('Mündlich', ' ')]),
        'c2': _page('c2', [_m('Vokabeltest', '1-')], second: true),
        'c4': _page('c4', const []),
      },
      {'c3'},
    );
    // Fachfarbe 0 vor 1; leere Note zählt nicht.
    expect([for (final s in o.withMarks) s.course.id], ['c2', 'c1']);
    expect(o.withMarks.last.marks.length, 1);
    expect(o.markCount, 2);
    // Chor (weiteres Angebot) nicht unter „ohne Noten“.
    expect(o.without, isEmpty);
    expect([for (final c in o.failed) c.id], ['c3']);
    expect(o.hasFirstHalf, isTrue);

    expect(currentIsFirstHalf(DateTime(2026, 10, 17)), isTrue);
    expect(currentIsFirstHalf(DateTime(2027, 1, 31)), isTrue);
    expect(currentIsFirstHalf(DateTime(2027, 2, 1)), isFalse);
    expect(currentIsFirstHalf(DateTime(2027, 7, 31)), isFalse);
  });

  testWidgets('Kurse | Noten: Noten je Fach, Zwischenspeicher', (t) async {
    t.view.physicalSize = const Size(1080, 2424);
    t.view.devicePixelRatio = 2.625;
    addTearDown(t.view.reset);
    var calls = 0;
    final source = GradesSource(
      account: 'a1',
      courses: _courses,
      load: (c, {required firstHalf}) async {
        calls++;
        return switch (c.id) {
          'c1' => _page('c1', [
            _m('Klassenarbeit', '2+', comment: 'gut gegliedert'),
          ]),
          'c3' => throw StateError('kaputt'),
          _ => _page(c.id, const []),
        };
      },
    );
    await t.pumpWidget(
      _app(CoursesPage(items: _courses, firstName: 'Kind', grades: source)),
    );
    expect(find.text('Offene Hausaufgaben'), findsOneWidget);
    await t.tap(find.text('Arbeiten & Noten'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('Mathematik'), findsOneWidget);
    expect(find.text('Klassenarbeit'), findsOneWidget);
    expect(find.text('2+'), findsOneWidget);
    expect(find.text('01.10.2026 · gut gegliedert'), findsOneWidget);
    expect(find.text('1 Note'), findsOneWidget);
    expect(find.text('1. Halbjahr'), findsOneWidget);
    expect(find.text('Englisch'), findsOneWidget); // unter „Ohne Noten“
    expect(find.textContaining('1 Kurs konnte nicht'), findsOneWidget);
    expect(find.textContaining('Ohne Durchschnitt'), findsOneWidget);
    expect(calls, 4);

    // Zurück zu Kurse und wieder Noten: nichts wird neu geladen außer dem
    // fehlgeschlagenen Kurs.
    await t.tap(find.text('Fächer & Hausaufgaben'));
    await t.pumpAndSettle();
    await t.tap(find.text('Arbeiten & Noten'));
    await t.pumpAndSettle();
    expect(calls, 5);
  });

  testWidgets('Noten: Leerfall mit Hinweis, 2. Halbjahr mit Umschalter', (
    t,
  ) async {
    final asked = <bool>[];
    await t.pumpWidget(
      _app(
        SingleChildScrollView(
          child: GradesView(
            source: GradesSource(
              account: 'a2',
              courses: _courses.take(2).toList(),
              load: (c, {required firstHalf}) async {
                asked.add(firstHalf);
                return _page(
                  c.id,
                  firstHalf ? [_m('Referat', '1')] : const [],
                  second: !firstHalf,
                );
              },
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Noch keine Noten eingetragen.'), findsOneWidget);
    expect(find.text('2. Halbjahr'), findsOneWidget);
    expect(find.text('Ohne Noten'), findsNothing);
    await t.tap(find.text('1. Halbjahr'));
    await t.pumpAndSettle();
    expect(find.text('Referat'), findsNWidgets(2));
    expect(asked, [false, false, true, true]);
  });
}

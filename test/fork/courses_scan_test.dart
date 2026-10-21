import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/courses_scan.dart';
import 'package:lanis/fork/l10n/l10n.dart';
import 'package:lanis/fork/ui/courses/courses_model.dart';
import 'package:lanis/fork/ui/courses/grades_model.dart';
import 'package:lanis/fork/ui/courses/grades_view.dart';
import 'package:lanis/fork/ui/today/today_from_lanis.dart';
import 'package:lanis/fork/ui/today/today_model.dart';
import 'package:liblanis/liblanis.dart';

// Synthetisch, im Aufbau wie die Kursseiten (Abschnitte „Kommende“ und
// „Alle“, jede Arbeit doppelt) – keine echten Daten.
const _courses = [
  CourseItem(id: 'm', title: 'Mathematik', fullName: 'M', planOrder: 0),
  CourseItem(id: 'e', title: 'Englisch', fullName: 'E', planOrder: 1),
];

DetailedLesson _page({
  List<LessonMark> marks = const [],
  List<LessonExam> exams = const [],
  Map<String, String> att = const {},
}) => DetailedLesson(
  courseID: 'x',
  name: 'x',
  teachers: const [],
  history: const [],
  marks: marks,
  exams: exams,
  attendances: att,
);

final _mathExams = [
  LessonExam(
    name: 'Kommende Leistungskontrolle(n)',
    value: '26.11.2026 Arbeit, 3., 4. Std. (90 Min.)',
  ),
  LessonExam(
    name: 'Alle Leistungskontrolle(n)',
    value: '15.09.2026 Arbeit\n26.11.2026 Arbeit',
  ),
];

LessonMark _m(String v) => LessonMark(name: 'Test', date: '1.10.', mark: v);

final _now = DateTime(2026, 10, 17, 16);

void main() {
  setUp(GradesCache.instance.clear);

  test('Arbeiten: einmal je Kurs und Tag, ausführlich, nur ab heute', () {
    final x = upcomingExams(_courses, {'m': _page(exams: _mathExams)}, _now);
    expect(x.length, 1);
    expect(x.single.day, DateTime(2026, 11, 26));
    expect(x.single.text, 'Arbeit, 3., 4. Std. (90 Min.)');
    expect(x.single.kind, 'Arbeit');
    expect(x.single.hours, '3., 4. Std. (90 Min.)');
    expect(x.single.subject, 'Mathematik');
  });

  test('Fehlzeiten zusammen', () {
    expect(absenceTotals([_page()]), isNull);
    final a = absenceTotals([
      _page(att: {'Anwesend': '20', 'Entschuldigt': '2', 'Fehlend': '1'}),
      _page(att: {'Anwesend': '9', 'Entschuldigt': '3', 'Fehlend': '0'}),
    ]);
    expect(a, (excused: 5, missing: 1));
  });

  test('Auswertung: speichern, Fehlschlag behält alten Stand, Neues', () {
    final first = scanFrom(_courses, {
      'm': _page(marks: [_m('2')], exams: _mathExams),
      'e': _page(),
    }, _now);
    expect(first.marks, {'m': 1, 'e': 0});
    final back = CourseScan.fromJson(first.toJson())!;
    expect(back.marks, first.marks);
    expect(back.exams.single.key, first.exams.single.key);
    expect(back.day, DateTime(2026, 10, 17));
    expect(CourseScan.fromJson({'day': 'kaputt'}), isNull);

    // Ohne alten Stand: nichts ist „neu“.
    final none = newsSince(null, first, const {});
    expect(none.marks, isEmpty);
    expect(none.exams, isEmpty);

    // Englisch schlägt fehl: behält 0, Mathe bekommt eine Note dazu.
    final later = _now.add(const Duration(days: 1));
    final second = scanFrom(
      _courses,
      {
        'm': _page(
          marks: [_m('2'), _m('1')],
          exams: [
            ..._mathExams,
            LessonExam(name: 'Alle', value: '10.12.2026 Lernkontrolle'),
          ],
        ),
      },
      later,
      old: first,
    );
    expect(second.marks, {'e': 0, 'm': 2});
    final n = newsSince(first, second, {'m': 'Mathematik', 'e': 'Englisch'});
    expect(n.marks, ['Mathematik']);
    expect([for (final e in n.exams) e.day], [DateTime(2026, 12, 10)]);

    // Unbekannter Kurs (neues Halbjahr): kein Hinweis.
    final third = scanFrom(
      const [CourseItem(id: 'neu', title: 'Physik', fullName: 'P')],
      {
        'neu': _page(marks: [_m('3')]),
      },
      later,
      old: second,
    );
    expect(newsSince(second, third, {'neu': 'Physik'}).marks, isEmpty);
  });

  test('Heute: Arbeiten aus der Kursmappe, ohne Doppelung mit Kalender', () {
    final scan = scanFrom(_courses, {
      'm': _page(exams: _mathExams),
      'e': _page(
        exams: [
          LessonExam(name: 'Alle', value: '20.10.2026 Vokabeltest'),
          LessonExam(name: 'Alle', value: '20.12.2026 Arbeit'),
        ],
      ),
    }, _now);
    final cal = [
      WeekItem(
        day: DateTime(2026, 10, 20),
        title: 'Englisch-Vokabeltest 9b',
        kind: WeekKind.exam,
        childIndex: 0,
      ),
    ];
    final w = withCourseExams(cal, scan, _now, childIndex: 0);
    // Englisch am 20.10. steht in Kalender und Kursmappe: einmal, und zwar
    // aus der Kursmappe (seit 20.10.26, exams.dart); 26.11. und 20.12.
    // liegen hinter 14 Tagen.
    expect([for (final x in w) x.title], ['Englisch: Vokabeltest']);
    final wide = withCourseExams(cal, scan, _now, childIndex: 1, days: 60);
    expect(
      [for (final x in wide) x.title],
      ['Englisch: Vokabeltest', 'Mathematik: Arbeit'],
    );
    expect(wide.last.time, '3., 4. Std. (90 Min.)');
    expect(wide.last.childIndex, 1);
    // Ohne Kursmappe: Kalender-Arbeit bereinigt (ohne Klassenangabe).
    expect(
      [for (final x in withCourseExams(cal, null, _now)) x.title],
      ['Englisch-Vokabeltest'],
    );
  });

  testWidgets('Noten: Nächste Arbeiten, Fehlstunden, Auswertung gemeldet', (
    t,
  ) async {
    Map<String, DetailedLesson>? reported;
    await t.pumpWidget(
      MaterialApp(
        localizationsDelegates: ForkL10n.localizationsDelegates,
        supportedLocales: ForkL10n.supportedLocales,
        locale: const Locale('de'),
        home: Scaffold(
          body: SingleChildScrollView(
            child: GradesView(
              now: _now,
              source: GradesSource(
                account: 'k',
                courses: _courses,
                load: (c, {required firstHalf}) async => c.id == 'm'
                    ? _page(
                        marks: [_m('2')],
                        exams: _mathExams,
                        att: {'Entschuldigt': '2', 'Fehlend': '0'},
                      )
                    : _page(att: {'Entschuldigt': '1', 'Fehlend': '1'}),
                onCurrentLoaded: (p) => reported = p,
              ),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('Nächste Arbeiten'), findsOneWidget);
    expect(find.text('Mathematik: Arbeit'), findsOneWidget);
    expect(find.text('3., 4. Std. (90 Min.)'), findsOneWidget);
    expect(
      find.text('Fehlstunden im Halbjahr: 3 entschuldigt · 1 fehlend'),
      findsOneWidget,
    );
    expect(find.text('Noten'), findsOneWidget); // Überschrift über den Fächern
    expect(reported?.keys.toSet(), {'m', 'e'});
  });
}

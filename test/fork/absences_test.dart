import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/absences.dart';
import 'package:lanis/fork/data/message_templates.dart';
import 'package:lanis/fork/l10n/l10n.dart';
import 'package:lanis/fork/ui/courses/absences_page.dart';
import 'package:lanis/fork/ui/courses/courses_model.dart';
import 'package:lanis/fork/ui/courses/courses_page.dart';
import 'package:liblanis/liblanis.dart';

// Synthetisch – keine echten Kurse, Lehrkräfte oder Tage.
CurrentEntry _e(String id, DateTime d, String? presence, [String h = '3.']) =>
    CurrentEntry(
      entryID: id,
      files: const [],
      uploads: const [],
      topicDate: d,
      presence: presence,
      schoolHours: h,
    );

DetailedLesson _page(List<CurrentEntry> h) => DetailedLesson(
  courseID: 'x',
  name: 'x',
  teachers: const [],
  history: h,
  marks: const [],
  exams: const [],
  attendances: const {},
);

Widget _app(Widget child) => MaterialApp(
  localizationsDelegates: ForkL10n.localizationsDelegates,
  supportedLocales: ForkL10n.supportedLocales,
  locale: const Locale('de'),
  home: child,
);

void main() {
  test('Fehlstunden aus den Kursmappen, neueste zuerst', () {
    expect(isExcused('entschuldigt'), isTrue);
    expect(isExcused('unentschuldigt'), isFalse);
    expect(isExcused('fehlend'), isFalse);
    const courses = [
      CourseItem(
        id: 'n',
        title: 'Naturwissenschaften',
        fullName: 'N',
        teacherCodes: ['AB'],
      ),
      CourseItem(id: 'm', title: 'Mathematik', fullName: 'M'),
    ];
    final x = absencesFrom(courses, {
      'n': _page([
        _e('1', DateTime(2026, 9, 21), 'fehlend'),
        _e('2', DateTime(2026, 9, 28), 'anwesend'),
        _e('3', DateTime(2026, 9, 14), null), // nicht erfasst
      ]),
      'm': _page([_e('9', DateTime(2026, 10, 5), 'entschuldigt', '1. - 2.')]),
    });
    expect([for (final a in x) a.key], ['m|9', 'n|1']);
    expect(x.last.excused, isFalse);
    expect(x.last.teacherCodes, ['AB']);
    expect(x.first.hours, '1. - 2.');

    final sent = {'n|1': DateTime(2026, 10, 18)};
    expect(decodeSent(encodeSent(sent)), sent);
    expect(decodeSent('{kaputt'), isEmpty);

    final m = absenceExcuse(
      child: 'Lena',
      subject: 'Mathematik',
      when: 'Montag, 21.9.2026 (3. Stunde)',
    );
    expect(
      m.subject,
      'Entschuldigung Lena – Mathematik am Montag, 21.9.2026 (3. Stunde)',
    );
    expect(m.text, contains('Grund: '));
  });

  testWidgets('Übersicht: offen mit Entschuldigen, entschuldigt, Vermerk', (
    t,
  ) async {
    final asked = <String>[];
    final items = [
      AbsenceItem(
        course: 'n',
        entry: '1',
        subject: 'Naturwissenschaften',
        status: 'fehlend',
        excused: false,
        day: DateTime(2026, 9, 21),
        hours: '3.',
      ),
      AbsenceItem(
        course: 'm',
        entry: '9',
        subject: 'Mathematik',
        status: 'entschuldigt',
        excused: true,
        day: DateTime(2026, 10, 5),
      ),
      AbsenceItem(
        course: 'n',
        entry: '4',
        subject: 'Naturwissenschaften',
        status: 'unentschuldigt',
        excused: false,
        day: DateTime(2026, 9, 7),
      ),
    ];
    await t.pumpWidget(
      _app(
        AbsencesView(
          items: items,
          firstName: 'Lena',
          sent: {'n|4': DateTime(2026, 10, 18)},
          onExcuse: (a) => asked.add(a.key),
        ),
      ),
    );
    expect(
      find.text('2 Stunden nicht entschuldigt · 1 entschuldigt'),
      findsOneWidget,
    );
    expect(find.text('Nicht entschuldigt'), findsOneWidget);
    expect(find.text('3. Stunde · fehlend'), findsOneWidget);
    expect(find.textContaining('Entschuldigung gesendet'), findsOneWidget);
    expect(find.text('Erneut schreiben'), findsOneWidget);
    await t.tap(find.text('Entschuldigen'));
    expect(asked, ['n|1']);

    // Nur ein Fach, Schülerkonto: Hinweis statt Knopf.
    await t.pumpWidget(
      _app(AbsencesView(items: items, focus: 'm', onClearFocus: () {})),
    );
    expect(find.text('Naturwissenschaften'), findsNothing);
    expect(find.textContaining('alle Fächer zeigen'), findsOneWidget);
    await t.pumpWidget(_app(AbsencesView(items: items)));
    expect(find.textContaining('nur ein Elternkonto'), findsOneWidget);
    expect(find.text('Entschuldigen'), findsNothing);
  });

  testWidgets('Unterricht: Fach mit Fehlstunden öffnet Abwesenheiten', (
    t,
  ) async {
    t.view.physicalSize = const Size(1080, 2424);
    t.view.devicePixelRatio = 2.625;
    addTearDown(t.view.reset);
    final opened = <String?>[];
    await t.pumpWidget(
      _app(
        Scaffold(
          body: CoursesPage(
            items: const [
              CourseItem(
                id: 'n',
                title: 'Naturwissenschaften',
                fullName: 'N',
                missing: 1,
                planOrder: 0,
              ),
              CourseItem(
                id: 'm',
                title: 'Mathematik',
                fullName: 'M',
                planOrder: 1,
              ),
            ],
            onOpenAbsences: opened.add,
          ),
        ),
      ),
    );
    expect(find.text('1 Fehlstunde nicht entschuldigt'), findsOneWidget);
    await t.tap(find.text('1 Fehlstunde nicht entschuldigt'));
    await t.tap(find.text('Abwesenheiten ansehen'));
    expect(opened, ['n', null]);
  });
}

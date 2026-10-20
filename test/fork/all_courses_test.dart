import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/exams.dart';
import 'package:lanis/fork/homework_ledger.dart';
import 'package:lanis/fork/ui/courses/courses_page.dart';
import 'package:liblanis/liblanis.dart';

import '../helpers/test_app.dart';

void main() {
  tearDown(LanisClient.reset);

  testWidgets('Alle: Hausaufgaben und Arbeiten mit Kind, Abhaken', (t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    var done = 0;
    await pumpTestApp(
      t,
      locale: const Locale('de'),
      child: Scaffold(
        body: AllCoursesView(
          now: DateTime(2026, 10, 20),
          homework: [
            AllHomework(
              item: const HomeworkItem(
                course: 'm',
                entry: '1',
                subject: 'Mathematik',
                text: 'Buch S. 42',
              ),
              kid: (name: 'Lena', color: 1),
              onDone: () => done++,
              onReopen: () {},
            ),
          ],
          exams: [
            AllExam(
              exam: UpcomingExam(
                day: DateTime(2026, 10, 22),
                subject: 'Englisch',
                kind: 'Arbeit',
              ),
              kid: (name: 'Jonas', color: 0),
            ),
          ],
          missing: const [],
        ),
      ),
    );
    expect(find.text('Buch S. 42'), findsOneWidget);
    expect(find.text('Lena'), findsOneWidget);
    expect(find.text('Jonas'), findsOneWidget);
    expect(find.text('Englisch: Arbeit'), findsOneWidget);
    await t.tap(find.text('Erledigt'));
    // Übergang (homework_section.dart): erst Haken und gestrichen, dann
    // zuklappen, erst danach gilt die Aufgabe als erledigt.
    await t.pump();
    expect(done, 0);
    await t.pumpAndSettle();
    expect(done, 1);
    expect(find.text('Buch S. 42'), findsNothing);
    expect(find.text('Als erledigt abgehakt.'), findsOneWidget);
  });
}

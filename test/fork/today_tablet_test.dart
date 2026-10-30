import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/l10n/l10n.dart';
import 'package:lanis/fork/ui/today/today_model.dart';
import 'package:lanis/fork/ui/today/today_page.dart';

/// Heute auf dem Tablet (Entwurf A, 30.10.26) – synthetisch.
void main() {
  final now = DateTime(2026, 10, 30, 10);
  ChildToday kid(String name, int c) => ChildToday(
    firstName: name,
    school: 'Beispielschule',
    className: '7X',
    colorIndex: c,
    lessons: const [
      DayLesson(slot: '1.', subject: 'Deutsch', start: '08:00', end: '08:45'),
      DayLesson(slot: '2.', subject: 'Englisch', start: '08:50', end: '12:00'),
    ],
  );
  final data = FamilyToday(
    now: now,
    kids: [kid('Lena', 0), kid('Jonas', 1)],
    week: [
      WeekItem(
        day: DateTime(2026, 11, 5),
        title: 'Elternabend',
        kind: WeekKind.event,
        childIndex: 0,
      ),
    ],
  );

  Future<void> pump(WidgetTester t, Size size) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        localizationsDelegates: ForkL10n.localizationsDelegates,
        supportedLocales: ForkL10n.supportedLocales,
        locale: const Locale('de'),
        home: Scaffold(body: TodayPage(data: data)),
      ),
    );
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  }

  testWidgets('hoch: Kinder nebeneinander, Termine darunter', (t) async {
    await pump(t, const Size(800, 1280));
    final lena = t.getTopLeft(find.text('Lena').first);
    final jonas = t.getTopLeft(find.text('Jonas').first);
    expect(lena.dy, jonas.dy);
    expect(jonas.dx, greaterThan(lena.dx));
    expect(t.getTopLeft(find.text('Demnächst')).dy, greaterThan(lena.dy + 100));
  });

  testWidgets('quer: drei Spalten', (t) async {
    await pump(t, const Size(1280, 800));
    final jonas = t.getTopLeft(find.text('Jonas').first);
    final up = t.getTopLeft(find.text('Demnächst'));
    expect(up.dx, greaterThan(jonas.dx));
    expect(up.dy, lessThan(jonas.dy + 60));
  });
}

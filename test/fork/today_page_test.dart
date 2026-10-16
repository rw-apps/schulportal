import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/ui/preview/demo_family.dart';
import 'package:lanis/fork/ui/preview/preview_shell.dart';
import 'package:lanis/fork/ui/today/today_model.dart';
import 'package:lanis/fork/ui/today/today_page.dart';

/// Pixel 9a: 1080 × 2424 px bei 2.625 → ca. 411 × 923 dp.
Future<void> _pixel(WidgetTester t) async {
  t.view.physicalSize = const Size(1080, 2424);
  t.view.devicePixelRatio = 2.625;
  t.view.padding = const FakeViewPadding(top: 120, bottom: 63);
  addTearDown(t.view.reset);
}

Widget _app({required Brightness b, double scale = 1.0}) => MaterialApp(
  theme: ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.deepPurple,
      brightness: b,
    ),
  ),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: const PreviewShell(),
);

const _day = [
  DayLesson(slot: '1.', subject: 'A', start: '08:00', end: '08:45'),
  DayLesson(slot: '2.', subject: 'B', start: '08:45', end: '09:30',
      change: ChangeKind.cancelled),
  DayLesson(slot: '3.', subject: 'C', start: '09:50', end: '10:35'),
];
DateTime _at(int h, int m) => DateTime(2026, 10, 20, h, m);

void main() {
  group('dayStatus', () {
    test('vor Schulbeginn: erste Stunde', () {
      final s = dayStatus(_day, _at(7, 30));
      expect(s.phase, DayPhase.before);
      expect(s.next, 0);
    });
    test('läuft: Restminuten, Fortschritt, Ausfall übersprungen', () {
      final s = dayStatus(_day, _at(8, 15));
      expect(s.phase, DayPhase.running);
      expect(s.current, 0);
      expect(s.minutesLeft, 30);
      expect(s.progress, closeTo(15 / 45, 1e-9));
      expect(s.next, 2, reason: 'Stunde 2 fällt aus, Danach ist 3.');
    });
    test('ausgefallene Stunde läuft nie', () {
      final s = dayStatus(_day, _at(9, 0));
      expect(s.phase, DayPhase.gap);
      expect(s.next, 2);
    });
    test('Schulschluss und freier Tag', () {
      expect(dayStatus(_day, _at(11, 0)).phase, DayPhase.over);
      expect(dayStatus(const [], _at(9, 0)).phase, DayPhase.noLessons);
    });
    test('Pause vor Abschnitt', () {
      expect(gapBefore(_day, 2), 20);
      expect(gapBefore(_day, 0), 0);
    });
  });

  test('Datumstexte und Schulwoche', () {
    final now = DateTime(2026, 10, 20, 10, 50);
    expect(relativeDay(DateTime(2026, 10, 20), now), 'Heute');
    expect(relativeDay(DateTime(2026, 10, 21), now), 'Morgen');
    expect(relativeDay(DateTime(2026, 10, 22), now), 'Do 22.10.');
    expect(dateCaps(now), 'DIENSTAG, 20. OKTOBER');
    expect(greetingFor(now), 'Guten Morgen');
    expect(schoolWeek(now).first, DateTime(2026, 10, 19));
    // Samstag: schon die nächste Woche
    expect(schoolWeek(DateTime(2026, 10, 24)).first, DateTime(2026, 10, 26));
  });

  test('Wichtig: nur heute und morgen, nach Tag sortiert', () {
    final items = importantItems(demoFamily());
    expect(items.map((e) => e.$2.subject), ['Deutsch', 'Sport']);
  });

  for (final b in Brightness.values) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('Heute: $b, Schrift ×$scale ohne Überlauf', (t) async {
        await _pixel(t);
        await t.pumpWidget(_app(b: b, scale: scale));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        expect(find.text('Lena'), findsOneWidget);
        expect(find.textContaining('Vertretung Hr. Sommer'), findsOneWidget);
        expect(find.textContaining('NOCH 30 MIN.'), findsOneWidget);

        // Langer Tag aufklappen: alle 6 Abschnitte, Mittagspause sichtbar.
        final open = find.text('Ganzen Tag zeigen').first;
        await t.drag(find.byType(CustomScrollView), const Offset(0, -250));
        await t.pumpAndSettle();
        await t.tap(open, warnIfMissed: true);
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        expect(find.text('Musik', skipOffstage: false), findsOneWidget);
        expect(find.text('Pause bis 14:00', skipOffstage: false), findsOneWidget);
        expect(find.text('Vertretung: Hr. Sommer, R 112', skipOffstage: false),
            findsOneWidget);

        await t.drag(find.byType(CustomScrollView), const Offset(0, -6000));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        expect(find.text('Demnächst'), findsOneWidget);
      });
    }
  }

  testWidgets('Krankmeldung nur bei Schule mit Modul', (t) async {
    await _pixel(t);
    await t.pumpWidget(_app(b: Brightness.dark));
    expect(demoFamily().kids.where((k) => k.canReportAbsence), hasLength(1));
    final btn = find.text('Krank melden');
    await t.scrollUntilVisible(btn, 300,
        scrollable: find.byType(Scrollable).first);
    expect(btn, findsOneWidget);
    await t.ensureVisible(btn);
    await t.pumpAndSettle();
    await t.tap(btn, warnIfMissed: true);
    await t.pump();
    expect(find.textContaining('noch ohne Funktion'), findsOneWidget);
  });

  testWidgets('Leiste: Ziele wechseln, Platzhalter', (t) async {
    await _pixel(t);
    await t.pumpWidget(_app(b: Brightness.light));
    await t.tap(find.text('Plan'));
    await t.pumpAndSettle();
    expect(find.textContaining('Entwurf folgt'), findsOneWidget);
  });
}

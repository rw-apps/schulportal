import 'package:flutter/material.dart';
import 'package:lanis/fork/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/ui/preview/demo_family.dart';
import 'package:lanis/fork/ui/preview/preview_shell.dart';
import 'package:lanis/fork/ui/today/today_model.dart';
import 'package:lanis/fork/ui/today/today_page.dart';

final de = forkL10nFor('de');

/// Hinweiszeile „Fach  Art“ (_HintLine, ein Text.rich).
Finder _hint(String s) => find.text(s, findRichText: true);

/// Pixel 9a: 1080 × 2424 px bei 2.625 → ca. 411 × 923 dp.
Future<void> _pixel(WidgetTester t) async {
  t.view.physicalSize = const Size(1080, 2424);
  t.view.devicePixelRatio = 2.625;
  t.view.padding = const FakeViewPadding(top: 120, bottom: 63);
  addTearDown(t.view.reset);
}

Widget _app({required Brightness b, double scale = 1.0}) => MaterialApp(
  localizationsDelegates: ForkL10n.localizationsDelegates,
  supportedLocales: ForkL10n.supportedLocales,
  locale: const Locale('de'),

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
  DayLesson(
    slot: '2.',
    subject: 'B',
    start: '08:45',
    end: '09:30',
    change: ChangeKind.cancelled,
  ),
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
    expect(relativeDay(de, DateTime(2026, 10, 20), now), 'Heute');
    expect(relativeDay(de, DateTime(2026, 10, 21), now), 'Morgen');
    expect(relativeDay(de, DateTime(2026, 10, 22), now), 'Do 22.10.');
    expect(dateCaps(de, now), 'DIENSTAG, 20. OKTOBER');
    expect(greetingFor(de, now), 'Guten Morgen');
    expect(schoolWeek(now).first, DateTime(2026, 10, 19));
    // Samstag: schon die nächste Woche
    expect(schoolWeek(DateTime(2026, 10, 24)).first, DateTime(2026, 10, 26));
  });

  testWidgets('Heute: Hinweise und Stundenplan an der Karte, Tablet', (
    t,
  ) async {
    final opened = <String>[];
    Widget page() => MaterialApp(
      localizationsDelegates: ForkL10n.localizationsDelegates,
      supportedLocales: ForkL10n.supportedLocales,
      locale: const Locale('de'),
      home: Scaffold(
        body: TodayPage(
          data: demoFamily(),
          onOpenDay: (c, _) => opened.add(c.firstName),
        ),
      ),
    );
    await _pixel(t);
    await t.pumpWidget(page());
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    // Hinweise je Tag gruppiert (Abnahme 30.10.26): heute die Vertretung,
    // morgen Ausfall und Arbeit – je eine Zeile, Anzahl rechts im Kopf.
    expect(find.text('HEUTE'), findsOneWidget);
    expect(find.text('MITTWOCH, 21. OKT.'), findsOneWidget);
    expect(_hint('Deutsch  Vertretung'), findsOneWidget);
    expect(_hint('Sport  fällt aus'), findsOneWidget);
    expect(_hint('Englisch  Klassenarbeit'), findsOneWidget);
    expect(find.textContaining('Morgen · '), findsNothing);
    // Die Lehrkraft steht nicht mehr in der Zeile, bleibt aber für den
    // Bildschirmleser erreichbar.
    final sem = t.ensureSemantics();
    expect(find.bySemanticsLabel(RegExp('Tim Sommer')), findsOneWidget);
    sem.dispose();
    expect(find.text('Hinweise'), findsWidgets);
    expect(find.text('Stundenplan'), findsNWidgets(2));
    // Die umrandete Fläche, „Ganzer Tag“ und eine Hinweiszeile öffnen den
    // Tag.
    await t.tap(find.textContaining('Danach').first);
    await t.tap(find.text('Ganzer Tag').first);
    await t.tap(_hint('Deutsch  Vertretung'));
    expect(opened, ['Lena', 'Lena', 'Lena']);
    // Tablet: Termine neben den Kindern, ohne Scrollen sichtbar.
    t.view.physicalSize = const Size(1600, 2560);
    t.view.devicePixelRatio = 2.0;
    await t.pumpWidget(page());
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    final lena = t.getTopLeft(find.text('Lena').first);
    final soon = t.getTopLeft(find.text('Demnächst'));
    expect(soon.dx, greaterThan(lena.dx + 200));
  });

  for (final b in Brightness.values) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('Heute: $b, Schrift ×$scale ohne Überlauf', (t) async {
        await _pixel(t);
        await t.pumpWidget(_app(b: b, scale: scale));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        expect(find.text('Lena'), findsOneWidget);
        expect(_hint('Deutsch  Vertretung'), findsOneWidget);
        expect(find.textContaining('NOCH 30 MIN.'), findsOneWidget);

        await t.drag(find.byType(Scrollable).first, const Offset(0, -6000));
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
    await t.scrollUntilVisible(
      btn,
      300,
      scrollable: find.byType(Scrollable).first,
    );
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
    // Leiste nach Konzept 17.10.26 (Variante A).
    for (final l in [
      'Heute',
      'Kalender',
      'Unterricht',
      'Nachrichten',
      'Mehr',
    ]) {
      expect(find.text(l), findsWidgets);
    }
    await t.tap(find.text('Mehr'));
    await t.pumpAndSettle();
    expect(find.text('Mehr'), findsNWidgets(2), reason: 'Titel und Leiste');
    await t.tap(find.text('Kalender'));
    await t.pumpAndSettle();
    await t.tap(find.text('Termine'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });

  testWidgets('Zurück führt erst nach „Heute“', (t) async {
    await _pixel(t);
    await t.pumpWidget(_app(b: Brightness.light));
    await t.tap(find.text('Mehr'));
    await t.pumpAndSettle();
    expect(find.text('Mehr'), findsNWidgets(2));
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.text('Mehr'), findsOneWidget);
    expect(find.text('Dienstag, 20. Oktober'), findsOneWidget);
  });
}

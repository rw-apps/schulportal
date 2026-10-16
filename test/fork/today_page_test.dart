import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/ui/preview/demo_family.dart';
import 'package:lanis/fork/ui/preview/preview_shell.dart';
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

void main() {
  test('relativeDay', () {
    final now = DateTime(2026, 10, 20, 10, 50);
    expect(relativeDay(DateTime(2026, 10, 20), now), 'Heute');
    expect(relativeDay(DateTime(2026, 10, 21), now), 'Morgen');
    expect(relativeDay(DateTime(2026, 10, 22), now), 'Do 22.10.');
  });

  for (final b in Brightness.values) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('Heute: $b, Schrift ×$scale ohne Überlauf', (t) async {
        await _pixel(t);
        await t.pumpWidget(_app(b: b, scale: scale));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        expect(find.text('Lena'), findsOneWidget);
        expect(find.textContaining('Vertretung: Hr. Sommer'), findsOneWidget);
        await t.scrollUntilVisible(
          find.text('Jonas'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        expect(t.takeException(), isNull);
        // Ganz nach unten: Wochenliste sichtbar, nichts unter der Leiste.
        await t.drag(find.byType(CustomScrollView), const Offset(0, -4000));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        expect(find.textContaining('Pädagogischer Tag'), findsOneWidget);
      });
    }
  }

  testWidgets('Krankmeldung nur bei Schule mit Modul', (t) async {
    await _pixel(t);
    await t.pumpWidget(_app(b: Brightness.dark));
    // Demo: nur Jonas' Schule bietet die Krankmeldung an.
    expect(demoFamily().kids.where((k) => k.canReportAbsence), hasLength(1));
    final chip = find.byTooltip('Krank melden');
    await t.scrollUntilVisible(chip, 300, scrollable: find.byType(Scrollable).first);
    expect(chip, findsOneWidget);
    await t.ensureVisible(chip);
    await t.pumpAndSettle();
    await t.tap(chip, warnIfMissed: true);
    await t.pumpAndSettle();
    await t.pump();
    expect(find.textContaining('noch ohne Funktion'), findsOneWidget);
  });
}

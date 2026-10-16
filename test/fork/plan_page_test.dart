import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/ui/plan/plan_model.dart';
import 'package:lanis/fork/ui/plan/plan_page.dart';
import 'package:lanis/fork/ui/preview/demo_plan.dart';
import 'package:lanis/fork/ui/preview/preview_shell.dart';

Future<void> _pixel(WidgetTester t) async {
  t.view.physicalSize = const Size(1080, 2424);
  t.view.devicePixelRatio = 2.625;
  t.view.padding = const FakeViewPadding(top: 120, bottom: 63);
  addTearDown(t.view.reset);
}

Widget _app({Brightness b = Brightness.light, double scale = 1.0}) =>
    MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple, brightness: b),
      ),
      builder: (c, w) => MediaQuery(
        data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
        child: w!,
      ),
      home: const PreviewShell(),
    );

Future<void> _openPlan(WidgetTester t, {String? kid}) async {
  await t.tap(find.text('Plan'));
  await t.pumpAndSettle();
  if (kid != null) {
    await t.tap(find.text(kid));
    await t.pumpAndSettle();
  }
}

void main() {
  final lena = demoPlans()[0];
  final jonas = demoPlans()[1];

  group('Modell', () {
    test('Parallelgruppen offen, nach Wahl nur die eigene', () {
      final fr = jonas.days[4][1]; // Freitag 1. Block, vier Textil-Gruppen
      expect(resolveCell(fr, {}), isA<ResolvedOpen>());
      final chosen = resolveCell(fr, {'TXT': 'BRU'});
      expect((chosen as ResolvedLesson).lesson.teacher, 'BRU');
    });

    test('Wahl gilt für alle Stunden des Fachs', () {
      final c = {'TXT': 'ABE'};
      final doBlock = resolveCell(jonas.days[3][1], c) as ResolvedLesson;
      final frBlock = resolveCell(jonas.days[4][1], c) as ResolvedLesson;
      expect(doBlock.lesson.room, 'R101', reason: 'Do mit Raumwechsel');
      expect(frBlock.lesson.room, 'R106');
      expect(openGroupSubjects(jonas, c), isEmpty);
    });

    test('verschiedene Fächer parallel: Wechsel lässt nur eines gewählt', () {
      var c = applyGroupChoice(lena, {}, 'ER', groupOptions(lena, 'ER')[0]);
      expect(c, {'ER': 'ABE'});
      c = applyGroupChoice(lena, c, 'ER', groupOptions(lena, 'ER')[2]);
      expect(c, {'Eth': 'CEL'}, reason: 'Ev. Religion darf nicht bleiben');
      final mi = resolveCell(lena.days[2][4], c) as ResolvedLesson;
      expect(mi.lesson.subject, 'Ethik');
      expect(applyGroupChoice(lena, c, 'ER', null), isEmpty);
    });

    test('Gruppenwahl zeigt Stammraum, nicht Ausweichraum', () {
      final abe = groupOptions(jonas, 'TXT').firstWhere((o) => o.teacher == 'ABE');
      expect(abe.room, 'R106');
      expect(groupOptions(jonas, 'TXT'), hasLength(4));
    });

    test('Doppelstunden als ein Abschnitt, Ränder ohne Leerstunden', () {
      final di = dayBlocks(lena, 1, {});
      expect(di.map((b) => blockLabel(lena, b)),
          ['1.–2.', '3.–4.', '5.', '6.', '7.', '8.']);
      final mo = dayBlocks(jonas, 0, {});
      expect(blockLabel(jonas, mo.first), '1. Block',
          reason: '0. Block leer → entfällt');
      expect(blockLabel(jonas, mo.last), '3.–4. Block');
    });

    test('Fachfarben: verschiedene Fächer verschiedene Plätze', () {
      final slots = subjectColorSlots(jonas);
      expect(slots.values.toSet().length, slots.length);
      expect(slots['NaWi'], 0, reason: 'Mo 1. Block zuerst');
    });

    test('Kurzformen im Raster', () {
      PlanLesson l(String s) => PlanLesson(subject: s, short: 'X');
      expect(gridName(l('Biologie')), 'Bio');
      expect(gridName(l('Englisch')), 'Englisch');
      expect(gridName(l('Mathematik')), 'Mathe');
      expect(gridName(l('Astronomieprojekt')), 'X');
    });

    test('ganz leere Stunden fehlen im Wochenraster', () {
      expect(usedSlots(jonas), [1, 2, 3, 4]);
      expect(usedSlots(lena), [0, 1, 2, 3, 4, 5, 6, 7]);
    });
  });

  for (final b in Brightness.values) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('Plan: $b, Schrift ×$scale, Tag und Woche ohne Überlauf',
          (t) async {
        await _pixel(t);
        await t.pumpWidget(_app(b: b, scale: scale));
        await _openPlan(t);
        expect(t.takeException(), isNull);
        expect(find.text('Mathematik'), findsOneWidget);
        expect(find.text('läuft'), findsOneWidget);
        await t.tap(find.text('Woche'));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        await _openPlan(t, kid: 'Jonas');
        expect(t.takeException(), isNull);
        await t.tap(find.text('Tag'));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
      });
    }
  }

  testWidgets('Gruppe wählen: Hinweis weg, Freitag zeigt nur die eigene',
      (t) async {
    await _pixel(t);
    await t.pumpWidget(_app());
    await _openPlan(t, kid: 'Jonas');
    expect(find.text('Gruppe wählen:'), findsOneWidget);

    await t.tap(find.text('Textil'));
    await t.pumpAndSettle();
    expect(find.text('Textil – Gruppe wählen'), findsOneWidget);
    await t.tap(find.text('Gruppe BRU'));
    await t.pumpAndSettle();

    expect(find.text('Gruppe wählen:'), findsNothing);
    await t.tap(find.text('Fr'));
    await t.pumpAndSettle();
    expect(find.text('Textil'), findsOneWidget);
    expect(find.textContaining('4 Gruppen'), findsNothing);

    // Wahl bleibt beim Wechsel der Leiste erhalten.
    await t.tap(find.text('Heute'));
    await t.pumpAndSettle();
    await _openPlan(t, kid: 'Jonas');
    expect(find.text('Gruppe wählen:'), findsNothing);
  });

  testWidgets('Woche: Tag antippen öffnet die Tagesansicht', (t) async {
    await _pixel(t);
    await t.pumpWidget(_app());
    await _openPlan(t);
    await t.tap(find.text('Woche'));
    await t.pumpAndSettle();
    await t.tap(find.text('22.'));
    await t.pumpAndSettle();
    expect(find.text('Physik'), findsOneWidget);
  });

  testWidgets('Woche passt ohne Scrollen auf den Pixel', (t) async {
    await _pixel(t);
    await t.pumpWidget(_app(scale: 1.15));
    await _openPlan(t);
    await t.tap(find.text('Woche'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(
      find.descendant(
        of: find.byType(WeekGrid),
        matching: find.byType(SingleChildScrollView),
      ).evaluate().where((e) =>
          (e.widget as SingleChildScrollView).scrollDirection ==
              Axis.vertical &&
          (e.widget as SingleChildScrollView).physics == null),
      isEmpty,
      reason: '8 Stunden passen bei ×1,15 ohne Scrollen',
    );
    // Letzte Stunde (Musik, Di 8.) endet über der Leiste.
    final musik = t.getRect(find.text('Musik'));
    final nav = t.getRect(find.byType(FloatingNavBar));
    expect(musik.bottom, lessThan(nav.top));
  });

  testWidgets('Tagesansicht endet über der Leiste', (t) async {
    await _pixel(t);
    await t.pumpWidget(_app());
    await _openPlan(t);
    await t.drag(find.byType(CustomScrollView), const Offset(0, -3000));
    await t.pumpAndSettle();
    final last = t.getRect(find.text('Musik'));
    final nav = t.getRect(find.byType(FloatingNavBar));
    expect(last.bottom, lessThan(nav.top));
  });
}

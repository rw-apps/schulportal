import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/l10n/l10n.dart';
import 'package:lanis/fork/meal_order_js.dart';
import 'package:lanis/fork/mensa.dart';
import 'package:lanis/fork/mensa_store.dart';
import 'package:lanis/fork/mensa_week.dart';
import 'package:lanis/fork/ui/mensa/meal_week_page.dart';
import 'package:lanis/fork/ui/today/kid_hints.dart';
import 'package:lanis/fork/ui/today/live_today_page.dart' show mealUnorderedDay;
import 'package:lanis/fork/ui/today/today_model.dart';

/// Essen beim Caterer lesen und zeigen (Kantine Schritt 2, 26.10.26) –
/// synthetische Seiten in test/fork/fixtures.
final de = forkL10nFor('de');

MealWeek load(String f) =>
    parseMealWeek(File('test/fork/fixtures/$f').readAsStringSync())!;

void main() {
  group('Tagesliste', () {
    final w = load('meal_daylist.html');
    test('Woche, Guthaben, Nachbarwochen', () {
      expect(w.label, '26.10. bis 30.10.2026');
      expect(w.balance, '12,50');
      expect(w.prev, isNull);
      expect(w.next, '/kunden/essen/2026/45/');
      expect([for (final d in w.days) d.day.day], [26, 27, 29, 30]);
    });
    test('bestellt, Beilagen, Frist aus der breiten Tabelle', () {
      final mo = w.days[0];
      expect(mo.state, MealState.ordered);
      expect(mo.ordered!.line, 'Veggie');
      expect(mo.ordered!.name, 'Linsencurry mit Reis');
      expect(mo.ordered!.allergens, 'G, Lak');
      expect(mo.sides.single.name, 'Apfel');
      expect(mo.options.length, 2);
      expect(mo.cancelUntil, isNull, reason: 'Abbestellung nicht mehr möglich');
      expect(w.days[2].cancelUntil, '29.10.26 08:30');
    });
    test('geschlossen und noch bestellbar', () {
      expect(w.days[1].state, MealState.closed);
      expect(w.days[1].note, 'Mensa geschlossen');
      expect(w.days[3].state, MealState.open);
      expect(w.days[3].note, 'Bestellbar bis: 30.10.26 08:30');
    });
  });

  group('Reiter je Tag', () {
    final w = load('meal_tabs.html');
    test('Woche und Links', () {
      expect(w.label, '26.10. bis 29.10.2026');
      expect(w.balance, '40,00');
      expect(w.next, endsWith('week=2026_45'));
      expect(w.prev, endsWith('week=2026_43'));
    });
    test('Zustände, Gericht ohne Dessert und Hinweis', () {
      expect(w.days[0].state, MealState.missed);
      expect(w.days[0].options.single.name, 'Gulasch mit Nudeln, grüner Salat');
      final di = w.days[1];
      expect(di.state, MealState.ordered);
      expect(di.ordered!.line, 'vegetarisch');
      expect(di.ordered!.name, 'Gnocchi auf Gemüse');
      expect(di.sides.single.name, 'Joghurt');
      expect(w.days[2].state, MealState.open);
      expect(w.days[2].options.single.name, 'Nudeln mit Soße');
      expect(w.days[3].state, MealState.closed);
    });
  });

  test('Kommas bereinigt', () {
    final w = parseMealWeek(
      File('test/fork/fixtures/meal_tabs.html').readAsStringSync().replaceFirst(
        'Hacksteak mit Reis',
        'Hacksteak mit Reis ,Soße',
      ),
    )!;
    expect(w.days[1].options.first.name, 'Hacksteak mit Reis, Soße');
  });

  test('Bestellbarkeit, Kennungen, Preise, Abbestellen', () {
    final a = load('meal_daylist.html');
    expect(a.kind, MealLayout.dayList);
    expect(a.days[0].options.first.id, '1-101');
    expect(a.days[0].canCancel, isFalse, reason: 'Minus gesperrt');
    expect(a.days[2].canCancel, isTrue);
    expect(a.days[3].options.single.orderable, isTrue);
    expect(a.days[0].options.any((o) => o.orderable), isFalse);
    final b = load('meal_tabs.html');
    expect(b.kind, MealLayout.tabs);
    expect(b.days[1].ordered!.id, '22');
    expect(b.days[1].canCancel, isTrue);
    expect(b.days[2].options.single.orderable, isTrue);
    expect(b.days[0].options.single.orderable, isFalse);
    final back = MealWeek.fromJson(
      b.withUrl('https://x.example/s.php').toJson(),
    )!;
    expect(back.kind, MealLayout.tabs);
    expect(back.url, 'https://x.example/s.php');
    expect(back.days[1].canCancel, isTrue);
    expect(back.days[2].options.single.id, '31');
    expect(back.days[2].options.single.orderable, isTrue);
  });

  test('Adresse der Woche zum Bestellen', () {
    final b = load('meal_tabs.html').withUrl('https://x.example/s.php');
    expect(
      mealWeekPageUrl(b, DateTime(2026, 11, 3), 'https://x.example/s.php'),
      'https://x.example/s.php?week=2026_45',
    );
    final a = load(
      'meal_daylist.html',
    ).withUrl('https://a.example/k/essen/2026/44/');
    expect(
      mealWeekPageUrl(a, DateTime(2026, 11, 3), 'https://a.example/k/'),
      'https://a.example/k/essen/2026/45/',
    );
  });

  test('Bestellskripte: Kennung, Woche, Rückfragen', () {
    final day = DateTime(2026, 10, 28);
    const o = MealOption(line: 'V', name: 'x', id: '1-201');
    final a = mealOrderJs(MealLayout.dayList, day, o);
    expect(a, contains('"1-201"'));
    expect(a, contains('"plus"'));
    expect(a, contains('if (used) return false'), reason: 'nur eine Rückfrage');
    final b = mealOrderJs(
      MealLayout.tabs,
      day,
      const MealOption(line: 'V', name: 'x', id: '31'),
    );
    expect(b, contains('"2026-10-28", "31", "2026_44"'));
    expect(mealCancelJs(MealLayout.tabs, day, null), contains('"2026_44"'));
    expect(mealModalJs, contains('data-fork-pre'));
    expect(mealModalJs, isNot(contains('.btn-primary')));
  });

  test('unbekannte Seite: null', () {
    expect(parseMealWeek('<html><body>Anmelden</body></html>'), isNull);
  });

  test('Wochenadresse für beide Muster', () {
    const w = (year: 2026, week: 45);
    expect(
      mensaUrlForWeek('https://a.example/kunden/essen/2026/44/', w),
      'https://a.example/kunden/essen/2026/45/',
    );
    expect(
      mensaUrlForWeek('https://b.example/s.php?week=2026_44&x=1', w),
      'https://b.example/s.php?week=2026_45&x=1',
    );
    expect(
      mensaUrlForWeek('https://c.example/s.php', w),
      'https://c.example/s.php',
    );
  });

  test('Speicher: JSON, Zusammenführen, höchstens drei Wochen', () {
    final c = MealCache.instance..reset();
    final a = load('meal_daylist.html');
    final again = MealWeek.fromJson(a.toJson())!;
    expect(again.days[0].ordered!.name, a.days[0].ordered!.name);
    expect(again.days[2].cancelUntil, '29.10.26 08:30');
    MealWeek shifted(int weeks) => MealWeek(
      label: 'x',
      days: [
        for (final d in a.days)
          MealDay(
            day: d.day.add(Duration(days: 7 * weeks)),
            state: d.state,
            ordered: d.ordered,
          ),
      ],
    );
    c.put('k', [a]);
    c.put('k', [shifted(1), shifted(2), shifted(3)]);
    final e = c.of('k')!;
    expect(e.weeks.length, 3);
    expect(e.weeks.first.start, shifted(1).start);
    expect(MealEntry.fromJson(e.toJson())!.weeks.length, 3);
    c.markUnreadable('k');
    expect(c.of('k')!.unreadable, isTrue);
    expect(c.of('k')!.weeks.length, 3, reason: 'alter Stand bleibt');
    c.reset();
  });

  test('Warnung nur, wenn überhaupt bestellt wird', () {
    final w = load('meal_daylist.html');
    final e = MealEntry(at: DateTime(2026, 10, 29), weeks: [w]);
    // Do 29.10. abends: Fr 30.10. ist offen.
    expect(
      mealUnorderedDay(e, DateTime(2026, 10, 29, 17), DateTime(2026, 10, 30)),
      DateTime(2026, 10, 30),
    );
    final never = MealEntry(
      at: DateTime(2026, 10, 29),
      weeks: [
        MealWeek(
          label: 'x',
          days: [MealDay(day: DateTime(2026, 10, 30), state: MealState.open)],
        ),
      ],
    );
    expect(
      mealUnorderedDay(never, DateTime(2026, 10, 29), DateTime(2026, 10, 30)),
      isNull,
    );
  });

  test('Guthaben unter 15 €: Hinweis, nur wenn bestellt wird', () {
    expect(parseEuro('1.234,50'), 1234.5);
    expect(parseEuro('18,00'), 18.0);
    expect(parseEuro('-3,00'), -3.0);
    final w = load('meal_daylist.html');
    final e = MealEntry(
      at: DateTime(2026, 10, 26),
      weeks: [w],
      balance: '12,50',
    );
    expect(lowMealBalance(e), '12,50');
    expect(
      lowMealBalance(
        MealEntry(at: DateTime(2026, 10, 26), weeks: [w], balance: '15,00'),
      ),
      isNull,
    );
    expect(
      lowMealBalance(MealEntry(at: DateTime(2026, 10, 26), balance: '2,00')),
      isNull,
      reason: 'ohne Bestellungen kein Hinweis',
    );
    final c = MealCache.instance..reset();
    c.put('k', [w]);
    expect(c.of('k')!.balance, '12,50');
    c.reset();
    final kid = ChildToday(
      firstName: 'Lena',
      school: 'S',
      className: '7X',
      colorIndex: 0,
      lowBalance: '12,50',
    );
    final h = kidHints(kid, DateTime(2026, 10, 26, 10), de).single;
    expect(h.kind, HintKind.balance);
    expect(h.title, 'Guthaben 12,50 €');
    expect(h.detail, 'unter 15 € – bitte Geld überweisen');
  });

  test('Hinweis „Kein Essen bestellt“ für morgen', () {
    final kid = ChildToday(
      firstName: 'Lena',
      school: 'S',
      className: '7X',
      colorIndex: 0,
      mealUnordered: DateTime(2026, 10, 30),
    );
    final h = kidHints(kid, DateTime(2026, 10, 29, 17), de);
    expect(h.single.kind, HintKind.meal);
    expect(h.single.title, 'Kein Essen bestellt');
    expect(h.single.when, 'Morgen');
  });

  testWidgets('Wochenansicht: alle Zustände', (t) async {
    final w = load('meal_daylist.html');
    var ordered = 0;
    var cancelled = 0;
    String? chosen;
    await t.pumpWidget(
      MaterialApp(
        localizationsDelegates: ForkL10n.localizationsDelegates,
        supportedLocales: ForkL10n.supportedLocales,
        locale: const Locale('de'),
        home: Scaffold(
          body: MealWeekView(
            week: w,
            now: DateTime(2026, 10, 26, 10),
            colorIndex: 0,
            onOrder: () => ordered++,
            onCancel: (_) => cancelled++,
            onOrderOption: (_, o) => chosen = o.name,
          ),
        ),
      ),
    );
    expect(t.takeException(), isNull);
    expect(find.text('Heute'), findsOneWidget);
    expect(find.text('Linsencurry mit Reis'), findsOneWidget);
    expect(find.text('Veggie · bestellt'), findsOneWidget);
    expect(find.text('Dazu: Apfel'), findsOneWidget);
    expect(find.text('Mensa geschlossen'), findsOneWidget);
    expect(
      find.text('Veggie · bestellt · abbestellbar bis 08:30'),
      findsOneWidget,
    );
    expect(find.text('Nichts bestellt'), findsOneWidget);
    // Offener Tag: zugeklappt nur die Zahl, aufgeklappt die Gerichte.
    expect(find.text('noch bestellbar'), findsOneWidget);
    expect(find.text('1 Gericht zur Wahl'), findsOneWidget);
    expect(find.text('Gemüsesuppe'), findsNothing);
    await t.tap(find.text('Nichts bestellt'));
    await t.pump();
    expect(find.text('Gemüsesuppe'), findsOneWidget);
    expect(find.text('VEGGIE'), findsOneWidget);
    expect(find.text('Guthaben 12,50 € · bitte überweisen'), findsOneWidget);
    await t.tap(find.text('Seite des Caterers'));
    expect(ordered, 1);
    // Abbestellen am Do (Frist läuft), Bestellen am Fr (aufgeklappt).
    expect(find.text('Abbestellen'), findsOneWidget);
    await t.tap(find.text('Abbestellen'));
    expect(cancelled, 1);
    await t.tap(find.text('Bestellen'));
    expect(chosen, 'Gemüsesuppe');
  });
}

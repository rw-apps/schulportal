import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/l10n/l10n.dart';
import 'package:lanis/fork/ui/plan/plan_page.dart';
import 'package:lanis/fork/ui/preview/demo_plan.dart';
import 'package:lanis/fork/ui/today/today_from_lanis.dart';
import 'package:lanis/fork/ui/today/today_model.dart';
import 'package:lanis/fork/ui/word_fit.dart';
import 'package:liblanis/liblanis.dart';

// Synthetisch: Kinder aus demoPlans (Lena, Jonas), erfundene Termine.
void main() {
  test('Feiertage: nur der ganze Titel zählt', () {
    for (final h in [
      'Reformationstag',
      'Allerheiligen!',
      '1. Advent',
      'Tag der Deutschen Einheit',
      '2. Weihnachtsfeiertag',
      ' Ostermontag ',
    ]) {
      expect(isPlainHoliday(h), isTrue, reason: h);
    }
    for (final x in [
      'Weihnachtskonzert',
      'Unterrichtsfrei (Fronleichnam)',
      'Herbstferien',
      'Adventsbasar',
      'Elternabend',
    ]) {
      expect(isPlainHoliday(x), isFalse, reason: x);
    }

    CalendarEvent ev(String title, DateTime d) => CalendarEvent(
      startTime: d,
      endTime: d.add(const Duration(hours: 23)),
      secret: false,
      id: title,
      isNew: false,
      public: true,
      private: false,
      allDay: true,
      description: '',
      title: title,
    );
    final now = DateTime(2026, 10, 18, 9);
    final events = [
      ev('Reformationstag', DateTime(2026, 10, 31)),
      ev('Projekttag', DateTime(2026, 10, 30)),
    ];
    expect(weekItemsFromCalendar(events, now).length, 2);
    expect(
      [
        for (final w in weekItemsFromCalendar(events, now, skipHolidays: true))
          w.title,
      ],
      ['Projekttag'],
    );
  });

  testWidgets('Langes Wort: Schrift wird kleiner statt zu trennen', (t) async {
    const style = TextStyle(fontSize: 20);
    expect(WordFitText.scaleFor('Kurz', style, 200, TextScaler.noScaling), 1);
    final f = WordFitText.scaleFor(
      'Reformationstagungsunterlagen',
      style,
      120,
      TextScaler.noScaling,
    );
    expect(f, lessThan(1));
    expect(f, greaterThanOrEqualTo(0.7));
  });

  testWidgets('Termine: Filter je Kind, Name am Termin, Ansicht von außen', (
    t,
  ) async {
    t.view.physicalSize = const Size(1080, 2424);
    t.view.devicePixelRatio = 2.625;
    addTearDown(t.view.reset);
    final plans = demoPlans();
    final request = ValueNotifier<PlanView?>(null);
    addTearDown(request.dispose);
    final now = DateTime(2026, 10, 18, 9);
    final events = [
      WeekItem(
        day: DateTime(2026, 10, 20),
        title: 'Elternabend 5b',
        kind: WeekKind.event,
        childIndex: 0,
      ),
      WeekItem(
        day: DateTime(2026, 10, 21),
        title: 'Wandertag 8c',
        kind: WeekKind.event,
        childIndex: 1,
        time: '08:00',
      ),
    ];
    await t.pumpWidget(
      MaterialApp(
        localizationsDelegates: ForkL10n.localizationsDelegates,
        supportedLocales: ForkL10n.supportedLocales,
        locale: const Locale('de'),
        home: Scaffold(
          body: PlanPage(
            plans: plans,
            now: now,
            events: events,
            viewRequest: request,
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Elternabend 5b'), findsNothing); // Ansicht „Tag“

    // Heute → „Alle Termine“.
    request.value = PlanView.events;
    await t.pumpAndSettle();
    expect(request.value, isNull);
    expect(find.text('Elternabend 5b'), findsOneWidget);
    expect(find.text('Wandertag 8c'), findsOneWidget);
    expect(find.text('Alle'), findsOneWidget);
    // Kindname unter jedem Termin (plus je eine Pille oben).
    expect(find.text('Lena'), findsNWidgets(2));
    expect(find.text('Jonas'), findsNWidgets(2));
    expect(find.text('ganztags'), findsOneWidget);
    expect(t.takeException(), isNull);

    // Nur Jonas: Lenas Termin weg, Namen am Termin entfallen.
    await t.tap(find.text('Jonas').first);
    await t.pumpAndSettle();
    expect(find.text('Elternabend 5b'), findsNothing);
    expect(find.text('Wandertag 8c'), findsOneWidget);
    expect(find.text('Jonas'), findsOneWidget);

    // Erneut „Alle Termine“: wieder alle Kinder.
    await t.tap(find.text('Tag'));
    await t.pumpAndSettle();
    request.value = PlanView.events;
    await t.pumpAndSettle();
    expect(find.text('Elternabend 5b'), findsOneWidget);
  });
}

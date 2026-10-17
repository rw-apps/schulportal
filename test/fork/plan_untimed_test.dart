import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/l10n/l10n.dart';
import 'package:lanis/fork/ui/plan/plan_from_lanis.dart';
import 'package:lanis/fork/ui/plan/plan_page.dart';
import 'package:lanis/fork/ui/today/today_from_lanis.dart';
import 'package:lanis/fork/ui/today/today_model.dart';
import 'package:lanis/fork/ui/today/today_page.dart';
import 'package:liblanis/liblanis.dart';

final _zero = SphTimeOfDay(hour: 0, minute: 0);

TimetableSubject _s(String name, int stunde, int duration) => TimetableSubject(
  id: '$name$stunde',
  name: name,
  raum: 'R1',
  lehrer: 'Ab',
  badge: null,
  duration: duration,
  startTime: _zero,
  endTime: _zero,
  stunde: stunde,
);

/// Form wie Schule B (Export 17.10.26): keine Uhrzeiten, Einträge nur mit
/// Stundennummer und Dauer; erfundene Fächer.
TimeTable _tt() => TimeTable(
  hours: const [],
  planForAll: const [],
  planForOwn: [
    [_s('G', 1, 2), _s('POWI', 3, 2), _s('GEO', 5, 1)],
    [_s('MU', 1, 2), _s('D', 3, 2)],
    [_s('M', 3, 2), _s('E', 8, 1)],
    [_s('F', 1, 2)],
    [_s('CH', 3, 2)],
  ],
);

void main() {
  test('Plan ohne Uhrzeiten aus Stundennummern', () {
    final p = kidPlanFromTimetable(_tt(), firstName: 'B', colorIndex: 1);
    expect(p.timed, isFalse);
    expect(p.slots.map((s) => s.label).first, '1. Stunde');
    expect(p.slots, hasLength(8)); // 1.–8. Stunde, Lücken bleiben
    expect(p.days[0].where((c) => !c.isEmpty), hasLength(5));
    expect(p.days[2][7].options.single.short, 'E');
  });

  test('Heute ohne Uhrzeiten: erste Stunde, keine Zeiten, kein Absturz', () {
    final p = kidPlanFromTimetable(_tt(), firstName: 'B', colorIndex: 1);
    final t = forkL10nFor('de');
    final l = dayLessonsFor(p, 0, const {}, t: t);
    expect(l.first.start, '');
    final st = dayStatus(l, DateTime(2026, 10, 19, 10));
    expect(st.phase, DayPhase.untimed);
    expect(st.next, 0);
    expect(lessonDone(l.first, DateTime(2026, 10, 19, 23)), isFalse);
    expect(gapBefore(l, 1), 0);
  });

  testWidgets('Kalender ohne Uhrzeiten ohne Überlauf', (t) async {
    final p = kidPlanFromTimetable(_tt(), firstName: 'B', colorIndex: 1);
    await t.pumpWidget(
      MaterialApp(
        localizationsDelegates: ForkL10n.localizationsDelegates,
        supportedLocales: ForkL10n.supportedLocales,
        locale: const Locale('de'),
        home: Scaffold(
          body: PlanPage(plans: [p], now: DateTime(2026, 10, 19, 10)),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.textContaining('keine Uhrzeiten'), findsOneWidget);
    await t.tap(find.text('Woche'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });

  testWidgets('Heute ohne Uhrzeiten zeigt die erste Stunde', (t) async {
    final p = kidPlanFromTimetable(_tt(), firstName: 'Bea', colorIndex: 1);
    final now = DateTime(2026, 10, 19, 10);
    final kid = childTodayFromLanis(
      plan: p,
      choice: const {},
      substitutions: const [],
      now: now,
      school: 'Schule B',
      t: forkL10nFor('de'),
    );
    await t.pumpWidget(
      MaterialApp(
        localizationsDelegates: ForkL10n.localizationsDelegates,
        supportedLocales: ForkL10n.supportedLocales,
        locale: const Locale('de'),
        home: TodayPage(
          data: FamilyToday(now: now, kids: [kid], week: const []),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.textContaining('AB 1.'), findsOneWidget);
    expect(find.text('Geschichte'), findsWidgets);
  });
}

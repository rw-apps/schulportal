import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/l10n/l10n.dart';
import 'package:lanis/fork/ui/plan/lesson_times.dart';
import 'package:lanis/fork/ui/plan/lesson_times_dialog.dart';
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
    expect(find.textContaining('Geschichte'), findsWidgets);
  });

  test('Stundenzeiten: Raster und gespeicherte Form', () {
    const v = LessonTimes(start: 8 * 60);
    expect(v.of(1), (start: 480, end: 525));
    expect(v.of(2), (start: 525, end: 570));
    expect(v.of(3), (start: 585, end: 630)); // nach 2 Stunden 15 Min. Pause
    expect(v.of(5).start, 690); // 11:30
    expect(v.of(0), (start: 435, end: 480));
    expect(LessonTimes.fromMap(v.toMap())?.of(3), v.of(3));
    expect(LessonTimes.fromMap(const {}), isNull);

    // Unregelmäßige Pausen (synthetisch, Muster wie Rückmeldung 17.10.26).
    var w = const LessonTimes(start: 8 * 60, pauses: {});
    for (final (n, m) in [(2, 20), (4, 20), (5, 5), (6, 10), (8, 5)]) {
      w = w.withPause(n, m);
    }
    String at(int n) =>
        '${LessonTimes.hm(w.of(n).start)}-${LessonTimes.hm(w.of(n).end)}';
    expect(at(3), '09:50-10:35');
    expect(at(5), '11:40-12:25');
    expect(at(6), '12:30-13:15');
    expect(at(7), '13:25-14:10');
    expect(at(9), '15:00-15:45');
    expect(at(10), '15:45-16:30');
    expect(w.toMap()['pauses'], '2:20,4:20,5:5,6:10,8:5');
    expect(LessonTimes.fromMap(w.toMap())?.of(10), w.of(10));
    expect(w.withPause(2, 0).of(3).start, 9 * 60 + 30);
    expect(
      LessonTimes.fromMap(const {
        'start': '08:00',
        'length': '45',
        'pauses': '2:x',
      }),
      isNull,
    );
    // Form bis 9351: Pause nach je n Stunden wird umgerechnet.
    final old = LessonTimes.fromMap(const {
      'start': '08:00',
      'length': '45',
      'every': '2',
      'pause': '15',
    });
    expect(old?.of(3), v.of(3));
    expect(old?.of(7), v.of(7));
    expect(
      LessonTimes.fromMap(const {
        'start': '25:00',
        'length': '45',
        'every': '2',
        'pause': '15',
      }),
      isNull,
    );

    final p = kidPlanFromTimetable(
      _tt(),
      firstName: 'B',
      colorIndex: 1,
      lessonTimes: v,
    );
    expect(p.timed, isTrue);
    expect(p.customTimes, isTrue);
    expect(p.slots.first.start, '08:00');
    expect(p.slots[2].start, '09:45');
    final l = dayLessonsFor(p, 0, const {}, t: forkL10nFor('de'));
    expect(l.first.start, '08:00');
    expect(dayStatus(l, DateTime(2026, 10, 19, 8, 10)).phase, DayPhase.running);
  });

  testWidgets('Knopf „Stundenzeiten eintragen“ und Dialog', (t) async {
    final p = kidPlanFromTimetable(_tt(), firstName: 'B', colorIndex: 1);
    LessonTimesResult? got;
    await t.pumpWidget(
      MaterialApp(
        localizationsDelegates: ForkL10n.localizationsDelegates,
        supportedLocales: ForkL10n.supportedLocales,
        locale: const Locale('de'),
        home: Builder(
          builder: (c) => Scaffold(
            body: PlanPage(
              plans: [p],
              now: DateTime(2026, 10, 19, 10),
              onEditTimes: (_) async => got = await askLessonTimes(c, null),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Stundenzeiten eintragen'));
    await t.pumpAndSettle();
    expect(find.text('3.  09:45–10:30'), findsOneWidget);
    expect(find.text('10.  15:45–16:30'), findsOneWidget);
    // Pause nach der 2. Stunde auf 20 Min.: die 3. rückt nach.
    await t.tap(find.text('15 Min.').first);
    await t.pumpAndSettle();
    await t.tap(find.text('20 Min.').last);
    await t.pumpAndSettle();
    expect(find.text('3.  09:50–10:35'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.tap(find.text('Speichern'));
    await t.pumpAndSettle();
    expect(got?.times?.of(1).start, 480);
    expect(got?.times?.pauseAfter(2), 20);
  });
}

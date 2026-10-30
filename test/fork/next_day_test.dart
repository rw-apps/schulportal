import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/l10n/l10n.dart';
import 'package:lanis/fork/ui/plan/plan_model.dart';
import 'package:lanis/fork/ui/plan/plan_page.dart';
import 'package:lanis/fork/ui/today/kid_hints.dart';
import 'package:lanis/fork/ui/today/today_model.dart';
import 'package:lanis/fork/ui/today/today_page.dart';

/// Nach Schulschluss der nächste Schultag auf der Kinderkarte, Arbeiten als
/// Hinweis (Abnahme 26.10.26) – synthetisch.
final de = forkL10nFor('de');

/// Hinweiszeile „Fach  Art“ (_HintLine, ein Text.rich).
Finder _hint(String s) => find.text(s, findRichText: true);

const today = [
  DayLesson(slot: '1.', subject: 'Deutsch', start: '08:00', end: '08:45'),
  DayLesson(slot: '2.', subject: 'Englisch', start: '08:50', end: '13:20'),
];
const tomorrow = [
  DayLesson(slot: '1.', subject: 'Mathematik', start: '08:00', end: '08:45'),
  DayLesson(slot: '2.', subject: 'Biologie', start: '08:50', end: '09:35'),
];
final mon = DateTime(2026, 10, 26);
final tue = DateTime(2026, 10, 27);

ChildToday kid(List<DayLesson> l, {List<ChangeItem> changes = const []}) =>
    ChildToday(
      firstName: 'Lena',
      school: 'Beispielschule',
      className: '7X',
      colorIndex: 0,
      lessons: l,
      changes: changes,
    );

final exam = WeekItem(
  day: tue,
  title: 'Mathematik: Klassenarbeit',
  kind: WeekKind.exam,
  childIndex: 0,
  time: '1.–2. Stunde',
);
final party = WeekItem(
  day: DateTime(2026, 10, 29),
  title: 'Elternabend',
  kind: WeekKind.event,
  childIndex: 0,
);

FamilyToday family(DateTime now) => FamilyToday(
  now: now,
  kids: [
    kid(
      today,
      changes: [
        ChangeItem(
          day: tue,
          slot: '3.–4.',
          subject: 'Deutsch',
          kind: ChangeKind.substitution,
        ),
      ],
    ),
  ],
  week: [exam, party],
  next: [kid(tomorrow)],
  nextDate: tue,
);

void main() {
  group('Arbeiten als Hinweis', () {
    test('morgen: Hinweis mit „Morgen“, übermorgen nicht', () {
      final now = DateTime(2026, 10, 26, 10);
      final h = kidHints(kid(today), now, de, exams: [exam]);
      expect(h.single.kind, HintKind.exam);
      expect(h.single.when, 'Morgen');
      expect(h.single.detail, contains('Stunde'));
      final later = kidHints(
        kid(today),
        now,
        de,
        exams: [
          WeekItem(
            day: DateTime(2026, 10, 28),
            title: 'X',
            kind: WeekKind.exam,
          ),
        ],
      );
      expect(later, isEmpty);
    });
    test('Demnächst ohne die Arbeit, solange sie Hinweis ist', () {
      final now = DateTime(2026, 10, 26, 10);
      expect(upcomingWithoutHints([exam, party], now, 1), [party]);
      // Zwei Tage vorher: noch kein Hinweis, also unter Demnächst.
      expect(upcomingWithoutHints([exam, party], DateTime(2026, 10, 25), 1), [
        exam,
        party,
      ]);
      // Ohne Kindzuordnung bei zwei Kindern zeigt keine Karte sie.
      final loose = WeekItem(day: tue, title: 'Y', kind: WeekKind.exam);
      expect(upcomingWithoutHints([loose], now, 2), [loose]);
      expect(examsFor([loose], 0, 2), isEmpty);
      expect(examsFor([loose], 0, 1), [loose]);
    });
  });

  Widget app(
    FamilyToday data, {
    void Function(DateTime)? opened,
    VoidCallback? exams,
  }) => MaterialApp(
    localizationsDelegates: ForkL10n.localizationsDelegates,
    supportedLocales: ForkL10n.supportedLocales,
    locale: const Locale('de'),
    home: Scaffold(
      body: TodayPage(
        data: data,
        onOpenDay: (_, day) => opened?.call(day),
        onOpenExams: exams == null ? null : (_) => exams(),
      ),
    ),
  );

  testWidgets('nach Schulschluss: Heute vorbei, darunter Morgen', (t) async {
    final opened = <DateTime>[];
    await t.pumpWidget(
      app(family(DateTime(2026, 10, 26, 17)), opened: opened.add),
    );
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('HEUTE'), findsOneWidget);
    expect(find.text('Unterricht vorbei seit 13:20'), findsOneWidget);
    expect(find.text('MORGEN'), findsOneWidget);
    expect(find.text('Dienstag, 27. Oktober'), findsOneWidget);
    expect(
      // Nicht die Hinweiszeile „Mathematik  Klassenarbeit“.
      find.textContaining(
        RegExp(r'^Mathematik(?!:|  Klassenarbeit)'),
        findRichText: true,
      ),
      findsOneWidget,
      reason: 'erste Stunde',
    );
    // Hinweise als EINE Gruppe mit dem Tag aus dem Kopf (kein zweites
    // „HEUTE“), ohne „Morgen ·“; die Arbeit nicht unter Demnächst.
    expect(find.textContaining('Morgen · '), findsNothing);
    expect(find.text('DIENSTAG, 27. OKT.'), findsOneWidget);
    expect(_hint('Mathematik  Klassenarbeit'), findsOneWidget);
    expect(_hint('Deutsch  Vertretung'), findsOneWidget);
    // Marke: nur die Stunde als Zahl, „STUNDE“ im Kopf statt der Anzahl
    // (Rückmeldung 30.10.26: „3.“ las sich wie eine Note).
    expect(find.text('1.–2.'), findsOneWidget);
    expect(find.text('STUNDE'), findsOneWidget);
    expect(find.text('2'), findsNothing);
    await t.tap(find.text('Ganzer Tag'));
    expect(opened, [tue]);
    // Antippen einer Zeile öffnet ihren Tag wie „Ganzer Tag“.
    await t.tap(_hint('Deutsch  Vertretung'));
    expect(opened, [tue, tue]);
  });

  // Rückmeldung 30.10.26: Arbeits-Hinweis führt zu „Arbeiten & Noten“.
  testWidgets('Arbeit antippen öffnet Arbeiten & Noten', (t) async {
    final opened = <DateTime>[];
    var exams = 0;
    await t.pumpWidget(
      app(
        family(DateTime(2026, 10, 26, 17)),
        opened: opened.add,
        exams: () => exams++,
      ),
    );
    await t.pumpAndSettle();
    await t.tap(_hint('Mathematik  Klassenarbeit'));
    expect(exams, 1);
    expect(opened, isEmpty);
  });

  testWidgets('während des Unterrichts: unverändert heute', (t) async {
    final opened = <DateTime>[];
    final now = DateTime(2026, 10, 26, 10);
    await t.pumpWidget(app(family(now), opened: opened.add));
    await t.pumpAndSettle();
    expect(find.text('MORGEN'), findsNothing);
    // Hinweise für morgen unter dem Tageskopf statt „Morgen ·“.
    expect(find.text('DIENSTAG, 27. OKT.'), findsOneWidget);
    expect(find.text('HEUTE'), findsNothing);
    await t.tap(find.text('Ganzer Tag'));
    expect(opened, [now]);
  });

  testWidgets('Freitag: nächster Schultag Montag', (t) async {
    final fri = DateTime(2026, 10, 30, 17);
    final monNext = DateTime(2026, 11, 2);
    await t.pumpWidget(
      app(
        FamilyToday(
          now: fri,
          kids: [kid(today)],
          week: const [],
          next: [kid(tomorrow)],
          nextDate: monNext,
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('NÄCHSTER SCHULTAG'), findsOneWidget);
    expect(find.text('Montag, 2. November'), findsOneWidget);
  });

  testWidgets('ohne Unterricht am nächsten Tag: bleibt bei vorbei', (t) async {
    await t.pumpWidget(
      app(
        FamilyToday(
          now: DateTime(2026, 10, 26, 17),
          kids: [kid(today)],
          week: const [],
          next: [kid(const [])],
          nextDate: tue,
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('MORGEN'), findsNothing);
    expect(
      find.textContaining('Unterricht vorbei', findRichText: true),
      findsWidgets,
    );
  });

  testWidgets('Kalender öffnet den verlangten Tag', (t) async {
    final view = ValueNotifier<PlanView?>(PlanView.day);
    final day = ValueNotifier<DateTime?>(DateTime(2026, 11, 3));
    final plan = KidPlan(
      firstName: 'Lena',
      colorIndex: 0,
      slots: const [PlanSlot(label: '1.', start: '08:00', end: '08:45')],
      days: [
        for (final s in ['Mo', 'Di', 'Mi', 'Do', 'Fr'])
          [
            PlanCell([PlanLesson(subject: 'Fach $s', short: s, room: '')]),
          ],
      ],
    );
    await t.pumpWidget(
      MaterialApp(
        localizationsDelegates: ForkL10n.localizationsDelegates,
        supportedLocales: ForkL10n.supportedLocales,
        locale: const Locale('de'),
        home: Scaffold(
          body: PlanPage(
            plans: [plan],
            now: DateTime(2026, 10, 30, 17),
            viewRequest: view,
            dayRequest: day,
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('Fach Di'), findsWidgets);
    expect(day.value, isNull);
  });
}

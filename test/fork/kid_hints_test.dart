import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/l10n/l10n.dart';
import 'package:lanis/fork/ui/preview/demo_family.dart';
import 'package:lanis/fork/ui/today/kid_hints.dart';
import 'package:lanis/fork/ui/today/today_model.dart';

/// Hinweise an der Kinderkarte (kid_hints.dart) – synthetisch.
final de = forkL10nFor('de');

ChildToday kid(
  List<DayLesson> lessons, {
  List<ChangeItem> changes = const [],
  String? meal,
}) => ChildToday(
  firstName: 'Lena',
  school: 'Beispielschule',
  className: '9X',
  colorIndex: 0,
  lessons: lessons,
  changes: changes,
  mealHint: meal,
);

DayLesson lesson(
  String slot,
  String subject,
  String start,
  String end, [
  ChangeKind? change,
  String? detail,
]) => DayLesson(
  slot: slot,
  subject: subject,
  start: start,
  end: end,
  change: change,
  changeDetail: detail,
);

/// Ohne geschützte Leerzeichen, damit die Erwartungen lesbar bleiben.
String? plain(String? s) => s?.replaceAll('\u00A0', ' ');

void main() {
  final morning = DateTime(2026, 10, 21, 7, 22);
  final day = [
    lesson('1.–2. Stunde', 'Ev. Religion', '08:00', '09:30'),
    lesson('3.–4. Stunde', 'Chemie', '09:45', '11:15'),
    lesson('5.–6. Stunde', 'Französisch', '11:30', '13:00'),
  ];
  List<DayLesson> cancel(int i) => [
    for (final (j, x) in day.indexed)
      j == i
          ? lesson(x.slot, x.subject, x.start, x.end, ChangeKind.cancelled)
          : x,
  ];

  test('Ausfall am Anfang nennt den späteren Beginn', () {
    final h = kidHints(kid(cancel(0)), morning, de);
    expect(h.single.title, 'Ev. Religion fällt aus');
    expect(h.single.cancelled, isTrue);
    expect(plain(h.single.detail), '1.–2. Stunde · Beginn erst 09:45');
  });

  test(
    'Ausfall am Ende nennt den früheren Schluss, mitten am Tag die Zeit',
    () {
      expect(
        plain(kidHints(kid(cancel(2)), morning, de).single.detail),
        '5.–6. Stunde · Schluss schon 11:15',
      );
      expect(
        plain(kidHints(kid(cancel(1)), morning, de).single.detail),
        '3.–4. Stunde · 09:45–11:15',
      );
    },
  );

  test('Vertretung mit Lehrkraft; vorbei = kein Hinweis mehr', () {
    final lessons = [
      day[0],
      lesson(
        '3.–4. Stunde',
        'Chemie',
        '09:45',
        '11:15',
        ChangeKind.substitution,
        'Tim Sommer',
      ),
      day[2],
    ];
    final h = kidHints(kid(lessons), morning, de).single;
    expect(h.title, 'Chemie: Vertretung');
    expect(plain(h.detail), '3.–4. Stunde · 09:45–11:15 · Tim Sommer');
    expect(kidHints(kid(lessons), DateTime(2026, 10, 21, 11, 20), de), isEmpty);
  });

  test('Reihenfolge: heute, Essen, nächster Schultag mit „Morgen“', () {
    // Beispieldaten: heutige Vertretung steht auch in changes (ohne
    // Doppelung), Sport fällt morgen aus.
    final f = demoFamily();
    final lena = f.kids.first;
    final h = kidHints(
      ChildToday(
        firstName: lena.firstName,
        school: lena.school,
        className: lena.className,
        colorIndex: 0,
        lessons: lena.lessons,
        changes: lena.changes,
        mealHint: 'Heute: kein Essen',
      ),
      f.now,
      de,
    );
    expect(h.map((x) => x.title), [
      'Deutsch: Vertretung',
      'Heute: kein Essen',
      'Sport fällt aus',
    ]);
    expect(h.last.when, 'Morgen');
    expect(h.first.when, isNull);
  });

  test('Freitag: Hinweise für Montag, nicht für später', () {
    final friday = DateTime(2026, 10, 23, 15, 0);
    expect(nextSchoolDay(friday), DateTime(2026, 10, 26));
    final h = kidHints(
      kid(
        const [],
        changes: [
          ChangeItem(
            day: DateTime(2026, 10, 26),
            slot: '1. Stunde',
            subject: 'Mathematik',
            kind: ChangeKind.roomChange,
            detail: 'R101 statt R106',
          ),
          ChangeItem(
            day: DateTime(2026, 10, 27),
            slot: '2. Stunde',
            subject: 'Kunst',
            kind: ChangeKind.cancelled,
          ),
        ],
      ),
      friday,
      de,
    );
    expect(h.single.title, 'Mathematik: Raumwechsel');
    expect(h.single.when, 'Mo 26.10.');
    expect(plain(h.single.detail), '1. Stunde · R101 statt R106');
  });

  group('Zeile und Gruppen (Abnahme 30.10.26)', () {
    test('Felder der Zeile: Fach, Art, Stunde als Zahl, Tag', () {
      final h = kidHints(
        kid(
          [
            lesson('1.–2. Stunde', 'Deutsch', '08:00', '09:30'),
            DayLesson(
              slot: '3.–4. Stunde',
              subject: 'Biologie',
              start: '09:45',
              end: '11:15',
              room: 'R020',
              change: ChangeKind.roomChange,
              changeDetail: 'R020 statt R106',
            ),
            lesson(
              '5.–6. Stunde',
              'Mathematik',
              '11:30',
              '13:00',
              ChangeKind.cancelled,
            ),
          ],
          changes: [
            ChangeItem(
              day: DateTime(2026, 10, 22),
              slot: '6.',
              subject: 'Kunst',
              kind: ChangeKind.substitution,
              detail: 'Tom Beispiel',
            ),
          ],
        ),
        morning,
        de,
      );
      expect(
        [for (final x in h) (x.subject, x.what, x.slot)],
        [
          ('Biologie', 'Raum R020', '3.–4.'),
          ('Mathematik', 'fällt aus', '5.–6.'),
          ('Kunst', 'Vertretung', '6.'),
        ],
      );
      expect(h[0].day, DateTime(2026, 10, 21));
      expect(h[2].day, DateTime(2026, 10, 22));
      // Folge und Lehrkraft bleiben im Detail (Bildschirmleser).
      expect(plain(h[1].detail), '5.–6. Stunde · Schluss schon 11:15');
      expect(plain(h[2].detail), '6. · Tom Beispiel');
    });

    test('Arbeit: Fach und Art geteilt, Uhrzeit bzw. Stunden als Marke', () {
      expect(examParts(de, 'Englisch: Test'), ('Englisch', 'Test'));
      expect(examParts(de, 'Klassenarbeit Englisch'), (
        'Englisch',
        'Klassenarbeit',
      ));
      expect(examParts(de, 'Physik'), ('Physik', 'Arbeit'));
      expect(examSlot('09:50'), '09:50');
      expect(examSlot('9:50 Uhr'), '09:50');
      expect(examSlot('3., 4. Std. (90 Min.)'), '3.–4.');
      expect(examSlot('5. Stunde'), '5.');
      expect(examSlot('nach Absprache'), isNull);
      expect(examSlot(null), isNull);
      final h = kidHints(
        kid(const []),
        morning,
        de,
        exams: [
          WeekItem(
            day: DateTime(2026, 10, 21),
            title: 'Englisch: Test',
            kind: WeekKind.exam,
            time: '09:50',
          ),
        ],
      ).single;
      expect((h.subject, h.what, h.slot), ('Englisch', 'Test', '09:50'));
      expect(h.day, DateTime(2026, 10, 21));
    });

    test('Essenshinweis: Text ohne „Heute:“, ab 14 Uhr für morgen', () {
      final h = kidHints(kid(const [], meal: 'Heute: kein Essen'), morning, de);
      expect((h.single.subject, h.single.what), ('Essen', 'kein Essen'));
      expect(h.single.day, DateTime(2026, 10, 21));
      final late = kidHints(
        kid(const [], meal: 'Morgen: kein Essen'),
        DateTime(2026, 10, 21, 15),
        de,
      ).single;
      expect(late.what, 'kein Essen');
      expect(late.day, DateTime(2026, 10, 22));
    });

    test('Gruppen: Tage aufsteigend, Guthaben beim gezeigten Tag', () {
      KidHint h(String s, DateTime? day) => KidHint(
        kind: HintKind.substitution,
        title: s,
        subject: s,
        what: '',
        day: day,
      );
      final mon = DateTime(2026, 11, 2);
      final fri = DateTime(2026, 10, 30);
      final hints = [
        h('A', mon),
        h('B', fri),
        h('Guthaben', null),
        h('C', mon),
        h('D', fri),
      ];
      final g = groupHints(hints, DateTime(2026, 10, 30, 9));
      expect([for (final x in g) x.day], [fri, mon]);
      expect([for (final x in g[0].hints) x.title], ['B', 'Guthaben', 'D']);
      expect([for (final x in g[1].hints) x.title], ['A', 'C']);
      // Nach Schulschluss zeigt die Karte Montag: Guthaben dort, eine Gruppe.
      final after = groupHints([h('A', mon), h('Guthaben', null)], mon);
      expect(after, hasLength(1));
      expect(after.single.hints, hasLength(2));
      final now = DateTime(2026, 10, 30, 9);
      expect(hintDayCaption(de, fri, now), 'HEUTE');
      expect(hintDayCaption(de, mon, now), 'MONTAG, 2. NOV.');
      expect(hintDayCaption(forkL10nFor('en'), mon, now), 'MONDAY, NOV 2');
    });
  });
}

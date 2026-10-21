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
}

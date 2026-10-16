import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/notify/notices.dart';
import 'package:lanis/fork/ui/plan/plan_model.dart';
import 'package:lanis/fork/ui/today/today_model.dart';
import 'package:liblanis/liblanis.dart';

/// Erfundener Plan: Mo und Di je 1.–2. Block Mathe/Deutsch.
KidPlan _plan() {
  const slots = [
    PlanSlot(label: '1. Block', start: '09:00', end: '10:15'),
    PlanSlot(label: '2. Block', start: '10:30', end: '11:45'),
  ];
  const m = PlanLesson(
    subject: 'Mathematik',
    short: 'M',
    room: 'R1',
    teacher: 'AAA',
  );
  const d = PlanLesson(
    subject: 'Deutsch',
    short: 'D',
    room: 'R1',
    teacher: 'BBB',
  );
  PlanCell c(PlanLesson l) => PlanCell([l]);
  return KidPlan(
    firstName: 'Kind',
    colorIndex: 0,
    slots: slots,
    days: [
      [c(m), c(d)],
      [c(m), c(d)],
      [c(m), c(d)],
      [c(m), c(d)],
      [c(m), c(d)],
    ],
  );
}

SubstitutionDay _day(String date, List<(String, String)> rows) =>
    SubstitutionDay(
      parsedDate: date,
      substitutions: [
        for (final (stunde, art) in rows)
          Substitution(tag: date, tag_en: '', stunde: stunde, art: art),
      ],
    );

CalendarEvent _ev(String title, DateTime a, {String? cat}) => CalendarEvent(
  startTime: a,
  endTime: a.add(const Duration(hours: 1)),
  secret: false,
  id: title,
  isNew: false,
  public: true,
  private: false,
  allDay: false,
  category: cat == null
      ? null
      : CalendarEventCategory(id: 1, colorArgb: 0, name: cat),
  description: '',
  title: title,
);

void main() {
  final plan = _plan();
  // Montag 19.10.26
  final subs = [
    _day('19.10.2026', [('1', 'Entfall'), ('2', 'Raumänderung')]),
    _day('20.10.2026', [('1', 'Entfall')]),
  ];

  List<Notice> at(
    DateTime now, {
    Set<String> sent = const {},
    List<CalendarEvent> ev = const [],
  }) => buildNotices(
    plan: plan,
    choice: const {},
    substitutions: subs,
    events: ev,
    now: now,
    sent: sent,
  );

  test('Ruhezeit 21–6 Uhr', () {
    expect(at(DateTime(2026, 10, 19, 5, 59)), isEmpty);
    expect(at(DateTime(2026, 10, 19, 21)), isEmpty);
  });

  test(
    'heute: nur kommende Stunden, nicht doppelt, Neues ersetzt vollständig',
    () {
      final morning = at(DateTime(2026, 10, 19, 8));
      expect(morning.single.id, 1);
      expect(morning.single.title, 'Heute bei Kind');
      expect(morning.single.lines, hasLength(2));
      final after1 = at(DateTime(2026, 10, 19, 10, 20));
      expect(
        after1.single.lines.single,
        startsWith('2. Block Deutsch – Raumwechsel'),
      );
      expect(
        at(DateTime(2026, 10, 19, 8), sent: morning.single.keys.toSet()),
        isEmpty,
      );
      expect(
        at(
          DateTime(2026, 10, 19, 8),
          sent: {morning.single.keys.first},
        ).single.lines,
        hasLength(2),
        reason: 'eine neue → vollständige Meldung',
      );
    },
  );

  test('Vorabend ab 19 Uhr für den nächsten Schultag, mit großen Terminen', () {
    expect(at(DateTime(2026, 10, 19, 18, 59)).where((n) => n.id == 2), isEmpty);
    final ev = [
      _ev('Lernkontrolle NaWi', DateTime(2026, 10, 20, 9), cat: 'Arbeiten'),
      _ev('Elternabend 6', DateTime(2026, 10, 20, 19)),
      _ev('Präsentation Prüfung', DateTime(2026, 10, 20, 8)),
    ];
    final n = at(
      DateTime(2026, 10, 19, 19, 30),
      ev: ev,
    ).firstWhere((n) => n.id == 2);
    expect(n.title, 'Morgen bei Kind');
    expect(n.lines, [
      '1. Block Mathematik – fällt aus',
      'Lernkontrolle NaWi · 09:00',
      'Elternabend 6 · 19:00',
    ]);
  });

  test('Freitagabend nichts für Samstag, Sonntagabend für Montag', () {
    final fri = buildNotices(
      plan: plan,
      choice: const {},
      substitutions: [
        _day('24.10.2026', [('1', 'Entfall')]),
      ],
      events: const [],
      now: DateTime(2026, 10, 23, 19, 30),
    );
    expect(fri, isEmpty);
    final sun = buildNotices(
      plan: plan,
      choice: const {},
      substitutions: [
        _day('26.10.2026', [('1', 'Entfall')]),
      ],
      events: const [],
      now: DateTime(2026, 10, 25, 19, 30),
    );
    expect(sun.single.title, 'Morgen bei Kind');
  });

  test('große Termine', () {
    WeekItem w(String t, WeekKind k) =>
        WeekItem(day: DateTime(2026), title: t, kind: k);
    expect(isBigEvent(w('Sportfest', WeekKind.event)), isTrue);
    expect(isBigEvent(w('Projektpr. Präsentation', WeekKind.event)), isFalse);
    expect(isBigEvent(w('Kein Essen', WeekKind.meal)), isFalse);
    expect(isBigEvent(w('Herbstferien', WeekKind.free)), isTrue);
  });

  test('Schlüssel begrenzt', () {
    final keys = rememberKeys(
      [for (var i = 0; i < 5; i++) 'k$i'],
      ['k1', 'n'],
      max: 4,
    );
    expect(keys, ['k3', 'k4', 'k1', 'n']);
  });

  test('ohne Kindernamen (Schülerkonto): „in der Schule“', () {
    final p = _plan();
    final anon = KidPlan(
      firstName: '',
      colorIndex: 0,
      slots: p.slots,
      days: p.days,
    );
    final n = buildNotices(
      plan: anon,
      choice: const {},
      substitutions: subs,
      events: const [],
      now: DateTime(2026, 10, 19, 8),
    );
    expect(n.single.title, 'Heute in der Schule');
  });
}

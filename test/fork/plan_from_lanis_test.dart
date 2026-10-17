import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/ui/plan/plan_from_lanis.dart';
import 'package:lanis/fork/ui/plan/plan_model.dart';
import 'package:liblanis/liblanis.dart';

SphTimeOfDay _t(int h, int m) => SphTimeOfDay(hour: h, minute: m);

TimeTableRow _row(String label, int idx, (int, int) a, (int, int) b) =>
    TimeTableRow(
      TimeTableRowType.lesson,
      _t(a.$1, a.$2),
      _t(b.$1, b.$2),
      label,
      idx,
    );

TimetableSubject _s(
  String name,
  String? raum,
  String? lehrer,
  (int, int) a,
  (int, int) b, {
  int duration = 1,
}) => TimetableSubject(
  id: '$name-$lehrer',
  name: name,
  raum: raum,
  lehrer: lehrer,
  badge: null,
  duration: duration,
  startTime: _t(a.$1, a.$2),
  endTime: _t(b.$1, b.$2),
  stunde: null,
);

/// Aufbau wie der Plan von Schule A (Blöcke), Kürzel und Räume erfunden.
TimeTable _tt({bool ownEmpty = false}) {
  final b1 = ((9, 0), (10, 15));
  final b2 = ((10, 30), (11, 45));
  final days = <TimetableDay>[
    [
      _s('M', 'G1', 'AAA', b1.$1, b1.$2),
      _s('M', 'G1', 'BBB', b1.$1, b1.$2), // Doppelbesetzung
      _s('TXT', 'G1', 'CCC', b2.$1, b2.$2),
      _s('TXT', null, 'DDD', b2.$1, b2.$2), // echte Gruppen (gemischt)
    ],
    [
      _s('TRAIN', null, 'AAA', b1.$1, b1.$2),
      _s('TRAIN', null, 'EEE', b1.$1, b1.$2), // beide ohne Raum
    ],
    [_s('NAWI', 'G2', 'FFF', b1.$1, b2.$2, duration: 2)], // Doppelblock
    [], [],
  ];
  return TimeTable(
    hours: [
      _row('1.Block', 1, b1.$1, b1.$2),
      TimeTableRow(TimeTableRowType.pause, _t(10, 15), _t(10, 30), 'Pause', 2),
      _row('2.Block', 3, b2.$1, b2.$2),
    ],
    planForOwn: ownEmpty ? [[], [], [], [], []] : days,
    planForAll: days,
  );
}

/// Kurse wie in „Mein Unterricht“ (erfunden): Projekt Text bei CCC und DDD.
const List<CourseRef> _courses = [
  (name: 'Projekt Text 6 xy', teachers: {'CCC', 'DDD'}),
  (name: 'Mathematik 06 xy', teachers: {'AAA', 'BBB'}),
];

void main() {
  final plan = kidPlanFromTimetable(
    _tt(),
    firstName: 'Kind',
    colorIndex: 0,
    teacherNames: const {'AAA': 'Anna Alt', 'BBB': 'Bernd Bau'},
    courseNames: const [
      'Naturwissenschaften 06 xy (061NAWI05-IGS)',
      'Training Klasse 6',
      'Projekt Text 6',
    ],
  );

  test('Zeitraster: nur Unterrichtszeilen, Beschriftung vereinheitlicht', () {
    expect(plan.slots.map((s) => s.label), ['1. Block', '2. Block']);
    expect(plan.slots.first.start, '09:00');
    expect(plan.slots.last.end, '11:45');
  });

  test('Doppelbesetzung (gleiches Fach, gleicher Raum) = eine Stunde', () {
    final m = plan.days[0][0];
    expect(m.isParallel, isFalse);
    expect(m.options.single.teacher, 'AAA, BBB');
    expect(plan.teacherFull('AAA, BBB'), 'Anna Alt, Bernd Bau');
    expect(plan.teacherLast('AAA, BBB'), 'Alt/Bau');
    expect(plan.teacherCell('AAA, BBB'), 'Alt +1');
    expect(plan.teacherCell('AAA'), 'Alt');
  });

  test('beide ohne Raum ebenfalls zusammen, gemischt bleiben Gruppen', () {
    expect(
      plan.days[1][0].options.where((o) => o.short == 'TRAIN'),
      hasLength(1),
    );
    expect(plan.days[0][1].isParallel, isTrue, reason: 'TXT G1 und ohne Raum');
    expect(openGroupSubjects(plan, {}), {'TXT'});
  });

  test('Doppelblock belegt beide Stunden und wird ein Abschnitt', () {
    expect(plan.days[2][0].options.single.short, 'NAWI');
    expect(plan.days[2][1].options.single.short, 'NAWI');
    final blocks = dayBlocks(plan, 2, {});
    expect(blocks.map((b) => blockLabel(plan, b)), contains('1.–2. Block'));
  });

  test('Fachnamen: Tabelle, Kurscode, Wortanfang, sonst Kürzel', () {
    const courses = [
      'Naturwissenschaften 06 xy (061NAWI05-IGS)',
      'Training Klasse 6',
      'Projekt Text 6',
    ];
    expect(subjectFullName('M', courses), 'Mathematik');
    expect(subjectFullName('SP5', courses), 'Sport');
    expect(subjectFullName('NAWI', courses), 'Naturwissenschaften');
    expect(subjectFullName('TRAIN', courses), 'Training');
    expect(
      subjectFullName('TXT', courses),
      'TXT',
      reason: 'aus dem Kürzel allein nicht raten (anderswo Textil)',
    );
    expect(subjectFullName('ÄSTH', const []), 'Ästhetik');
    expect(subjectFullName('ZFU6', const []), 'ZFU6');
  });

  test('persönlicher Plan leer → Klassenplan', () {
    final p = kidPlanFromTimetable(
      _tt(ownEmpty: true),
      firstName: 'Kind',
      colorIndex: 0,
    );
    expect(p.days[0][0].isEmpty, isFalse);
  });

  test('Gruppe automatisch über die Kurs-Lehrkraft', () {
    final p = kidPlanFromTimetable(
      _tt(),
      firstName: 'K',
      colorIndex: 0,
      courses: _courses,
    );
    expect(openGroupSubjects(p, {}), {'TXT'});
    final auto = autoGroupChoice(p, [
      (name: 'Projekt Text 6 xy', teachers: {'DDD'}),
      (name: 'Mathematik 06 xy', teachers: {'AAA'}),
    ]);
    expect(auto, {'TXT': 'DDD'});
    expect(openGroupSubjects(p, effectiveChoice(auto, {})), isEmpty);
    // Eigene Wahl geht vor, '' = bewusst alle zeigen.
    expect(effectiveChoice(auto, {'TXT': 'CCC'}), {'TXT': 'CCC'});
    expect(effectiveChoice(auto, {'TXT': ''}), isEmpty);
  });

  test('keine Automatik ohne passenden Kurs oder bei Mehrdeutigkeit', () {
    final p = kidPlanFromTimetable(
      _tt(),
      firstName: 'K',
      colorIndex: 0,
      courses: _courses,
    );
    expect(
      autoGroupChoice(p, [
        (name: 'Sport 06', teachers: {'DDD'}),
      ]),
      isEmpty,
    );
    final ohneName = kidPlanFromTimetable(_tt(), firstName: 'K', colorIndex: 0);
    expect(
      autoGroupChoice(ohneName, [
        (name: 'TXT', teachers: {'DDD'}),
      ]),
      isEmpty,
      reason: 'Kürzel ohne Namen wird nicht geraten',
    );
  });

  test('zwei Kurs-Lehrkräfte in jeder Stunde → Team als eine Stunde', () {
    final p = kidPlanFromTimetable(
      _tt(),
      firstName: 'K',
      colorIndex: 0,
      courses: _courses,
    );
    final auto = autoGroupChoice(p, [
      (name: 'Projekt Text 6', teachers: {'CCC', 'DDD'}),
    ]);
    expect(auto, {'TXT': 'CCC, DDD'});
    expect(openGroupSubjects(p, auto), isEmpty);
    final r = resolveCell(p.days[0][1], auto) as ResolvedLesson;
    expect(r.lesson.teacher, 'CCC, DDD');
    expect(r.lesson.room, 'G1');
    final chosen = chosenOption(p, auto, 'TXT')!;
    expect(chosen.groupKey, 'CCC, DDD');
    // Eine Einzelgruppe bleibt wählbar.
    expect(
      (resolveCell(p.days[0][1], {'TXT': 'DDD'}) as ResolvedLesson).lesson.room,
      isNull,
    );
  });

  test('eigene Lehrernamen überschreiben und lassen sich löschen', () {
    final p = plan.withTeacherNames({'CCC': 'Frau Muster', 'AAA': ''});
    expect(p.teacherFull('CCC'), 'Frau Muster');
    expect(p.teacherFull('AAA'), 'AAA');
    expect(p.teacherFull('BBB'), 'Bernd Bau');
  });

  test('Fachname über die Lehrkräfte des Kurses, nicht aus dem Kürzel', () {
    final p = kidPlanFromTimetable(
      _tt(),
      firstName: 'K',
      colorIndex: 0,
      courses: _courses,
    );
    expect(p.days[0][1].options.first.subject, 'Projekt Text');
    expect(
      subjectsByCourseTeachers(
        {
          'X': {'AAA'},
        },
        const [
          (name: 'Kurs A', teachers: {'AAA'}),
          (name: 'Kurs B', teachers: {'AAA'}),
        ],
      ),
      isEmpty,
      reason: 'Gleichstand → Kürzel bleibt',
    );
    final mitMathe = kidPlanFromTimetable(
      _tt(),
      firstName: 'K',
      colorIndex: 0,
      courses: const [
        (name: 'Mathematik 06 xy', teachers: {'CCC', 'DDD'}),
      ],
    );
    expect(
      mitMathe.days[0][1].options.first.subject,
      'TXT',
      reason: 'Mathematik gehört schon zu „M“',
    );
  });
}

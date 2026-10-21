import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/courses_scan.dart' show ScanExam;
import 'package:lanis/fork/exams.dart';
import 'package:lanis/fork/l10n/l10n.dart';
import 'package:lanis/fork/ui/courses/course_detail_model.dart';
import 'package:lanis/fork/ui/courses/course_detail_page.dart';
import 'package:lanis/fork/ui/courses/courses_model.dart';
import 'package:lanis/fork/ui/kit.dart';
import 'package:lanis/fork/ui/plan/plan_model.dart';
import 'package:lanis/fork/ui/today/today_model.dart';
import 'package:liblanis/liblanis.dart';

CurrentEntry _e(
  String id,
  String? topic,
  DateTime date, {
  Homework? hw,
  String? presence,
  List<FileInfo> files = const [],
  List<LessonUpload> uploads = const [],
}) => CurrentEntry(
  entryID: id,
  topicTitle: topic,
  topicDate: date,
  homework: hw,
  presence: presence,
  files: files,
  uploads: uploads,
  schoolHours: '3.–4. Stunde',
);

/// Erfundene Kursmappe (keine echten Daten).
DetailedLesson _lesson() => DetailedLesson(
  courseID: 'c1',
  name: 'Englisch 07 b',
  teachers: [LessonTeacher(teacher: 'Wolf, Tim', teacherKuerzel: 'WOL')],
  history: [
    _e(
      '5',
      'Unit 2: At the station',
      DateTime(2026, 10, 15),
      hw: Homework(description: 'Vokabeln lernen', homeWorkDone: false),
      files: [FileInfo(name: 'Arbeitsblatt.pdf', url: Uri.parse('x'))],
    ),
    _e('4', 'Unit 2: Tickets', DateTime(2026, 10, 13), presence: 'fehlend'),
    _e('3', 'Unit 1: Test zurück', DateTime(2026, 10, 8)),
    _e('2', 'Unit 1: My school', DateTime(2026, 9, 29), presence: 'anwesend'),
    _e('1', null, DateTime(2026, 9, 22), presence: 'nicht erfasst'),
  ],
  marks: [LessonMark(name: 'Vokabeltest', date: '24.09.2026', mark: '2')],
  exams: [
    LessonExam(
      name: 'Kommende Leistungskontrollen',
      value:
          '02.11.2099 Lernkontrolle, 1. Std. (60 Min.)\n02.11.2099 Lernkontrolle',
    ),
  ],
  attendances: {'anwesend': '26', 'entschuldigt': '1', 'fehlend': '1'},
);

void main() {
  test('Themen: Teil vor dem Trenner, aufeinanderfolgende zusammen', () {
    expect(topicKey('Unit 2: Tickets'), 'Unit 2');
    expect(topicRest('Unit 2: Tickets'), 'Tickets');
    expect(topicKey('KL'), 'KL');
    expect(topicRest('KL'), isNull);
    final g = groupHistory(_lesson().history, noTopic: 'Ohne Thema');
    expect(g.map((x) => x.title), ['Unit 2', 'Unit 1', 'Ohne Thema']);
    expect(g.first.entries.length, 2);
    // Offen nach der Hausaufgabenliste (homeworkLists), sonst Portal-Marke.
    const portalOnly = CourseContext(title: 'E', fullName: 'E', teachers: []);
    expect(g.first.entries.where(portalOnly.homeworkOpen).length, 1);
    const ticked = CourseContext(
      title: 'E',
      fullName: 'E',
      teachers: [],
      openHomework: {},
    );
    expect(g.first.entries.where(ticked.homeworkOpen), isEmpty);
    expect(g.first.from, DateTime(2026, 10, 13));
    expect(g.first.to, DateTime(2026, 10, 15));
  });

  test('Anwesenheit, Abwesenheiten, Dateien', () {
    final d = _lesson();
    final c = attendanceCounts(d.attendances)!;
    expect((c.present, c.excused, c.missing), (26, 1, 1));
    expect(
      attendanceCounts({'unentschuldigt': '2', 'kurs': 'x'})!.missing,
      2,
      reason: '„unentschuldigt“ ist Fehlen, nicht Entschuldigt',
    );
    expect(attendanceCounts({'kurs': 'x'}), isNull);
    expect(absentEntries(d.history).map((e) => e.entryID), ['4']);
    expect(allFiles(d.history).single.$1.name, 'Arbeitsblatt.pdf');
  });

  test('nächste Stunde und Arbeit aus dem Kalender', () {
    const slots = [
      PlanSlot(label: '1. Block', start: '08:00', end: '09:30'),
      PlanSlot(label: '2. Block', start: '09:50', end: '11:20'),
    ];
    const en = PlanLesson(
      subject: 'Englisch',
      short: 'E',
      room: 'R112',
      teacher: 'WOL',
    );
    final plan = KidPlan(
      firstName: 'Kind',
      colorIndex: 0,
      slots: slots,
      days: [
        [
          const PlanCell([en]),
          const PlanCell([]),
        ],
        [const PlanCell([]), const PlanCell([])],
        [const PlanCell([]), const PlanCell([])],
        [
          const PlanCell([]),
          const PlanCell([en]),
        ],
        [const PlanCell([]), const PlanCell([])],
      ],
    );
    // Montag 10 Uhr: Montagsstunde vorbei → Donnerstag 2. Block.
    final n = nextLessonOf(plan, const {}, 'Englisch', {
      'WOL',
    }, DateTime(2026, 10, 19, 10))!;
    expect(n.day, DateTime(2026, 10, 22));
    expect(n.slot, '2. Block');
    expect(n.room, 'R112');
    expect(courseShortIn(plan, 'Englisch', const {}), 'E');
    expect(courseShortIn(plan, 'Ganztagsangebot', const {}), isNull);
    expect(
      isExtraOffer('Ganztagsangebot 06 (061KeineNoten04-IGS)', inPlan: true),
      isTrue,
    );
    expect(isExtraOffer('Englisch 07 b', inPlan: true), isFalse);
    // Wortformen und Kürzel als Kurstitel (Form wie Schule B, erfunden).
    const rev = PlanLesson(subject: 'Ev. Religion', short: 'REV', room: 'R1');
    expect(lessonBelongsTo(rev, 'Religion - evangelisch', const {}), isTrue);
    const rka = PlanLesson(subject: 'Kath. Religion', short: 'RKA', room: 'R1');
    expect(lessonBelongsTo(rka, 'Religion - evangelisch', const {}), isFalse);
    const mu = PlanLesson(subject: 'Musik', short: 'MU', room: 'R1');
    expect(lessonBelongsTo(mu, 'MU', const {}), isTrue);

    final now = DateTime(2026, 10, 19);
    final items = [
      WeekItem(
        day: DateTime(2026, 10, 27),
        title: 'Klassenarbeit Englisch',
        kind: WeekKind.exam,
      ),
      WeekItem(
        day: DateTime(2026, 10, 28),
        title: 'Klassenarbeit Mathe',
        kind: WeekKind.exam,
      ),
    ];
    UpcomingExam? next(String subject) => nextExamOfSubject(
      subject: subject,
      folder: const [],
      calendar: items,
      now: now,
    );
    expect(next('Englisch')?.day, DateTime(2026, 10, 27));
    expect(next('Englisch')?.title, 'Englisch: Klassenarbeit');
    expect(next('Mathematik')?.day, DateTime(2026, 10, 28));
    expect(next('Deutsch'), isNull);
  });

  test('Kursliste: Hausaufgabe ohne Text, Fehlstunden, Kürzel', () {
    final items = courseItemsFrom([
      Lesson(
        courseID: '1',
        name: 'Englisch 07 b',
        teachers: [LessonTeacher(teacher: 'Wolf, Tim', teacherKuerzel: 'WOL')],
        courseURL: Uri.parse('x'),
        attendances: {'fehlend': '2'},
        currentEntry: CurrentEntry(
          entryID: 'e',
          files: const [],
          uploads: const [],
          topicDate: DateTime(2026, 10, 1),
          homework: Homework(description: ' ', homeWorkDone: false),
        ),
      ),
    ]);
    expect(items.single.homework, '');
    expect(items.single.hasOpenHomework, isTrue);
    expect(items.single.missing, 2);
    expect(items.single.teacherCodes, ['WOL']);
  });

  test('Lehrkräfte: Name und Kürzel bleiben gepaart', () {
    // Prüfbefund 17.10.26: leerer eigener Name verschob die Zuordnung.
    final items = courseItemsFrom(
      [
        Lesson(
          courseID: '1',
          name: 'Projekt 7 b',
          teachers: [
            LessonTeacher(teacher: 'Alt, Anna', teacherKuerzel: 'AAA'),
            LessonTeacher(teacher: null, teacherKuerzel: null),
            LessonTeacher(teacher: 'Berg, Ben', teacherKuerzel: 'BBB'),
          ],
          courseURL: Uri.parse('x'),
        ),
      ],
      ownNames: const {'AAA': ''},
    );
    expect(items.single.teachers, ['Anna Alt', 'Ben Berg']);
    expect(items.single.teacherCodes, ['AAA', 'BBB']);
  });

  test('Leistungskontrollen: Zeilen mit Datum, ohne Doppelungen', () {
    // Form wie im Portal (Bildschirmfoto 17.10.26), erfundene Daten.
    final s = examSections([
      LessonExam(
        name: 'Kommende Leistungskontrollen',
        value:
            '02.11.2026 Lernkontrolle, 1. Std. (60 Min.)\n'
            '08.03.2027 Lernkontrolle, 1. Std. (60 Min.)\n'
            '02.11.2026 Lernkontrolle\n'
            '08.03.2027 Lernkontrolle',
      ),
      LessonExam(name: 'Leer', value: 'Keine Daten!'),
    ]);
    expect(s, hasLength(1));
    expect(s.single.title, 'Kommende Leistungskontrollen');
    expect(s.single.lines.map((l) => l.text), [
      'Lernkontrolle, 1. Std. (60 Min.)',
      'Lernkontrolle, 1. Std. (60 Min.)',
    ]);
    expect(s.single.lines.first.date, DateTime(2026, 11, 2));
    // Kursmappe vor Kalender, Vergangenes zählt nicht (exams.dart).
    final next = nextExamOfSubject(
      subject: 'Englisch',
      folder: [
        for (final (d, x) in [
          (DateTime(2026, 10, 1), 'Arbeit, alt'),
          (DateTime(2026, 11, 2), 'Lernkontrolle, 1. Std.'),
        ])
          ScanExam(course: 'e', subject: 'Englisch', day: d, text: x),
      ],
      calendar: [
        WeekItem(
          day: DateTime(2026, 11, 2),
          title: 'Englisch 9b Lernkontrolle',
          kind: WeekKind.exam,
          time: '08:00',
        ),
      ],
      now: DateTime(2026, 10, 17),
    );
    expect(next?.title, 'Englisch: Lernkontrolle');
    expect(next?.detail, '1. Std.');
    expect(next?.fromCalendar, isFalse);
  });

  for (final (lang, scale) in [('de', 1.0), ('tr', 1.26 * 1.3)]) {
    testWidgets('Kursseite $lang ohne Überlauf bei ×$scale', (t) async {
      t.view.physicalSize = const Size(1080, 2424);
      t.view.devicePixelRatio = 2.625;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          localizationsDelegates: ForkL10n.localizationsDelegates,
          supportedLocales: ForkL10n.supportedLocales,
          locale: Locale(lang),
          builder: (c, w) => MediaQuery(
            data: MediaQuery.of(
              c,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: w!,
          ),
          home: CourseDetailPage(
            course: CourseContext(
              title: 'Englisch',
              fullName: 'Englisch 07 b',
              teachers: const [('WOL', 'Tim Wolf')],
              calendarExams: [
                WeekItem(
                  day: DateTime.now().add(const Duration(days: 9)),
                  title: 'Klassenarbeit Englisch',
                  kind: WeekKind.exam,
                ),
              ],
            ),
            load: ({required bool firstHalf}) async => _lesson(),
            onWrite: (_) {},
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      final list = find.byType(Scrollable).first;
      await t.scrollUntilVisible(find.text('Unit 2'), 300, scrollable: list);
      expect(find.text('Unit 2'), findsOneWidget);
      // Verlauf zugeklappt: Stunden erst nach Antippen sichtbar.
      expect(find.text('Tickets'), findsNothing);
      await t.ensureVisible(find.text('Unit 2'));
      await t.pumpAndSettle();
      await t.tap(find.text('Unit 2'));
      await t.pumpAndSettle();
      await t.scrollUntilVisible(find.text('Tickets'), 200, scrollable: list);
      expect(find.text('Tickets'), findsOneWidget);
      expect(t.takeException(), isNull);
      expect(KitPalette.light.bg, isNotNull);
    });
  }
}

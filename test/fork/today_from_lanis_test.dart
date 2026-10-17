import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/l10n/l10n.dart';
import 'package:lanis/fork/school_links.dart';
import 'package:lanis/fork/ui/plan/plan_model.dart';
import 'package:lanis/fork/ui/today/today_from_lanis.dart';
import 'package:lanis/fork/ui/today/today_model.dart';
import 'package:lanis/fork/ui/today/today_page.dart' show listSlot;
import 'package:liblanis/liblanis.dart';

final de = forkL10nFor('de');

/// Erfundener Plan im Aufbau von Schule A (Blöcke, Doppelbesetzung, Gruppen).
KidPlan _plan() {
  const slots = [
    PlanSlot(label: '1. Block', start: '09:00', end: '10:15'),
    PlanSlot(label: '2. Block', start: '10:30', end: '11:45'),
    PlanSlot(label: '3. Block', start: '12:30', end: '13:45'),
  ];
  const m = PlanLesson(
    subject: 'Mathematik',
    short: 'M',
    room: 'R1',
    teacher: 'AAA, BBB',
  );
  const txtA = PlanLesson(
    subject: 'Projekt Text',
    short: 'TXT',
    room: 'R1',
    teacher: 'CCC',
  );
  const txtB = PlanLesson(
    subject: 'Projekt Text',
    short: 'TXT',
    teacher: 'DDD',
  );
  const sp = PlanLesson(
    subject: 'Sport',
    short: 'SP',
    room: 'H',
    teacher: 'EEE',
  );
  PlanCell c(List<PlanLesson> o) => PlanCell(o);
  // Mo: M, TXT (Gruppen), –  · Di: Sport Doppelblock 1–2, M
  return KidPlan(
    firstName: 'Kind',
    colorIndex: 0,
    slots: slots,
    days: [
      [
        c([m]),
        c([txtA, txtB]),
        c([]),
      ],
      [
        c([sp]),
        c([sp]),
        c([m]),
      ],
      [c([]), c([]), c([])],
      [c([]), c([]), c([])],
      [c([]), c([]), c([])],
    ],
    teacherNames: const {
      'AAA': 'Anna Alt',
      'EEE': 'Eva Ernst',
      'FFF': 'Fritz Fink',
    },
  );
}

Substitution _sub(
  String tag,
  String stunde, {
  String? art,
  String? fach,
  String? raum,
  String? raumAlt,
  String? lehrer,
  String? vertreter,
  String? hinweis,
}) => Substitution(
  tag: tag,
  tag_en: '',
  stunde: stunde,
  art: art,
  fach: fach,
  raum: raum,
  raum_alt: raumAlt,
  Lehrerkuerzel: lehrer,
  Vertreterkuerzel: vertreter,
  hinweis: hinweis,
);

SubstitutionDay _day(String date, List<Substitution> s) =>
    SubstitutionDay(parsedDate: date, substitutions: s);

void main() {
  final plan = _plan();
  final monday = DateTime(2026, 10, 19, 9, 30);

  test('Tag aus dem Plan: Abschnitte, Gruppenhinweis, Zählung', () {
    final l = dayLessonsFor(plan, 0, const {}, t: de);
    expect(l.map((x) => x.subject), ['Mathematik', 'Projekt Text']);
    expect(l.first.teacher, 'Anna Alt, BBB');
    expect(l.last.teacher, 'Gruppe im Plan wählen');
    expect(
      dayLessonsFor(plan, 0, const {'TXT': 'DDD'}, t: de).last.teacher,
      'DDD',
    );
    final di = dayLessonsFor(plan, 1, const {}, t: de);
    expect(di.first.slot, '1.–2. Block');
    expect(di.first.end, '11:45');
    expect(periodsLabelFor(plan, 1, const {}, t: de), '3 Blöcke heute');
    expect(dayLessonsFor(plan, 5, const {}, t: de), isEmpty, reason: 'Samstag');
  });

  test('Ausfall, Raumwechsel, Vertretung landen im Tag und im Kasten', () {
    final r = applySubstitutions(
      t: de,
      plan: plan,
      choice: const {'TXT': 'CCC'},
      now: monday,
      days: [
        _day('19.10.2026', [
          _sub(
            '19.10.2026',
            '1',
            art: 'Raumänderung',
            raum: 'R9',
            raumAlt: 'R1',
          ),
          _sub('19.10.2026', '2', art: 'Entfall', fach: 'TXT', lehrer: 'CCC'),
        ]),
        _day('20.10.2026', [
          _sub(
            '20.10.2026',
            '1 - 2',
            art: 'Vertretung',
            fach: 'SP',
            lehrer: 'EEE',
            vertreter: 'FFF',
            raum: 'H',
          ),
        ]),
      ],
    );
    expect(r.today[0].change, ChangeKind.roomChange);
    expect(r.today[0].room, 'R9');
    expect(r.today[0].changeDetail, 'R9 statt R1');
    expect(r.today[1].cancelled, isTrue);
    expect(r.changes, hasLength(3));
    final di = r.changes.last;
    expect(di.slot, '1.–2. Block');
    expect(di.subject, 'Sport');
    expect(di.kind, ChangeKind.substitution);
    expect(di.detail, 'Fritz Fink');
  });

  test(
    'Kalender: Vertretungen der Woche im Plan, nur die betroffene Gruppe',
    () {
      final week = [for (var i = 0; i < 5; i++) DateTime(2026, 10, 19 + i)];
      final p = planWithSubstitutions(
        t: de,
        plan: plan,
        week: week,
        days: [
          _day('19.10.2026', [
            _sub('19.10.2026', '2', art: 'Entfall', fach: 'TXT', lehrer: 'CCC'),
          ]),
          _day('20.10.2026', [
            _sub(
              '20.10.2026',
              '1 - 2',
              art: 'Raumänderung',
              fach: 'SP',
              raum: 'H2',
              raumAlt: 'H',
            ),
          ]),
          _day('03.11.2026', [_sub('03.11.2026', '1', art: 'Entfall')]),
        ],
      );
      final mo2 = p.days[0][1].options;
      expect(
        mo2.firstWhere((o) => o.teacher == 'CCC').change,
        ChangeKind.cancelled,
      );
      expect(mo2.firstWhere((o) => o.teacher == 'DDD').change, isNull);
      expect(p.days[1][0].options.single.room, 'H2');
      expect(p.days[1][1].options.single.change, ChangeKind.roomChange);
      expect(
        planWithSubstitutions(plan: plan, week: week, days: const [], t: de),
        same(plan),
      );
    },
  );

  test('Vertretung der anderen Gruppe wird übergangen', () {
    final r = applySubstitutions(
      t: de,
      plan: plan,
      choice: const {'TXT': 'CCC'},
      now: monday,
      days: [
        _day('19.10.2026', [
          _sub('19.10.2026', '2', art: 'Entfall', fach: 'TXT', lehrer: 'DDD'),
        ]),
      ],
    );
    expect(r.changes, isEmpty);
    expect(r.today[1].change, isNull);
  });

  test('Doppelbesetzung: fehlt eine Lehrkraft, findet die Stunde statt', () {
    final r = applySubstitutions(
      t: de,
      plan: plan,
      choice: const {},
      now: monday,
      days: [
        _day('19.10.2026', [
          _sub('19.10.2026', '1', art: 'Entfall', fach: 'M', lehrer: 'AAA'),
        ]),
      ],
    );
    expect(r.today[0].change, ChangeKind.substitution);
    expect(r.today[0].changeDetail, 'Anna Alt fehlt');
  });

  test('unbekannte Art gilt als Vertretung, nie als Ausfall', () {
    final c = classifySubstitution(
      t: de,
      _sub('x', '1', art: 'Sonderregelung', hinweis: 'Aula'),
    );
    expect(c.kind, ChangeKind.substitution);
    expect(c.detail, 'Aula');
    expect(
      classifySubstitution(_sub('x', '1', art: '<b>Entfall</b>'), t: de).kind,
      ChangeKind.cancelled,
      reason: 'HTML aus dem Portal',
    );
  });

  test('Tagesliste: kurze Stundenbezeichnung', () {
    expect(listSlot('2. Block'), '2.');
    expect(listSlot('1.–2. Block'), '1.–2.');
    expect(listSlot('3.–4.'), '3.–4.');
  });

  test('Klasse aus den Kursnamen', () {
    expect(
      classFromCourses(const [
        'Naturwissenschaften 06 xy (061NAWI05-IGS)',
        'Mathematik 06 xy',
        'Training Klasse 6',
      ]),
      '06 XY',
    );
    expect(classFromCourses(const ['Sport']), '');
    expect(shortSchoolName('Musterschule (Frankfurt)'), 'Musterschule');
  });

  group('Kalender', () {
    final cats = [
      CalendarEventCategory(id: 3, colorArgb: 0, name: 'Arbeiten'),
      CalendarEventCategory(
        id: 4,
        colorArgb: 0,
        name: 'Ferien/Schulfreie Tage',
      ),
      CalendarEventCategory(id: 6, colorArgb: 0, name: 'Pausenaufsicht'),
    ];
    CalendarEvent ev(
      String title,
      DateTime a,
      DateTime b, {
      int? cat,
      bool allDay = false,
    }) => CalendarEvent(
      startTime: a,
      endTime: b,
      secret: false,
      id: title,
      isNew: false,
      public: true,
      private: false,
      allDay: allDay,
      category: cat == null ? null : cats.firstWhere((c) => c.id == cat),
      description: '',
      title: title,
    );
    final now = DateTime(2026, 10, 19, 8);

    test('Art, Uhrzeit, Zeitraum und Jahrgang', () {
      final items = weekItemsFromCalendar(
        [
          ev(
            'Lernkontrolle',
            DateTime(2026, 10, 21, 9),
            DateTime(2026, 10, 21, 10),
            cat: 3,
          ),
          ev(
            'Herbstferien',
            DateTime(2026, 10, 5),
            DateTime(2026, 10, 19, 23, 59),
            cat: 4,
            allDay: true,
          ),
          ev(
            '5-7 Klassen Elternabend',
            DateTime(2026, 10, 22, 18),
            DateTime(2026, 10, 22, 19),
          ),
          ev(
            '8-10 Klassen Elternabend',
            DateTime(2026, 10, 22, 19),
            DateTime(2026, 10, 22, 20),
          ),
          ev(
            'Aufsicht',
            DateTime(2026, 10, 20, 9),
            DateTime(2026, 10, 20, 10),
            cat: 6,
          ),
          ev(
            'Abgabe Bewerbung',
            DateTime(2026, 10, 23),
            DateTime(2026, 10, 23, 23, 59),
            allDay: true,
          ),
          ev('Vorbei', DateTime(2026, 10, 16, 9), DateTime(2026, 10, 16, 10)),
          ev('Zu weit', DateTime(2026, 11, 30, 9), DateTime(2026, 11, 30, 10)),
        ],
        now,
        childIndex: 0,
        className: '06 XY',
      );
      expect(items.map((i) => i.title), [
        'Herbstferien',
        'Lernkontrolle',
        '5-7 Klassen Elternabend',
        'Abgabe Bewerbung',
      ]);
      expect(items[0].kind, WeekKind.free);
      expect(items[0].day, DateTime(2026, 10, 19), reason: 'läuft noch');
      expect(items[1].kind, WeekKind.exam);
      expect(items[1].time, '09:00');
      expect(items[3].kind, WeekKind.deadline);
      expect(items[3].time, isNull);
    });

    test(
      'Essenshinweise: nicht als Kachel, aber an der Karte und im Kalender',
      () {
        final events = [
          ev(
            'Kein Essen für alle Jg.!',
            DateTime(2026, 10, 19),
            DateTime(2026, 10, 19, 23, 59),
            allDay: true,
          ),
          ev(
            'Essen nur für 5, 6 und 7 Jg.',
            DateTime(2026, 10, 20, 11),
            DateTime(2026, 10, 20, 12),
          ),
          ev(
            'Essen nur für 8 und 9 Jg.',
            DateTime(2026, 10, 20, 11),
            DateTime(2026, 10, 20, 12),
          ),
          ev(
            'Interessen-AG',
            DateTime(2026, 10, 20, 14),
            DateTime(2026, 10, 20, 15),
          ),
        ];
        final tiles = weekItemsFromCalendar(events, now, className: '06 XY');
        expect(tiles.map((i) => i.title), ['Interessen-AG']);
        final all = weekItemsFromCalendar(
          events,
          now,
          className: '06 XY',
          includeMeals: true,
        );
        expect(all.where((i) => i.kind == WeekKind.meal), hasLength(2));
        expect(
          mealHintFor(events, now, t: de, className: '06 XY'),
          'Heute: Kein Essen für alle Jg.!',
        );
        expect(
          mealHintFor(
            events,
            DateTime(2026, 10, 19, 15),
            t: de,
            className: '06 XY',
          ),
          'Morgen: Essen nur für 5, 6 und 7 Jg.',
        );
        expect(forGrade('Essen nur für 5, 6 und 7 Jg.', 8), isFalse);
      },
    );

    test('mehrtägig: läuft bis', () {
      final items = weekItemsFromCalendar([
        ev(
          'Herbstferien',
          DateTime(2026, 10, 5),
          DateTime(2026, 10, 23, 23, 59),
          cat: 4,
          allDay: true,
        ),
      ], now);
      expect(items.single.until, DateTime(2026, 10, 23));
    });

    test('ohne bekannte Klasse kein Jahrgangsfilter', () {
      final items = weekItemsFromCalendar([
        ev(
          '8-10 Klassen Elternabend',
          DateTime(2026, 10, 22, 19),
          DateTime(2026, 10, 22, 20),
        ),
      ], now);
      expect(items, hasLength(1));
      expect(items.single.childIndex, isNull);
    });
  });

  test('Moodle nur, wenn die Schule es anbietet; Mensa-Adresse', () {
    expect(
      offersMoodle(const [
        {'Name': 'Stundenplan', 'link': 'stundenplan.php'},
      ]),
      isFalse,
    );
    expect(
      offersMoodle(const [
        {
          'Name': 'Lernplattform',
          'link': 'https://mo1234.schulportal.hessen.de',
        },
      ]),
      isTrue,
    );
    expect(
      normalizeMensaUrl('bestellung.example.de'),
      'https://bestellung.example.de',
    );
    expect(
      normalizeMensaUrl(' https://x.example/login '),
      'https://x.example/login',
    );
    expect(normalizeMensaUrl('kein link'), isNull);
    expect(
      normalizeMensaUrl('http://bestellung.example.de/a'),
      'https://bestellung.example.de/a',
    );
    expect(normalizeMensaUrl('https://nutzer@bestellung.example.de'), isNull);
    expect(normalizeMensaUrl(''), isNull);
  });
}

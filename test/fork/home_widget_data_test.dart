import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/exams.dart';
import 'package:lanis/fork/l10n/l10n.dart';
import 'package:lanis/fork/ui/plan/plan_model.dart';
import 'package:lanis/fork/widget/home_widget_data.dart';
import 'package:liblanis/liblanis.dart';

/// Startbildschirm-Widget (Entwurf 4, Abnahme 28.10.26): Abbildung von Plan
/// und Vertretungsplan auf Kacheln. Erfundene Daten, keine echten Namen.

final de = forkL10nFor('de');

/// Jeden Tag gleich: Deutsch 1.–2., Englisch 3., Mathematik 4., Sport 5.–6.
KidPlan _plan() {
  const slots = [
    PlanSlot(label: '1.', start: '08:00', end: '08:45'),
    PlanSlot(label: '2.', start: '08:50', end: '09:35'),
    PlanSlot(label: '3.', start: '09:55', end: '10:40'),
    PlanSlot(label: '4.', start: '10:45', end: '11:30'),
    PlanSlot(label: '5.', start: '11:45', end: '12:30'),
    PlanSlot(label: '6.', start: '12:35', end: '13:20'),
  ];
  const d = PlanLesson(
    subject: 'Deutsch',
    short: 'D',
    room: 'R021',
    teacher: 'AAA',
  );
  const e = PlanLesson(
    subject: 'Englisch',
    short: 'E',
    room: 'R105',
    teacher: 'BBB',
  );
  const m = PlanLesson(
    subject: 'Mathematik',
    short: 'M',
    room: 'R106',
    teacher: 'CCC',
  );
  const sp = PlanLesson(
    subject: 'Sport',
    short: 'SP',
    room: 'H1',
    teacher: 'DDD',
  );
  List<PlanCell> day() => [
    const PlanCell([d]),
    const PlanCell([d]),
    const PlanCell([e]),
    const PlanCell([m]),
    const PlanCell([sp]),
    const PlanCell([sp]),
  ];
  return KidPlan(
    firstName: 'Kind',
    colorIndex: 1,
    slots: slots,
    days: [for (var i = 0; i < 5; i++) day()],
  );
}

Substitution _sub(
  String stunde, {
  String? art,
  String? fach,
  String? raum,
  String? raumAlt,
  String? lehrer,
  String? vertreter,
}) => Substitution(
  tag: '',
  tag_en: '',
  stunde: stunde,
  art: art,
  fach: fach,
  raum: raum,
  raum_alt: raumAlt,
  Lehrerkuerzel: lehrer,
  Vertreterkuerzel: vertreter,
);

SubstitutionDay _day(String date, List<Substitution> s) =>
    SubstitutionDay(parsedDate: date, substitutions: s);

void main() {
  final plan = _plan();
  // Dienstag früh; nächster Schultag Mittwoch.
  final tuesday = DateTime(2026, 10, 27, 7, 30);

  final days = [
    _day('27.10.2026', [
      _sub(
        '3',
        art: 'Vertretung',
        fach: 'E',
        lehrer: 'BBB',
        vertreter: 'XXX',
        raum: 'R117',
      ),
      _sub(
        '4',
        art: 'Raumänderung',
        fach: 'M',
        lehrer: 'CCC',
        raum: 'R310',
        raumAlt: 'R106',
      ),
      _sub('5 - 6', art: 'Entfall', fach: 'SP', lehrer: 'DDD'),
    ]),
    _day('28.10.2026', [
      _sub('1 - 2', art: 'Entfall', fach: 'D', lehrer: 'AAA'),
    ]),
  ];

  List<WidgetItem> items(List<SubstitutionDay> d, DateTime now) =>
      widgetItems(plan: plan, choice: const {}, days: d, now: now, t: de);

  test('Reihenfolge: heute vor dem nächsten Schultag, je Tag nach Stunde', () {
    final r = items(days, tuesday);
    expect(r.map((i) => '${isoDate(i.date)} ${i.title}'), [
      '2026-10-27 Englisch',
      '2026-10-27 Mathematik',
      '2026-10-27 Sport',
      '2026-10-28 Deutsch',
    ]);
  });

  test('Ausfall am Tagesende: „Schluss“ mit Ende der letzten Stunde', () {
    final sport = items(days, tuesday).firstWhere((i) => i.title == 'Sport');
    expect(sport.kind, WidgetKind.cancel);
    expect(sport.what, 'fällt aus');
    expect(sport.slot, '5.–6. Std.');
    expect(sport.detail, 'Schluss 11:30');
    expect(sport.end, '13:20');
  });

  test('Ausfall am Tagesanfang: „Start erst“ mit Beginn der ersten Stunde', () {
    final german = items(days, tuesday).firstWhere((i) => i.title == 'Deutsch');
    expect(german.kind, WidgetKind.cancel);
    expect(german.slot, '1.–2. Std.');
    expect(german.detail, 'Start erst 09:55');
  });

  test('Ausfall mitten im Tag: keine Folge', () {
    final r = items([
      _day('27.10.2026', [_sub('3', art: 'Entfall', fach: 'E', lehrer: 'BBB')]),
    ], tuesday);
    expect(r.single.kind, WidgetKind.cancel);
    expect(r.single.detail, isNull);
  });

  test('Vertretung nennt den Raum der Vertretungszeile', () {
    final english = items(days, tuesday).first;
    expect(english.kind, WidgetKind.change);
    expect(english.what, 'Vertretung');
    expect(english.slot, '3. Std.');
    expect(english.detail, 'Raum R117');
  });

  test('Raumwechsel: „neu statt alt“', () {
    final math = items(days, tuesday)[1];
    expect(math.kind, WidgetKind.room);
    expect(math.what, 'Raumwechsel');
    expect(math.detail, 'R310 statt R106');
  });

  test('Nichts geändert: keine Einträge, ruhige Fläche in der Datei', () {
    expect(items(const [], tuesday), isEmpty);
    final p = homeWidgetPayload(
      account: 3,
      kid: 1,
      items: const [],
      now: tuesday,
      t: de,
    );
    expect(p['items'], isEmpty);
    // Ohne Vorname kein Feld; mit Vorname steht er im Kopf (28.10.26).
    expect(p.containsKey('name'), isFalse);
    expect(
      homeWidgetPayload(
        account: 3,
        kid: 1,
        items: const [],
        now: tuesday,
        t: de,
        name: ' Lena ',
      )['name'],
      'Lena',
    );
    final labels = p['labels']! as Map;
    expect(labels['calmTitle'], 'Alles nach Plan');
    expect(labels['calmText'], 'heute und morgen');
  });

  test('Vergangene Tage: Dart nimmt nur heute und den nächsten Schultag, '
      'Kotlin filtert nach Datum und Ende', () {
    // Montag liegt vor „heute“ (Dienstag) und fällt schon hier weg.
    final r = items([
      _day('26.10.2026', [_sub('3', art: 'Entfall', fach: 'E', lehrer: 'BBB')]),
      ...days,
    ], tuesday);
    expect(r.any((i) => i.date.day == 26), isFalse);
    // Jeder Eintrag trägt Datum und Ende – daraus entscheidet
    // SchoolWidget.kt nach Mitternacht bzw. nach der Stunde selbst
    // (visibleItems), auch ohne neue Datei.
    final json = r.first.toJson();
    expect(json['date'], '2026-10-27');
    expect(json['end'], '10:40');
  });

  test('Freitag: nächster Schultag ist Montag', () {
    final friday = DateTime(2026, 10, 30, 7, 0);
    final r = items([
      _day('02.11.2026', [_sub('3', art: 'Entfall', fach: 'E', lehrer: 'BBB')]),
    ], friday);
    expect(isoDate(r.single.date), '2026-11-02');
  });

  test('Datei: Datum, Wochentage, Aufgaben, Arbeit', () {
    final p = homeWidgetPayload(
      account: 3,
      kid: 1,
      items: items(days, tuesday),
      now: tuesday,
      t: de,
      stand: DateTime(2026, 10, 27, 7, 52),
      homework: 2,
      exam: UpcomingExam(
        day: DateTime(2026, 10, 29),
        subject: 'Mathematik',
        kind: 'Test',
      ),
    );
    expect(p['account'], 3);
    expect(p['kid'], 1);
    expect((p['dates']! as Map)['2026-10-27'], 'Di, 27. Okt.');
    expect((p['dates']! as Map).length, 8);
    expect(((p['labels']! as Map)['weekdays'] as List).first, 'Mo');
    expect((p['labels']! as Map)['today'], 'heute');
    expect(p['homework'], '2 Aufgaben');
    expect(p['exam'], {'date': '2026-10-29', 'label': 'Test'});
    expect(p['stand'], '2026-10-27T07:52:00.000');
    expect((p['items']! as List).length, 4);
  });

  test('Nächste Arbeit nur innerhalb von 7 Tagen', () {
    UpcomingExam at(int day) =>
        UpcomingExam(day: DateTime(2026, 11, day), subject: 'Bio', kind: '');
    expect(nextExamWithin([at(3)], tuesday)?.day.day, 3);
    expect(nextExamWithin([at(4)], tuesday), isNull);
  });

  test('Stunde ohne Zahl bleibt, wie die Schule sie nennt', () {
    expect(widgetSlotLabel(de, '2. Block'), '2. Block');
    expect(widgetSlotLabel(de, '4.'), '4. Std.');
  });
}

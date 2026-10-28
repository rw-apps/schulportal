import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/exams.dart';
import 'package:lanis/fork/l10n/l10n.dart';
import 'package:lanis/fork/ui/plan/plan_model.dart';
import 'package:lanis/fork/widget/home_widget_data.dart';
import 'package:lanis/fork/widget/home_widget_sync.dart'
    show storeWidgetKidSelection, widgetKidSelection;
import 'package:liblanis/liblanis.dart';

/// Startbildschirm-Widget (Entwurf 5, Abnahme 28.10.26): Abbildung von Plan
/// und Vertretungsplan auf Kacheln, Datei mit allen Kindern, Zusammenführen
/// im Hintergrund, Übernahme der alten Einstellung. Stufen und Reihenfolge
/// der Kacheln prüft der JVM-Test android/app/src/test/.../WidgetModelTest.kt.
/// Erfundene Daten (Jonas, Lena), keine echten Namen.

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

  test('Drei Zeilen: Fach / was / Stunde ohne „Std.“', () {
    final r = items(days, tuesday);
    final sport = r.firstWhere((i) => i.title == 'Sport');
    expect(sport.kind, WidgetKind.cancel);
    expect(sport.what, 'fällt aus');
    expect(sport.word, 'fällt aus');
    expect(sport.slot, '5.–6.');
    expect(sport.end, '13:20');
    final english = r.first;
    expect(english.kind, WidgetKind.change);
    expect(english.what, 'Vertretung');
    expect(english.slot, '3.');
  });

  test('Raumwechsel: Kachel nennt den Raum, die Zelle das Wort', () {
    final math = items(days, tuesday)[1];
    expect(math.kind, WidgetKind.room);
    expect(math.what, 'Raum R310');
    expect(math.word, 'Raumwechsel');
    expect(math.toJson()['word'], 'Raumwechsel');
  });

  test('Vergangene Tage: Dart nimmt nur heute und den nächsten Schultag, '
      'Kotlin filtert nach Datum und Ende', () {
    final r = items([
      _day('26.10.2026', [_sub('3', art: 'Entfall', fach: 'E', lehrer: 'BBB')]),
      ...days,
    ], tuesday);
    expect(r.any((i) => i.date.day == 26), isFalse);
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

  Map<String, Object?> jonas({List<WidgetItem>? list, int hw = 2}) =>
      widgetKidEntry(
        account: 1,
        name: ' Jonas ',
        color: 0,
        items: list ?? items(days, tuesday),
        stand: DateTime(2026, 10, 27, 7, 52),
        homework: hw,
        homeworkDue: DateTime(2026, 10, 28),
        exam: UpcomingExam(
          day: DateTime(2026, 10, 29),
          subject: 'Mathematik',
          kind: '',
        ),
        meal: 'Gnocchi',
        mealDay: DateTime(2026, 10, 27),
      );
  Map<String, Object?> lena() => widgetKidEntry(
    account: 2,
    name: 'Lena',
    color: 1,
    items: const [],
    homework: 3,
  );

  test('Datei Version 2: alle Kinder in Familienreihenfolge, Texte dazu', () {
    final p = homeWidgetPayload(kids: [jonas(), lena()], now: tuesday, t: de);
    expect(p['v'], 2);
    final kids = (p['kids']! as List).cast<Map<String, Object?>>();
    expect(kids.map((k) => k['name']), ['Jonas', 'Lena']);
    expect(kids[0]['account'], 1);
    expect(kids[0]['color'], 0);
    expect(kids[0]['hw'], 2);
    expect(kids[0]['hwText'], '2 Aufgaben');
    expect(kids[0]['hwDue'], '2026-10-28');
    expect(kids[0]['exam'], {
      'date': '2026-10-29',
      'subject': 'Mathematik',
      'kind': '',
    });
    expect(kids[0]['meal'], {'date': '2026-10-27', 'name': 'Gnocchi'});
    expect(kids[0]['stand'], '2026-10-27T07:52:00.000');
    expect((kids[0]['items']! as List).length, 4);
    expect(kids[1].containsKey('stand'), isFalse);
    // Summe für die Fußzeile ab drei Kindern.
    expect(p['hwTotal'], '5 Aufgaben');
    expect((p['dates']! as Map)['2026-10-27'], 'Di, 27. Okt.');
    expect((p['dates']! as Map).length, 8);
    final labels = p['labels']! as Map;
    expect((labels['weekdays'] as List).first, 'Mo');
    expect((labels['weekdaysLong'] as List)[3], 'Donnerstag');
    expect(labels['today'], 'heute');
    expect(labels['calmTitle'], 'Nach Plan');
    expect(labels['calmText'], 'und morgen');
    expect(labels['calmShort'], 'nach Plan');
    expect(labels['homeworkOpen'], 'offen');
    expect(labels['dueFor'], 'für %s');
    expect(labels['exam'], 'Arbeit');
    expect(labels['meal'], 'Essen');
    // Englisch/Türkisch: Platzhalter bleibt für Kotlin erhalten.
    expect(
      (homeWidgetPayload(
            kids: const [],
            now: tuesday,
            t: forkL10nFor('tr'),
          )['labels']!
          as Map)['dueFor'],
      '%s için',
    );
    // Ohne Aufgaben kein Text, keine Summe.
    final none = homeWidgetPayload(kids: [jonas(hw: 0)], now: tuesday, t: de);
    expect((none['kids']! as List).single, isNot(contains('hwText')));
    expect(none.containsKey('hwTotal'), isFalse);
    expect(jsonDecode(jsonEncode(p)), p);
  });

  test('Hintergrund: nur der eigene Eintrag wird ersetzt, Geschwister '
      'bleiben', () {
    final old = homeWidgetPayload(kids: [jonas(), lena()], now: tuesday, t: de);
    final later = DateTime(2026, 10, 27, 10, 0);
    final merged = mergeWidgetKid(
      old,
      account: 1,
      items: const [],
      stand: later,
      color: 3,
    )!;
    expect(merged.map((k) => k['name']), ['Jonas', 'Lena']);
    expect(merged[0]['items'], isEmpty);
    expect(merged[0]['stand'], later.toIso8601String());
    expect(merged[0]['color'], 3);
    // Aufgaben, Arbeit, Essen und Name bleiben aus der vorigen Datei.
    expect(merged[0]['hw'], 2);
    expect(merged[0]['exam'], isNotNull);
    expect(merged[0]['meal'], isNotNull);
    expect(merged[1], (old['kids']! as List)[1]);
    // Ohne Farbe bleibt die alte.
    expect(
      mergeWidgetKid(
        old,
        account: 2,
        items: const [],
        stand: later,
      )![1]['color'],
      1,
    );
    // Neu geschrieben stimmt die Summe wieder.
    expect(
      homeWidgetPayload(kids: merged, now: later, t: de)['hwTotal'],
      '5 Aufgaben',
    );
  });

  test('Hintergrund schreibt nichts ohne Datei, bei Version 1 oder fremdem '
      'Konto', () {
    final old = homeWidgetPayload(kids: [lena()], now: tuesday, t: de);
    expect(
      mergeWidgetKid(null, account: 2, items: const [], stand: tuesday),
      isNull,
    );
    expect(
      mergeWidgetKid(
        {'v': 1, 'account': 2, 'items': []},
        account: 2,
        items: const [],
        stand: tuesday,
      ),
      isNull,
    );
    expect(
      mergeWidgetKid(old, account: 9, items: const [], stand: tuesday),
      isNull,
    );
  });

  test('Auswahl: Vorgabe alle, neue Liste, alte Einzelwahl verfällt', () {
    expect(widgetKidSelectionFrom(), isNull);
    expect(widgetKidSelectionFrom(kids: '[2, 3]'), {2, 3});
    // Neue Einstellung geht vor der alten.
    expect(widgetKidSelectionFrom(kids: '[2]', legacy: '3'), {2});
    // Entwurf 4: die alte Einzelwahl gilt nicht mehr (alle Kinder).
    expect(widgetKidSelectionFrom(legacy: '3'), isNull);
    expect(widgetKidSelectionFrom(legacy: 'x'), isNull);
    // Leer oder kaputt: alle.
    expect(widgetKidSelectionFrom(kids: '[]', legacy: '3'), isNull);
    expect(widgetKidSelectionFrom(kids: '{kaputt'), isNull);
  });

  test('Einstellung: alte Einzelwahl verfällt, neue Wahl löscht sie', () {
    final store = <String, String>{};
    final shared = TypedSettings(
      read: (k) => store[k],
      write: (k, v) => store[k] = v!,
      delete: store.remove,
    );
    expect(widgetKidSelection(shared), isNull);
    shared.setString(widgetAccountSetting, '3');
    expect(widgetKidSelection(shared), isNull);
    storeWidgetKidSelection(shared, {4, 3});
    expect(widgetKidSelection(shared), {3, 4});
    expect(store.containsKey(widgetAccountSetting), isFalse);
    // „Alle“: beide Einträge weg, die alte Wahl kommt nicht zurück.
    shared.setString(widgetAccountSetting, '3');
    storeWidgetKidSelection(shared, null);
    expect(store, isEmpty);
    expect(widgetKidSelection(shared), isNull);
  });

  test('Gezeigte Konten in Familienreihenfolge; gelöschte zählen nicht', () {
    expect(widgetAccounts([1, 2, 4], null), [1, 2, 4]);
    expect(widgetAccounts([1, 2, 4], {4, 1}), [1, 4]);
    // Gewähltes Konto gelöscht: wieder alle statt eines leeren Widgets.
    expect(widgetAccounts([1, 2], {7}), [1, 2]);
  });

  test('Nächste Arbeit nur innerhalb von 7 Tagen', () {
    UpcomingExam at(int day) =>
        UpcomingExam(day: DateTime(2026, 11, day), subject: 'Bio', kind: '');
    expect(nextExamWithin([at(3)], tuesday)?.day.day, 3);
    expect(nextExamWithin([at(4)], tuesday), isNull);
  });
}

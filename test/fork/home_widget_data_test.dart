import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/l10n/l10n.dart';
import 'package:lanis/fork/ui/plan/plan_model.dart';
import 'package:lanis/fork/widget/home_widget_data.dart';
import 'package:lanis/fork/widget/home_widget_sync.dart'
    show storeWidgetKidSelection, widgetKidSelection;
import 'package:liblanis/liblanis.dart';

/// Startbildschirm-Widget (Entwurf 10, Abnahme 30.10.26): Tage je Kind
/// (tatsächlicher Zeitraum, Ausfälle mitten am Tag, Vertretung/Raum, freie
/// Tage), Datei Version 3, Zusammenführen im Hintergrund, Auswahl. Tagwahl,
/// Texte und Größen prüft der JVM-Test android/app/src/test/.../widget.
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

  final subs = [
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
      _sub('4', art: 'Entfall', fach: 'M', lehrer: 'CCC'),
    ]),
  ];

  List<Map<String, Object?>> days(
    List<SubstitutionDay> d,
    DateTime now, {
    Map<DateTime, String> free = const {},
  }) => widgetDays(
    plan: plan,
    choice: const {},
    days: d,
    now: now,
    t: de,
    free: free,
  );

  test('Tage: heute bis +7, ohne Wochenende', () {
    final r = days(subs, tuesday);
    expect(r.map((d) => d['date']), [
      '2026-10-27',
      '2026-10-28',
      '2026-10-29',
      '2026-10-30',
      '2026-11-02',
      '2026-11-03',
    ]);
  });

  test(
    'Ausfall am Ende: tatsächlicher Zeitraum kürzer, Vertretung und Raum',
    () {
      final d = days(subs, tuesday).first;
      expect(d['timed'], isTrue);
      expect([d['planStart'], d['planEnd']], ['08:00', '13:20']);
      expect([d['start'], d['end']], ['08:00', '11:30']);
      expect([d['startSlot'], d['endSlot']], ['1.', '4.']);
      expect(d['allOff'], isFalse);
      expect(d['mid'], isEmpty);
      expect(d['subs'], [
        {'slot': '3.', 'end': '10:40'},
      ]);
      expect(d['rooms'], [
        {'slot': '4.', 'end': '11:30', 'room': 'R310'},
      ]);
    },
  );

  test('Ausfall vorn und in der Mitte: ab der 3., Mitte 4.', () {
    final d = days(subs, tuesday)[1];
    expect([d['start'], d['end']], ['09:55', '13:20']);
    expect(d['startSlot'], '3.');
    expect(d['mid'], [
      {'slot': '4.', 'end': '11:30'},
    ]);
  });

  test('Alles fällt aus: allOff, kein Zeitraum', () {
    final d = days([
      _day('27.10.2026', [_sub('1 - 6', art: 'Entfall')]),
    ], tuesday).first;
    expect(d['allOff'], isTrue);
    expect(d.containsKey('start'), isFalse);
    expect(d['planStart'], '08:00');
  });

  test('Freie Tage: Text mit dem letzten freien Tag am Stück', () {
    final free = {
      for (var i = 28; i <= 31; i++) DateTime(2026, 10, i): 'Herbstferien',
      DateTime(2026, 11, 2): 'Herbstferien',
    };
    final r = days(const [], tuesday, free: free);
    expect(r[1], {'date': '2026-10-28', 'free': 'Herbstferien bis Mo. 2.11.'});
    expect(r.last['date'], '2026-11-03');
    expect(r.last.containsKey('free'), isFalse);
  });

  Map<String, Object?> jonas({DateTime? stand}) => widgetKidEntry(
    account: 1,
    name: ' Jonas ',
    color: 0,
    days: days(subs, tuesday),
    stand: stand ?? DateTime(2026, 10, 27, 7, 52),
    homeworkDue: [DateTime(2026, 10, 28), DateTime(2026, 10, 28)],
    exams: [DateTime(2026, 10, 29), DateTime(2026, 10, 29)],
    mealOpen: [DateTime(2026, 10, 28)],
  );
  Map<String, Object?> lena() => widgetKidEntry(
    account: 2,
    name: 'Lena',
    color: 1,
    days: const [],
    own: true,
    shown: false,
    lowBalance: true,
  );

  test('Datei Version 3: Kinder, Fristen, Texte für Kotlin', () {
    final p = homeWidgetPayload(kids: [jonas(), lena()], now: tuesday, t: de);
    expect(p['v'], 3);
    final kids = (p['kids'] as List).cast<Map<String, Object?>>();
    expect(kids.map((k) => k['name']), ['Jonas', 'Lena']);
    expect(kids.first['hwDue'], ['2026-10-28', '2026-10-28']);
    expect(kids.first['exams'], ['2026-10-29']);
    expect(kids.first['mealOpen'], ['2026-10-28']);
    expect(
      [kids[1]['own'], kids[1]['shown'], kids[1]['lowBalance']],
      [true, false, true],
    );
    final l = (p['labels'] as Map).cast<String, Object?>();
    expect(l['today'], 'HEUTE');
    expect((l['weekdaysLong'] as List).first, 'MONTAG');
    expect(l['from'], 'ab %s');
    expect(l['slot'], '%s Std.');
    expect(l['homeworkN'], ['1 Aufgabe', '%d Aufgaben']);
    expect(l['range'], r'%1$s–%2$s');
    expect(l['more'], '+%d nach Plan');
    // JSON-fähig (Kotlin liest JSONObject).
    expect(jsonDecode(jsonEncode(p))['v'], 3);
  });

  test('Hintergrund: nur Tage und Stand des eigenen Kindes', () {
    final old = homeWidgetPayload(kids: [jonas(), lena()], now: tuesday, t: de);
    final later = DateTime(2026, 10, 27, 10);
    final merged = mergeWidgetKid(
      old,
      account: 1,
      days: const [],
      stand: later,
      color: 3,
    )!;
    expect(merged.first['days'], isEmpty);
    expect(merged.first['stand'], later.toIso8601String());
    expect(merged.first['color'], 3);
    expect(merged.first['hwDue'], ['2026-10-28', '2026-10-28']);
    expect(merged[1], lena());
    // Keine Datei, alte Version, fremdes Konto: nichts.
    expect(
      mergeWidgetKid(null, account: 1, days: const [], stand: later),
      isNull,
    );
    expect(
      mergeWidgetKid(
        {...old, 'v': 2},
        account: 1,
        days: const [],
        stand: later,
      ),
      isNull,
    );
    expect(
      mergeWidgetKid(old, account: 9, days: const [], stand: later),
      isNull,
    );
  });

  test('Schreiben aus der App: der neuere Vertretungsplan gewinnt', () {
    final app = jonas();
    final old = mergeWidgetKid(
      homeWidgetPayload(kids: [app], now: tuesday, t: de),
      account: 1,
      days: const [],
      stand: DateTime(2026, 10, 27, 10),
      color: 3,
    )!.single;
    final kept = newerWidgetKid(app, old)!;
    expect(kept['stand'], '2026-10-27T10:00:00.000');
    expect(kept['days'], isEmpty);
    expect(kept['color'], 0);
    expect(kept['exams'], app['exams']);
    // App neuer: alles aus der App.
    final newer = jonas(stand: DateTime(2026, 10, 27, 11));
    expect(newerWidgetKid(newer, old), newer);
    expect(newerWidgetKid(null, old), old);
  });

  test('Abmelden: Kind fällt aus der Datei, ohne Kind wird sie gelöscht', () {
    final p = homeWidgetPayload(kids: [jonas(), lena()], now: tuesday, t: de);
    final rest = widgetKidsWithout(p, 1)!;
    expect(rest.map((k) => k['name']), ['Lena']);
    expect(widgetKidsWithout({...p, 'kids': rest}, 2), isEmpty);
    expect(widgetKidsWithout(p, 9), isNull);
    expect(widgetKidsWithout(null, 1), isNull);
    // Ältere Versionen: ganz löschen, wenn das Konto darin vorkommt.
    expect(widgetKidsWithout({'v': 1, 'account': 3}, 3), isEmpty);
    expect(
      widgetKidsWithout({
        'v': 2,
        'kids': [
          {'account': 4},
        ],
      }, 4),
      isEmpty,
    );
    expect(widgetKidsWithout({'v': 1, 'account': 3}, 1), isNull);
  });

  test('Stunde ohne Zusatz', () {
    expect(widgetSlotShort('1.–2. Std.'), '1.–2.');
    expect(widgetSlotShort('3. Block'), '3.');
    expect(widgetSlotShort('5 - 6'), '5-6.');
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
}

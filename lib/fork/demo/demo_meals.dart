import '../mensa_store.dart';
import '../mensa_week.dart';
import 'demo_pages.dart' show DemoClock;

/// Erfundener Caterer der Demo (Wunsch 27.10.26: „Demo mit neuen
/// Funktionen“): zwei Wochen Essen für „Essen“ und die Heute-Karte.
///
/// Ursache: Das Essen kommt nicht aus dem Schulportal, sondern von der
/// Seite eines Caterers; DemoPortal deckt nur das Portal ab. Statt eine
/// Caterer-Seite nachzubauen, liefert die Demo die gelesenen Wochen direkt
/// (MealCache.demo) – die Anzeige ist dieselbe wie mit echten Daten.
///
/// Inhalt (relativ zu heute, DemoClock):
/// - vergangene Tage bestellt, heute bestellt (abbestellbar bis 08:30),
/// - nächster Schultag offen mit zwei Gerichten → Hinweis „Kein Essen
///   bestellt“ auf Heute,
/// - ein Tag „Mensa geschlossen“, die übrigen bestellt,
/// - Guthaben 12,50 € → Hinweis „bitte Geld überweisen“.
/// Grenze: Bestellen, Abbestellen und die Seite des Caterers sind in der
/// Demo gesperrt (blockedInDemo).
const demoMensaUrl = 'https://essen.beispiel.example/kunden/essen/';

const _dishes = [
  ('Veggie', 'Linsencurry mit Reis'),
  ('Klassisch', 'Spaghetti mit Tomatensoße und Reibekäse'),
  ('Veggie', 'Gemüselasagne mit Salat'),
  ('Klassisch', 'Hähnchengeschnetzeltes mit Nudeln'),
  ('Veggie', 'Kartoffelpuffer mit Apfelmus'),
  ('Klassisch', 'Fischstäbchen mit Kartoffelpüree'),
  ('Veggie', 'Gnocchi auf Ratatouillegemüse'),
];

const _sides = [
  MealOption(line: 'Dessert', name: 'Apfel'),
  MealOption(line: 'Dessert', name: 'Joghurt'),
];

String _d2(int v) => v.toString().padLeft(2, '0');

String _until(DateTime d) =>
    '${_d2(d.day)}.${_d2(d.month)}.${_d2(d.year % 100)} 08:30';

MealWeek _week(DateTime monday, DateTime now, int offset) {
  final clock = DemoClock(now);
  final today = clock.today;
  final tomorrow = clock.schoolDay(1);
  final days = <MealDay>[];
  for (var i = 0; i < 5; i++) {
    final d = DateTime(monday.year, monday.month, monday.day + i);
    final (line, name) = _dishes[(i + offset) % _dishes.length];
    final dish = MealOption(line: line, name: name, price: '3,50 €');
    final isToday = d == today;
    if (d == tomorrow || (offset > 0 && i >= 2)) {
      days.add(
        MealDay(
          day: d,
          state: MealState.open,
          options: [
            MealOption(
              line: line,
              name: name,
              price: '3,50 €',
              orderable: true,
            ),
            MealOption(
              line: line == 'Veggie' ? 'Klassisch' : 'Veggie',
              name: _dishes[(i + offset + 3) % _dishes.length].$2,
              price: '3,50 €',
              orderable: true,
            ),
          ],
        ),
      );
    } else if (i == 2 && !isToday && offset == 0) {
      days.add(
        MealDay(day: d, state: MealState.closed, note: 'Mensa geschlossen'),
      );
    } else {
      final past = d.isBefore(today);
      final cancel =
          !past &&
          (!isToday || now.hour < 8 || (now.hour == 8 && now.minute < 30));
      days.add(
        MealDay(
          day: d,
          state: MealState.ordered,
          ordered: dish,
          options: [dish],
          sides: [_sides[i % _sides.length]],
          cancelUntil: past ? null : _until(d),
          canCancel: cancel,
        ),
      );
    }
  }
  final f = days.first.day, l = days.last.day;
  return MealWeek(
    label:
        '${_d2(f.day)}.${_d2(f.month)}. bis ${_d2(l.day)}.${_d2(l.month)}.${l.year}',
    days: days,
    balance: '12,50',
    url: demoMensaUrl,
    prev: offset == 0 ? null : '#prev',
    next: offset == 0 ? '#next' : null,
  );
}

/// Gelesener Stand des Demo-Caterers für [now] (laufende und nächste Woche).
MealEntry demoMealEntry(DateTime now) {
  final monday = DemoClock(now).monday;
  return MealEntry(
    at: now,
    balance: '12,50',
    weeks: [
      _week(monday, now, 0),
      _week(DateTime(monday.year, monday.month, monday.day + 7), now, 1),
    ],
  );
}

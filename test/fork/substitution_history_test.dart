import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/substitution_history.dart';
import 'package:liblanis/liblanis.dart';

/// Ablage vergangener Vertretungstage (substitution_history.dart) –
/// synthetisch.
void main() {
  SubstitutionDay day(String date, String fach) => SubstitutionDay(
    parsedDate: date,
    substitutions: [
      Substitution(
        tag: date,
        tag_en: '',
        stunde: '1',
        fach: fach,
        art: 'Vertretung',
        vertreter: 'ABC',
      ),
    ],
  );
  final now = DateTime(2026, 10, 21, 15, 17);

  test('gelieferte Tage ersetzen, vergangene bleiben, alte fallen weg', () {
    final h = SubstitutionHistory.empty
        .record([day('20.10.2026', 'D'), day('21.10.2026', 'M')], now)
        .record([day('21.10.2026', 'E'), day('22.10.2026', 'K')], now);
    expect(h.days.keys.toSet(), {'2026-10-20', '2026-10-21', '2026-10-22'});
    expect(h.days['2026-10-21']!.substitutions.single.fach, 'E');
    // Drei Wochen später: der 20.10. ist zu alt.
    final later = h.record(const [], DateTime(2026, 11, 12));
    expect(later.days.containsKey('2026-10-20'), isFalse);
  });

  test('künftiger Tag ohne Lieferung gilt als geleert', () {
    final h = SubstitutionHistory.empty
        .record([day('22.10.2026', 'K')], now)
        .record(const [], now);
    expect(h.days, isEmpty);
  });

  test('Kalender: gelieferte Tage plus gespeicherte bis heute', () {
    final h = SubstitutionHistory.empty.record([
      day('19.10.2026', 'D'),
      day('20.10.2026', 'M'),
    ], DateTime(2026, 10, 20, 8));
    final days = h.withPast([day('21.10.2026', 'E')], now);
    expect([for (final d in days) d.parsedDate]..sort(), [
      '19.10.2026',
      '20.10.2026',
      '21.10.2026',
    ]);
    // Liefert das Portal einen Tag, gilt dessen Stand.
    final again = h.withPast([day('20.10.2026', 'X')], now);
    expect(
      again
          .where((d) => d.parsedDate == '20.10.2026')
          .single
          .substitutions
          .single
          .fach,
      'X',
    );
  });

  test('Heute und Sammelmeldung: gespeicherter heutiger Tag, kein '
      'vergangener (Prüfung 27.10.26)', () {
    final h = SubstitutionHistory.empty.record([
      day('20.10.2026', 'D'),
      day('21.10.2026', 'M'),
    ], DateTime(2026, 10, 20, 8));
    // Nachmittags liefert das Portal den 21.10. nicht mehr.
    final days = h.fromToday([day('22.10.2026', 'E')], now);
    expect([for (final d in days) d.parsedDate]..sort(), [
      '21.10.2026',
      '22.10.2026',
    ]);
  });

  test('Speichern und Lesen; Unlesbares ergibt eine leere Ablage', () {
    final h = SubstitutionHistory.empty.record([day('20.10.2026', 'D')], now);
    final back = SubstitutionHistory.decode(h.encode());
    expect(back.days['2026-10-20']!.substitutions.single.vertreter, 'ABC');
    expect(SubstitutionHistory.decode('{kaputt').days, isEmpty);
    expect(SubstitutionHistory.decode(null).days, isEmpty);
  });
}

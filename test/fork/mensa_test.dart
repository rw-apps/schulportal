import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/mensa.dart';

void main() {
  test('ISO-Woche, auch am Jahreswechsel', () {
    expect(isoWeek(DateTime(2026, 10, 17)), (year: 2026, week: 42));
    expect(isoWeek(DateTime(2025, 12, 29)), (year: 2026, week: 1));
    expect(isoWeek(DateTime(2027, 1, 1)), (year: 2026, week: 53));
    expect(isoWeek(DateTime(2026, 1, 1)), (year: 2026, week: 1));
  });

  test('Bestellwoche: ab Freitag 12 Uhr die nächste', () {
    expect(mensaOrderWeek(DateTime(2026, 10, 14, 9)).week, 42); // Mi
    expect(mensaOrderWeek(DateTime(2026, 10, 16, 11)).week, 42); // Fr früh
    expect(mensaOrderWeek(DateTime(2026, 10, 16, 12)).week, 43); // Fr mittag
    expect(mensaOrderWeek(DateTime(2026, 10, 18, 20)).week, 43); // So
  });

  test('Woche in der Adresse ersetzen (Pfad und Rücksprung)', () {
    final now = DateTime(2026, 10, 14);
    expect(
      mensaWeekUrl(
        'https://bestellung.example.de/login/?next=/kunden/essen/2025/35/',
        now,
      ),
      'https://bestellung.example.de/login/?next=/kunden/essen/2026/42/',
    );
    expect(
      mensaWeekUrl(
        'https://bestellung.example.de/login/?next=%2Fkunden%2Fessen%2F2025%2F35%2F',
        now,
      ),
      'https://bestellung.example.de/login/?next=%2Fkunden%2Fessen%2F2026%2F42%2F',
    );
    expect(
      mensaWeekUrl('https://example.de/essen/2025/35', now),
      'https://example.de/essen/2026/42',
    );
    // Kein Wochenmuster: unverändert (auch nicht Jahr/Monat/Tag-Längen).
    expect(
      mensaWeekUrl('https://example.de/login/', now),
      'https://example.de/login/',
    );
    expect(
      mensaWeekUrl('https://example.de/a/2025/99/', now),
      'https://example.de/a/2025/99/',
    );
  });

  test('Adressen je Kind, alte Kontoadresse als Rückfall', () {
    var a = MensaAddresses.decode(null, legacy: 'bestellung.example.de');
    expect(a.of('k1'), 'https://bestellung.example.de');
    expect(a.ownFor('k1'), isFalse);
    a = a.withUrl('k2', 'other.example.org/login');
    expect(a.of('k2'), 'https://other.example.org/login');
    expect(a.of('k1'), 'https://bestellung.example.de');
    // Ungültig ändert nichts.
    expect(
      a.withUrl('k1', 'kein url').of('k1'),
      'https://bestellung.example.de',
    );
    final back = MensaAddresses.decode(a.encode(), legacy: a.legacy);
    expect(back.of('k2'), 'https://other.example.org/login');
    // Letzten Eintrag löschen verwirft auch die alte Adresse.
    final none = back.withUrl('k2', '');
    expect(none.of('k2'), isNull);
    expect(none.legacy, isNull);
    // Geerbte Adresse löschen: weg für alle, die sie erbten.
    final both = MensaAddresses.decode(
      '{"k2":"https://other.example.org"}',
      legacy: 'bestellung.example.de',
    ).withUrl('k1', null);
    expect(both.of('k1'), isNull);
    expect(both.of('k2'), 'https://other.example.org');
    // Kaputter Speicher = leer.
    expect(MensaAddresses.decode('{kaputt').byKid, isEmpty);
    // Fremde Schemata werden beim Lesen verworfen.
    expect(
      MensaAddresses.decode('{"k":"javascript:alert(1)"}').of('k'),
      isNull,
    );
  });

  test('eingebettete Seite: nur eigene Domain und https', () {
    final home = Uri.parse('https://bestellung.example.de/login/');
    expect(
      mensaAllows(home, Uri.parse('https://bestellung.example.de/x')),
      isTrue,
    );
    expect(mensaAllows(home, Uri.parse('https://www.example.de/')), isTrue);
    expect(
      mensaAllows(home, Uri.parse('http://bestellung.example.de/')),
      isFalse,
    );
    expect(mensaAllows(home, Uri.parse('https://pay.other.com/')), isFalse);
    expect(
      mensaAllows(home, Uri.parse('https://example.de.evil.com/')),
      isFalse,
    );
    expect(
      mensaAllows(home, Uri.parse('https://u:p@bestellung.example.de/')),
      isFalse,
    );
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:liblanis/liblanis.dart';

/// Platzhalter statt Hausaufgabe (Bildschirmfoto 28.10.26: „-“ erschien als
/// offene Hausaufgabe). Synthetische Texte.
void main() {
  test('Platzhalter: nur Zeichen ohne Buchstaben/Ziffern oder „keine …“', () {
    for (final p in [
      '-',
      ' – ',
      '—',
      '/',
      '.',
      '---',
      'keine',
      'Keine HA',
      'keine Hausaufgaben.',
      'nichts',
      'entfällt',
    ]) {
      expect(Homework.isPlaceholder(p), isTrue, reason: p);
    }
  });

  test('echte Aufgaben und leerer Text bleiben', () {
    for (final h in [
      '',
      'S. 52 Nr. 3',
      '1',
      'keine Fehler im Heft lassen',
      'Vokabeln lernen',
      'AB Teil C',
      '📖',
    ]) {
      expect(Homework.isPlaceholder(h), isFalse, reason: h);
    }
  });
}

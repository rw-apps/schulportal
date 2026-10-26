import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/anon/anonymizer.dart';

// Nur erfundene Namen (Sicherheitsregel: keine echten Daten im Repo).
const _plan = '''
<!DOCTYPE html><html><head><title>Vertretungsplan</title>
<script>var user = "Anna Beispiel";</script></head><body>
<!-- Kommentar mit Tim Muster -->
<div class="panel" data-tag="27.10.2026">
<table id="vtable_27_10_2026">
<tr><th>Stunde</th><th>Klasse</th><th>Vertreter</th><th>Fach</th><th>Raum</th><th>Hinweis</th></tr>
<tr><td>3 - 4</td><td>9c</td><td>Klein</td><td>Deutsch</td><td>R112</td><td>entfällt wegen Ausflug mit Frau Sommer</td></tr>
</table></div>
<a href="meinunterricht.php?a=sus_view&amp;id=4711&amp;p=Anna">Mappe</a>
<img src="data:image/png;base64,AAAA" alt="Foto Anna Beispiel">
</body></html>''';

const _grades = '''
<table class="table"><tr><th>Name</th><th>Note</th></tr>
<tr><td>Beispiel, Anna</td><td>2-</td></tr>
<tr><td>Muster, Tim</td><td>13</td></tr></table>''';

void main() {
  Anonymizer make() => Anonymizer(key: List.filled(32, 7), random: Random(1));

  test('Namen, Freitext, Bilder und Skripte verschwinden, Aufbau bleibt', () {
    final a = make();
    final out = a.html(_plan);
    for (final real in [
      'Anna',
      'Beispiel',
      'Tim',
      'Muster',
      'Sommer',
      'Ausflug',
      'AAAA',
    ]) {
      expect(out, isNot(contains(real)), reason: real);
    }
    // Beschriftungen, Kennungen, Daten und Zahlen bleiben.
    for (final keep in [
      '<th>Vertreter</th>',
      'id="vtable_27_10_2026"',
      'data-tag="27.10.2026"',
      '3 - 4',
      'entfällt',
      '<td>Deutsch</td>',
      'meinunterricht.php?a=sus_view',
    ]) {
      expect(out, contains(keep), reason: keep);
    }
    // „Klein“ steht in der Vertreter-Spalte: verwürfelt, obwohl ein Wort.
    expect(out, isNot(contains('>Klein<')));
    // Form bleibt: Ziffern und Länge.
    expect(RegExp(r'<td>9[a-z]</td>').hasMatch(out), isTrue);
    expect(RegExp(r'<td>[A-Z]112</td>').hasMatch(out), isTrue);
  });

  test('gleiche Wörter gleich verwürfelt, anderer Schlüssel anders', () {
    final a = make();
    expect(a.scramble('Anna'), a.scramble('Anna'));
    expect(a.scramble('Anna'), hasLength(4));
    expect(a.scramble('Anna'), isNot('Anna'));
    final b = Anonymizer(key: List.filled(32, 8));
    expect(b.scramble('Anna'), isNot(a.scramble('Anna')));
    // Gleiche Person in Name und Adresse:
    final out = a.html(_plan);
    expect(out, contains('p=${a.scramble('Anna')}'));
  });

  test('Noten in Notenspalten zufällig, Format bleibt', () {
    var changed = false;
    for (var seed = 0; seed < 5; seed++) {
      final a = Anonymizer(key: List.filled(32, 7), random: Random(seed));
      final out = a.html(_grades);
      expect(out, isNot(contains('Beispiel')));
      final cells = RegExp(
        r'<td>(\d{1,2}-?)</td>',
      ).allMatches(out).map((m) => m[1]!).toList();
      expect(cells, hasLength(2));
      expect(cells[0], endsWith('-'));
      if (cells[0] != '2-' || cells[1] != '13') changed = true;
    }
    expect(changed, isTrue);
  });

  test('JSON: Schlüssel bleiben, Namen und Titel verwürfelt', () {
    final a = make();
    final out = a.json(
      jsonEncode([
        {
          'title': 'Elternabend Klasse 9c',
          'Verantwortlich': 'Herr Sommer',
          'start': '2026-10-27 18:00:00',
          'allDay': false,
          'id': 12,
          'link': 'kalender.php?id=Anna',
        },
      ]),
    );
    final m = (jsonDecode(out) as List).single as Map;
    expect(
      m.keys,
      containsAll(['title', 'Verantwortlich', 'start', 'allDay', 'id']),
    );
    expect(m['start'], '2026-10-27 18:00:00');
    expect(m['allDay'], false);
    expect(m['title'], startsWith(a.scramble('Elternabend')));
    expect(m['title'], contains('Klasse'));
    expect(m['Verantwortlich'], isNot(contains('Herr')));
    expect(m['link'], 'kalender.php?id=${a.scramble('Anna')}');
  });

  test('Schulnummer verschwindet auch aus Pfaden und Zahlen', () {
    final a = Anonymizer(secretNumbers: ['9999']);
    final out = a.html(
      '<img src="img/schullogo/9999/ab12.png"><span class="hidden">9999</span>'
      '<a href="vertretungsplan.php?i=9999">x</a>',
    );
    expect(out, isNot(contains('9999')));
    expect(out, contains('vertretungsplan.php?i=0000'));
    expect(a.json('{"school": 9999, "n": 12}'), isNot(contains('9999')));
  });

  test('stehen gebliebene Wörter werden gesammelt', () {
    final a = make()..html(_plan);
    expect(a.kept, containsAll(['vertreter', 'entfällt']));
    expect(a.kept, isNot(contains('anna')));
  });
}

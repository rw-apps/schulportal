import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart';
import 'package:lanis/fork/lessons_parent.dart';

/// Nachbildung der Eltern-Seite von meinunterricht.php: Aufbau wie im Export
/// von Schule A (16.10.26), alle Namen, IDs und Texte erfunden.
/// Zwei Kinder, damit die Trennung je `pupilbox` geprüft ist.
String _box(String id, String name, String kurs, String kursId) => '''
<div class="pupilbox">
  <h2 data-pupil="$id">$name</h2>
  <ul class="nav nav-tabs">
    <li><a href="#aktuell$id">Aktuelle Einträge</a></li>
    <li><a href="#mappen$id">Kursmappen</a></li>
    <li><a href="#anwesend$id">Anwesenheiten</a></li>
  </ul>
  <div class="tab-content">
    <div id="aktuell$id"><table><tbody>
      <tr data-entry="5" data-book="99" class="printable">
        <td><h3><a href="meinunterricht.php?a=sus_view&id=$kursId&p=$id"><span class="name">$kurs</span></a></h3>
          <span class="teacher"><div class="btn-group"><button class="btn btn-primary dropdown-toggle btn-xs" title="Muster, Max (MUS)">MUS</button></div></span>
        </td>
        <td><span class="datum">29.09.2026</span><b class="thema">Bruchrechnung</b>
          <span class="homework"><span class="realHomework">S. 12 Nr. 3</span><span class="undone"></span></span>
        </td>
      </tr>
    </tbody></table></div>
    <div id="mappen$id"><div class="row">
      <div class="col-md-4"><div class="thumbnail"><div class="caption">
        <h2><span title="$kurs">$kurs</span></h2>
        <div class="btn-group"><button class="btn btn-primary dropdown-toggle btn-md" title="Muster, Max (MUS)">MUS</button></div>
        <a class="btn btn-primary" href="meinunterricht.php?a=sus_view&id=$kursId&p=$id">öffnen</a>
      </div></div></div>
    </div></div>
    <div id="anwesend$id"><table>
      <thead><tr><th>Kurs</th><th>Lehrkraft</th><th>anwesend</th><th>fehlend</th></tr></thead>
      <tbody><tr><td><a href="meinunterricht.php?a=sus_view&id=$kursId&p=$id">$kurs</a></td><td>MUS</td><td>12</td><td></td></tr></tbody>
    </table></div>
  </div>
</div>''';

void main() {
  final doc = parse(
    '<html><body>${_box('100', 'Beispiel, Anna', 'Mathematik 6a', '501')}'
    '${_box('200', 'Beispiel, Ben', 'Englisch 8b', '777')}</body></html>',
  );

  test('je Kind ein Block mit Kursen, Einträgen und Anwesenheiten', () {
    final kids = parseParentLessons(doc);
    expect(kids.map((k) => k.pupilId), ['100', '200']);
    expect(kids.first.firstName, 'Anna');

    final mathe = kids.first.lessons.single;
    expect(mathe.name, 'Mathematik 6a');
    expect(mathe.courseID, '501&p=100', reason: 'Kind gehört in die Kursroute');
    expect(mathe.courseURL.queryParameters['p'], '100');
    expect(mathe.teachers.single.teacherKuerzel, 'MUS');
    expect(mathe.teachers.single.teacher, 'Muster, Max');

    final entry = mathe.currentEntry!;
    expect(entry.topicDate, DateTime(2026, 9, 29));
    expect(entry.topicTitle, 'Bruchrechnung');
    expect(entry.homework!.description, 'S. 12 Nr. 3');
    expect(entry.homework!.homeWorkDone, isFalse);

    expect(mathe.attendances, {'anwesend': '12', 'fehlend': '0'});
  });

  test('Kurse bleiben beim richtigen Kind', () {
    final kids = parseParentLessons(doc);
    expect(kids[1].lessons.single.name, 'Englisch 8b');
    expect(kids[1].lessons.single.courseID, '777&p=200');
  });

  test('Schülerseite (ohne pupilbox) ergibt keine Kinder', () {
    expect(parseParentLessons(parse('<div id="mappen"></div>')), isEmpty);
  });

  test('flatten: bei mehreren Kindern Vorname vor dem Kurs', () {
    final all = flattenChildLessons(parseParentLessons(doc));
    expect(all.map((l) => l.name), containsAll(['Anna: Mathematik 6a', 'Ben: Englisch 8b']));
  });

  test('flatten: ein Kind ohne Vorsilbe', () {
    final one = parse('<html><body>${_box('100', 'Beispiel, Anna', 'Mathematik 6a', '501')}</body></html>');
    expect(flattenChildLessons(parseParentLessons(one)).single.name, 'Mathematik 6a');
  });
}

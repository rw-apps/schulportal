import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart';
import 'package:lanis/fork/absence/absence_form.dart';

/// Nachbildung von abwesenheitsmeldung.php (Elternkonto): Aufbau wie im
/// Export von Schule A (16.10.26), Namen und IDs erfunden.
/// Zweites Kind gesperrt, um `allowed` zu prüfen.
const _html = '''
<html><body><div id="content">
<div class="alert alert-info">Die Meldung kann nur erfolgen:
  <ul><li>spätestens bis 12:00 des aktuellen Tages</li>
      <li>maximal für die nächsten 5 Tage</li></ul></div>
<form id="meldungForm" action="abwesenheitsmeldung.php" method="post">
  <button type="button" class="btn btn-success btn-block pupil-select-btn"
    data-pupil-id="111" data-pupil-name="Anna Beispiel" data-preselected="true">Anna Beispiel</button>
  <button type="button" class="btn btn-default btn-block pupil-select-btn disabled"
    data-pupil-id="222" data-pupil-name="Ben Beispiel" disabled>Ben Beispiel</button>
  <input type="hidden" name="selectedPupils" id="selectedPupils" value="">
  <select id="inputArt" name="art">
    <option value="krank">als abwesend melden</option>
    <option value="verspätet">als verspätet melden</option>
  </select>
  <input type="text" name="von" value="16.10.2026">
  <input type="text" name="bis" value="16.10.2026">
  <select name="stundenVon">
    <option value="0" data-von="08:00:00" data-bis="08:45:00">0. Block (08:00
       -08:45) </option>
    <option value="1" data-von="09:00:00" data-bis="10:15:00">1.Block (09:00 -10:15) </option>
    <option value="2" data-von="10:30:00" data-bis="11:45:00">2.Block (10:30 -11:45) </option>
  </select>
  <select name="stundenBis">
    <option value="0">0. Block (08:00 -08:45) </option>
    <option value="1">1.Block (09:00 -10:15) </option>
    <option value="2">2.Block (10:30 -11:45) </option>
  </select>
  <input type="text" name="kommentar" value="">
  <button type="submit" name="save" value="1">Speichern</button>
</form></div>
<script> function datevonSet(date) { \$(".datepickergroupvon .input-group.date").datepicker("setDate", date); }
 \$(function() { const \$element = \$('.datepickergroupvon .input-group.date');
 \$element.datepicker({ startDate: "16.10.2026", endDate: "19.10.2026", autoclose: true }); }); </script>
<script> function datebisSet(date) { \$(".datepickergroupbis .input-group.date").datepicker("setDate", date); }
 \$(function() { const \$element = \$('.datepickergroupbis .input-group.date');
 \$element.datepicker({ startDate: "16.10.2026", endDate: "22.10.2026", autoclose: true }); }); </script>
</body></html>
''';

void main() {
  final form = parseAbsenceForm(parse(_html))!;

  AbsenceDraft draft({
    List<String> pupils = const ['111'],
    String kind = 'krank',
    DateTime? from,
    DateTime? to,
    String bf = '1',
    String bt = '2',
  }) => AbsenceDraft(
    pupilIds: pupils,
    kind: kind,
    from: from ?? DateTime(2026, 10, 16),
    to: to ?? DateTime(2026, 10, 16),
    blockFrom: bf,
    blockTo: bt,
    comment: '',
  );

  test('Kinder mit Vorauswahl und Sperre', () {
    expect(form.pupils.map((p) => p.id), ['111', '222']);
    expect(form.pupils.first.preselected, isTrue);
    expect(form.pupils.first.firstName, 'Anna');
    expect(form.allowedPupils.map((p) => p.id), ['111']);
  });

  test('Art und Blöcke mit Uhrzeiten', () {
    expect(form.kinds.map((k) => k.value), ['krank', 'verspätet']);
    expect(form.kinds.first.label, 'als abwesend melden');
    expect(form.blocks.map((b) => b.label), ['0. Block', '1. Block', '2. Block']);
    expect(form.blocks[1].start, '09:00');
    expect(form.blocks[1].end, '10:15');
  });

  test('Datumsgrenzen aus dem Datepicker des Portals', () {
    expect(form.fromRange!.first, DateTime(2026, 10, 16));
    expect(form.fromRange!.last, DateTime(2026, 10, 19));
    expect(form.toRange!.last, DateTime(2026, 10, 22));
    expect(form.defaultFrom, DateTime(2026, 10, 16));
    expect(form.rules, hasLength(2));
  });

  test('zulässige Meldung ergibt die Portal-Felder', () {
    final d = draft(to: DateTime(2026, 10, 20));
    expect(validateAbsenceDraft(form, d), isEmpty);
    expect(d.toFields(), {
      'selectedPupils': '111',
      'art': 'krank',
      'von': '16.10.2026',
      'bis': '20.10.2026',
      'stundenVon': '1',
      'stundenBis': '2',
      'kommentar': '',
      'save': '1',
    });
  });

  test('Grenzen und Fehler', () {
    expect(validateAbsenceDraft(form, draft(pupils: [])), isNotEmpty);
    expect(validateAbsenceDraft(form, draft(pupils: ['222'])), isNotEmpty);
    expect(
      validateAbsenceDraft(form, draft(from: DateTime(2026, 10, 20), to: DateTime(2026, 10, 20))),
      contains(startsWith('Beginn nur')),
    );
    expect(
      validateAbsenceDraft(form, draft(to: DateTime(2026, 10, 23))),
      contains(startsWith('Ende nur')),
    );
    expect(
      validateAbsenceDraft(form, draft(from: DateTime(2026, 10, 19), to: DateTime(2026, 10, 16))),
      contains('Das Ende liegt vor dem Beginn.'),
    );
    expect(validateAbsenceDraft(form, draft(bf: '2', bt: '1')), isNotEmpty);
    // Mehrtägig: letzter Block darf vor dem ersten liegen (anderer Tag).
    expect(
      validateAbsenceDraft(form, draft(to: DateTime(2026, 10, 19), bf: '2', bt: '0')),
      isEmpty,
    );
  });

  test('ohne Formular (Sitzung verloren) null', () {
    expect(parseAbsenceForm(parse('<html><body>Login</body></html>')), isNull);
  });
}

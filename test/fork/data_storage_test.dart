import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/data_storage.dart';

// Aufbau wie dateispeicher.php (Startordner, Export Schule B 17.10.26),
// Namen erfunden.
const _home = '''
<div id="content"><div class="row"><div class="col-md-9"><div class="row">
<div class="col-md-4"><div class="thumbnail folder" data-id="6" data-name="Formulare">
 <div class="caption"><h3><a href="#" data-dir="6">Formulare</a></h3></div>
 <p class="desc"><small> Für Eltern </small></p>
 <p><small><span style="visibility:hidden" class="label label-info">Keine Dateien</span></small></p>
</div></div>
<div class="col-md-4"><div class="thumbnail folder" data-id="2" data-name="Elternbriefe">
 <div class="caption"><h3><a href="#" data-dir="2">Elternbriefe</a></h3></div>
 <p class="desc"><small></small></p>
 <p><small><span class="label label-info">3 Dateien</span></small></p>
</div></div>
</div></div>
<div class="col-md-3"><div class="thumbnail"><div class="caption"><h4>Neue Dateien</h4></div>
<p><table class="table"><tbody>
<tr data-id="111" data-ext="pdf" data-name="Brief-Herbst.pdf"><td class="download new_download"><i></i></td><td class="download new_download"> Brief-Herbst.pdf <br/><small></small></td></tr>
<tr data-id="222" data-ext="docx" data-name="Anmeldung.docx"><td class="download new_download"><i></i></td><td class="download new_download"> Anmeldung.docx <br/><small>bis Freitag</small></td></tr>
</tbody></table></p></div></div></div></div>
''';

const _folder = '''
<table id="files"><thead><tr><th></th><th>Name</th><th>Änderung</th><th>Größe</th></tr></thead>
<tbody>
<tr data-id="333"><td><i></i></td><td>Elternbrief 1.pdf <small>Bitte lesen</small></td><td>12.10.2026 16:51:07</td><td>120 KB</td></tr>
</tbody></table>
''';

void main() {
  test('Startordner: Ordner und neue Dateien', () {
    final v = parseStorage(_home);
    expect(v.folders.map((f) => f.name), ['Formulare', 'Elternbriefe']);
    expect(v.folders.first.files, isNull);
    expect(v.folders.last.files, 3);
    expect(v.folders.first.desc, 'Für Eltern');
    expect(v.newFiles.map((f) => f.id), [111, 222]);
    expect(v.newFiles.last.note, 'bis Freitag');
    expect(v.newFiles.first.extension, 'pdf');
    expect(v.files, isEmpty);
  });

  test('Ordner mit Dateien', () {
    final v = parseStorage(_folder);
    expect(v.files.single.name, 'Elternbrief 1.pdf');
    expect(v.files.single.note, 'Bitte lesen');
    expect(v.files.single.changedDay, '12.10.2026');
    expect(v.files.single.size, '120 KB');
    expect(v.files.single.url, endsWith('a=download&f=333'));
  });

  test('fehlende Spalten stürzen nicht ab', () {
    final v = parseStorage(
      '<table id="files"><thead><tr><th>Datei</th></tr></thead>'
      '<tbody><tr data-id="5" data-name="x.pdf"><td>x.pdf</td></tr></tbody></table>',
    );
    expect(v.files.single.name, 'x.pdf');
    expect(v.files.single.size, '');
  });

  test('Meldung: erster Blick still, danach nur Neues', () {
    final v = parseStorage(_home);
    expect(unseenFiles(v, null), isEmpty);
    expect(unseenFiles(v, {111}).map((f) => f.id), [222]);
    expect(decodeSeen(encodeSeen({222, 111})), {111, 222});
    expect(decodeSeen('kaputt'), isEmpty);
  });

  test('App-Liste', () {
    expect(
      offersStorage([
        {'link': 'dateispeicher.php'},
      ]),
      isTrue,
    );
    expect(
      offersStorage([
        {'link': 'kalender.php'},
      ]),
      isFalse,
    );
  });
}

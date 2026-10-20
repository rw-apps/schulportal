import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/portal_extras.dart';

// Aufbau wie wahl.php und benutzerverwaltung.php?a=userFoto (Export Schule B
// 20.10.26), Inhalte gekürzt, Kennungen erfunden.
const _closed =
    '''<div id="content"><h1>Wahltool</h1><h2>Aktive Veranstaltungen</h2>
<div class="alert alert-info">Es sind derzeit keine passenden Veranstaltungen aktiv.</div></div>''';
const _open =
    '''<div id="content"><h1>Wahltool</h1><h2>Aktive Veranstaltungen</h2>
<table><tr><td><a href="wahl.php?a=v&id=3">AG-Wahl 2. Halbjahr</a></td></tr></table></div>''';
const _photo = '''<div class="currentUserFotoSection"><h2>Aktuelles Bild</h2>
<img src="benutzerverwaltung.php?a=userFoto&p=123&t=l&b=show" class="img-responsive userFoto_preview"></div>''';

void main() {
  test('Wahltool: offen, leer, fremde Seite', () {
    expect(electionOpen(_closed), isFalse);
    expect(electionOpen(_open), isTrue);
    expect(electionOpen('<p>Bitte melden Sie sich an</p>'), isFalse);
  });

  test('Fotoadresse', () {
    expect(
      photoUrlFrom(_photo),
      'https://start.schulportal.hessen.de/benutzerverwaltung.php?a=userFoto&p=123&t=l&b=show',
    );
    expect(photoUrlFrom('<h2>Aktuelles Bild</h2>'), isNull);
  });

  test('Module in der App-Liste', () {
    expect(
      offersModule([
        {'link': 'wahl.php'},
      ], electionModule),
      isTrue,
    );
    expect(offersModule(const [], electionModule), isFalse);
  });

  testWidgets('Platzhalter (grau) erkannt, farbiges Bild nicht', (t) async {
    Future<Uint8List> png(Color a, Color b) async {
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      c.drawRect(const Rect.fromLTWH(0, 0, 40, 40), Paint()..color = a);
      c.drawCircle(const Offset(20, 16), 9, Paint()..color = b);
      final img = await rec.endRecording().toImage(40, 40);
      final d = await img.toByteData(format: ui.ImageByteFormat.png);
      return d!.buffer.asUint8List();
    }

    await t.runAsync(() async {
      final grey = await png(const Color(0xFFE0E0E0), const Color(0xFF9E9E9E));
      final photo = await png(const Color(0xFFC4D6E8), const Color(0xFFF0CDB4));
      expect(await looksLikePlaceholder(grey), isTrue);
      expect(await looksLikePlaceholder(photo), isFalse);
    });
  });
}

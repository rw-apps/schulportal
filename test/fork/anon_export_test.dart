import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/fork/anon/anon_export.dart';
import 'package:lanis/view/settings/subsettings/debug_export_presets.dart';

/// Erfundenes Portal: antwortet je Pfad mit synthetischen Seiten und merkt
/// sich alle Abrufe.
class _FakePortal implements HttpClientAdapter {
  final calls = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add('${o.method} ${o.uri.path}?${o.uri.query}');
    final path = o.uri.path;
    final (String body, String type) = switch (path) {
      '/vertretungsplan.php' when o.method == 'GET' => (
        '<html><body><div data-tag="27.10.2026"></div>'
            '<p>Schule 9999 · Frau Sommer</p></body></html>',
        'text/html',
      ),
      '/vertretungsplan.php' => (
        '<table><tr><th>Vertreter</th></tr><tr><td>Tim Muster</td></tr></table>',
        'text/html',
      ),
      '/kalender.php' when o.method == 'POST' => (
        jsonEncode([
          {'title': 'Elternabend', 'Verantwortlich': 'Herr Sommer'},
        ]),
        'application/json',
      ),
      _ => ('<html><body><h1>Anna Beispiel</h1></body></html>', 'text/html'),
    };
    return ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: [type],
        'set-cookie': ['sid=GEHEIM; i=9999'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('Lehrkraft: nur lesende Seiten, alles anonym, nichts doppelt', () async {
    final portal = _FakePortal();
    final dio = Dio()..httpClientAdapter = portal;
    final r = await runAnonExport(
      dio: dio,
      type: AccountType.teacher,
      schoolId: 9999,
      travelMenu: const [],
      version: '4.1.0+1',
      now: DateTime(2026, 10, 26),
    );
    for (final real in [
      'Anna',
      'Beispiel',
      'Sommer',
      'Muster',
      'Elternabend',
      '9999',
      'GEHEIM',
      'sid=',
    ]) {
      expect(r.text, isNot(contains(real)), reason: real);
    }
    expect(r.text, contains('Konto: Lehrkraft'));
    expect(r.text, contains('<th>Vertreter</th>'));
    expect(r.text, contains('=== substitutionsAjax@27.10.2026'));
    // Lehrkraft: Übersicht ja, Schülerkursseiten und Nachrichten nein.
    expect(portal.calls.where((c) => c.contains('meinunterricht.php')), [
      'GET /meinunterricht.php?jump=no',
    ]);
    expect(portal.calls.any((c) => c.contains('nachrichten')), isFalse);
    // Vertretungsplan nur einmal abgerufen, obwohl zwei Abschnitte ihn
    // brauchen.
    expect(
      portal.calls.where((c) => c == 'GET /vertretungsplan.php?'),
      hasLength(1),
    );
    expect(r.kept, contains('vertreter'));
  });

  test('Schülerkonto: Kursseiten aus der Übersicht', () {
    expect(
      anonPresetsFor(AccountType.student),
      contains(DebugExportPresetId.lessonsCourseDetail),
    );
    expect(
      anonPresetsFor(AccountType.teacher),
      isNot(contains(DebugExportPresetId.lessonsCourseDetail)),
    );
  });
}

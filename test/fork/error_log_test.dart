import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/error_log.dart';
import 'package:lanis/fork/l10n/l10n.dart';
import 'package:lanis/fork/school_links.dart';
import 'package:lanis/fork/ui/settings/error_report_page.dart';

void main() {
  test('Protokoll: keine Fehlermeldung, Doppelte gezählt, gespeichert', () {
    final dir = Directory.systemTemp.createTempSync('errlog');
    addTearDown(() => dir.deleteSync(recursive: true));
    final f = File('${dir.path}/e.json');
    final log = ErrorLog.instance
      ..clear()
      ..version = '4.1.0+1'
      ..attach(f);
    StackTrace st;
    try {
      throw const FormatException('Anna Beispiel, Note 2');
    } catch (_, s) {
      st = s;
    }
    final e = const FormatException('Anna Beispiel, Note 2');
    log.record('meinunterricht.php', e, st);
    log.record('meinunterricht.php', e, st);
    expect(log.records, hasLength(1));
    expect(log.records.single.count, 2);
    expect(log.records.single.type, 'FormatException');
    final text = log.report(os: 'android');
    expect(text, isNot(contains('Anna')));
    expect(text, isNot(contains('Note 2')));
    expect(f.readAsStringSync(), isNot(contains('Anna')));
    expect(text, contains('meinunterricht.php'));
    // Neu laden aus der Datei.
    log
      ..clear()
      ..attach(f);
    expect(log.records, isEmpty, reason: 'clear schreibt die Datei leer');
    for (var i = 0; i < 30; i++) {
      log.record('a$i', StateError('x'), null);
    }
    expect(log.records, hasLength(ErrorLog.maxRecords));
    log.clear();
  });

  test('Stapel: nur Rahmen und Kopfzeilen', () {
    final st = StackTrace.fromString(
      '*** *** ***\npid: 1, tid: 2, name 1.ui\nos: android arch: arm64\n'
      "build_id: 'abc'\nisolate_dso_base: 7a, vm_dso_base: 7a\n"
      '#00 abs 0000007a virt 00000000 _kDartIsolateSnapshotInstructions+0x1\n'
      '<asynchronous suspension>\nirgendwas mit Anna\n',
    );
    expect(safeStack(st), [
      'os: android arch: arm64',
      "build_id: 'abc'",
      'isolate_dso_base: 7a, vm_dso_base: 7a',
      '#00 abs 0000007a virt 00000000 _kDartIsolateSnapshotInstructions+0x1',
    ]);
  });

  test('Zwischenspeicher: alte Dateien weg, neue bleiben', () {
    final dir = Directory.systemTemp.createTempSync('cache');
    addTearDown(() => dir.deleteSync(recursive: true));
    final now = DateTime(2026, 10, 17);
    final old = File('${dir.path}/kurs/alt.pdf')..createSync(recursive: true);
    old.setLastModifiedSync(now.subtract(const Duration(days: 40)));
    final fresh = File('${dir.path}/neu.pdf')..createSync();
    fresh.setLastModifiedSync(now.subtract(const Duration(days: 2)));
    expect(pruneOldFiles(dir, now: now), 1);
    expect(old.existsSync(), isFalse);
    expect(Directory('${dir.path}/kurs').existsSync(), isFalse);
    expect(fresh.existsSync(), isTrue);
    expect(pruneOldFiles(Directory('${dir.path}/fehlt')), 0);
  });

  test('Mensa-Vorschlag aus der App-Liste', () {
    expect(
      mensaSuggestion([
        {'Name': 'Moodle', 'link': 'https://mo1.schulportal.hessen.de'},
        {'Name': 'Interessen-AG', 'link': 'https://ag.example.de'},
        {
          'Name': 'Mittagessen bestellen',
          'link': 'https://bestellung.example.de/login/',
        },
      ]),
      'https://bestellung.example.de/login/',
    );
    expect(
      mensaSuggestion([
        {'Name': 'Mensa', 'link': 'https://start.schulportal.hessen.de/x.php'},
        {'Name': 'Mensa', 'link': 'mensa.php'},
      ]),
      isNull,
    );
    expect(mensaSuggestion(const []), isNull);
  });

  testWidgets('Fehlerseite zeigt den Bericht, ohne Überlauf', (t) async {
    ErrorLog.instance
      ..clear()
      ..record('vertretungsplan.php', StateError('x'), StackTrace.current);
    for (final lang in ['de', 'tr']) {
      await t.pumpWidget(
        MaterialApp(
          localizationsDelegates: ForkL10n.localizationsDelegates,
          supportedLocales: ForkL10n.supportedLocales,
          locale: Locale(lang),
          home: const ErrorReportPage(),
        ),
      );
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.textContaining('vertretungsplan.php'), findsOneWidget);
    }
    ErrorLog.instance.clear();
  });
}

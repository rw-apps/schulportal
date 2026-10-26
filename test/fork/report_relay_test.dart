import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/fork/anon/anon_export.dart';
import 'package:lanis/fork/error_log.dart';
import 'package:lanis/fork/l10n/l10n.dart';
import 'package:lanis/fork/report_relay.dart';
import 'package:lanis/fork/ui/live/page_report.dart';
import 'package:lanis/fork/ui/today/auto_report_prompt.dart';
import 'package:lanis/view/settings/subsettings/debug_export_presets.dart';

import '../helpers/test_app.dart';

TypedSettings _mem() {
  final m = <String, String?>{};
  return TypedSettings(
    read: (k) => m[k],
    write: (k, v) => m[k] = v,
    delete: m.remove,
  );
}

void main() {
  tearDown(() {
    ErrorLog.instance.clear();
    LanisClient.reset();
  });

  group('flushErrorReports', () {
    late List<String> sent;
    Future<bool> send({
      required String kind,
      required String version,
      required String area,
      required String text,
    }) async {
      sent.add('$kind|$area');
      return true;
    }

    setUp(() {
      sent = [];
      ErrorLog.instance
        ..clear()
        ..version = '4.1.0+1';
    });

    test('ohne Zustimmung nichts', () async {
      ErrorLog.instance.record(
        'stundenplan.php',
        UnknownException('x'),
        StackTrace.empty,
      );
      final s = _mem();
      expect(await flushErrorReports(s, os: 'test', send: send), isFalse);
      s.setBool(autoReportKey, false);
      expect(await flushErrorReports(s, os: 'test', send: send), isFalse);
      expect(sent, isEmpty);
    });

    test('mit Zustimmung: einmal je neuem Stand', () async {
      final s = _mem()..setBool(autoReportKey, true);
      ErrorLog.instance.record(
        'stundenplan.php',
        UnknownException('x'),
        StackTrace.empty,
      );
      expect(await flushErrorReports(s, os: 'test', send: send), isTrue);
      expect(await flushErrorReports(s, os: 'test', send: send), isFalse);
      // Gleicher Fehler erneut → Anzahl steigt → wieder melden.
      ErrorLog.instance.record(
        'stundenplan.php',
        UnknownException('x'),
        StackTrace.empty,
      );
      expect(await flushErrorReports(s, os: 'test', send: send), isTrue);
      expect(sent, [
        'fehler|stundenplan.php · UnknownException',
        'fehler|stundenplan.php · UnknownException',
      ]);
    });
  });

  test('ohne Dienst keine Frage auf Heute', () {
    ErrorLog.instance.record('x', UnknownException('x'), StackTrace.empty);
    expect(relayConfigured, isFalse);
    expect(autoReportPromptDue(_mem()), isFalse);
  });

  test('Seiten zum Senden: Lehrkraft eigene Übersicht, Nachrichten nie', () {
    expect(
      pageRequestFor('meinunterricht.php', AccountType.teacher)!.url,
      endsWith('meinunterricht.php?jump=no'),
    );
    expect(
      pageRequestFor('meinunterricht.php', AccountType.parent)!.url,
      endsWith('/meinunterricht.php'),
    );
    expect(pageRequestFor('nachrichten.php', AccountType.student), isNull);
  });

  testWidgets('Blatt zeigt stehen gebliebene Wörter und Senden', (
    tester,
  ) async {
    await pumpTestApp(
      tester,
      child: const Scaffold(
        body: PageReportSheet(
          session: null,
          phpUrl: 'meinunterricht.php',
          request: DebugExportHttpRequest(
            method: 'GET',
            url: '$sphBase/meinunterricht.php',
          ),
          initial: AnonExport(text: 'x', kept: ['kurs', 'thema']),
        ),
      ),
    );
    final t = tester.element(find.byType(PageReportSheet)).t;
    expect(find.text(t.pageReportTitle), findsOneWidget);
    expect(find.text('kurs, thema'), findsOneWidget);
    expect(find.text(t.pageReportSend), findsOneWidget);
  });
}

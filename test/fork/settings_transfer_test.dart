import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/ui/settings/transfer_page.dart';
import 'package:lanis/fork/absences.dart';
import 'package:lanis/fork/homework_ledger.dart';
import 'package:lanis/fork/settings_transfer.dart';
import 'package:liblanis/liblanis.dart';

import '../helpers/test_app.dart';

// Erfundene Konten und Werte.
String enc(String s) => LanisDatabase.encodeValue(s);
String? dec(String raw) => LanisDatabase.decodeValue(raw)?.toString();

void main() {
  final now = DateTime(2026, 10, 18, 12);

  test('Datei: nur bekannte Schlüssel, Konto über Schule und Name', () {
    expect(transferAccountKey(1234, ' Max.Muster '), '1234:max.muster');
    final text = buildTransfer({
      '1234:max.muster': {
        'stundenplan.php/fork-lesson-times': enc('{"start":"08:00"}'),
        'fork/fork-mensa-urls': null,
        'geheim/passwort': enc('x'),
      },
    }, now: now);
    expect(text, isNot(contains('passwort')));
    final back = parseTransfer(text)!;
    expect(back.keys, ['1234:max.muster']);
    expect(back['1234:max.muster']!.keys, [
      'stundenplan.php/fork-lesson-times',
    ]);
    expect(parseTransfer('{"format":"anderes"}'), isNull);
    expect(parseTransfer('kein json'), isNull);
    // Eine manipulierte Datei schreibt keine fremden Schlüssel.
    expect(
      parseTransfer(
        '{"format":"schulportal-eingaben","accounts":{"1:a":{"x/y":"1"}}}',
      )!['1:a'],
      isEmpty,
    );
  });

  test('Übernehmen: Haken zusammenführen, Rest ersetzen', () {
    HomeworkItem h(String e) =>
        HomeworkItem(course: 'm', entry: e, subject: 'M', text: e);
    final here = HomeworkLedger.empty
        .put(h('1').record(done: now, now: now), now)
        .put(h('2').record(done: now, now: now), now);
    final later = now.add(const Duration(hours: 1));
    final there = HomeworkLedger.empty
        .put(h('2').record(now: later), later) // dort wieder geöffnet, neuer
        .put(h('3').record(done: later, now: later), later);
    final merged = HomeworkLedger.decode(
      dec(
        mergeValue(
          homeworkLedgerSetting,
          enc(there.encode()),
          enc(here.encode()),
          decode: dec,
          encode: enc,
        ),
      ),
    );
    expect(merged['m|1']?.isDone, isTrue);
    expect(merged['m|2']?.isDone, isFalse);
    expect(merged['m|3']?.isDone, isTrue);

    final sent = decodeSent(
      dec(
        mergeValue(
          absenceSentSetting,
          enc(encodeSent({'a': later})),
          enc(encodeSent({'a': now, 'b': now})),
          decode: dec,
          encode: enc,
        ),
      ),
    );
    expect(sent, {'a': later, 'b': now});

    expect(
      mergeValue(
        'stundenplan.php/fork-lesson-times',
        enc('neu'),
        enc('alt'),
        decode: dec,
        encode: enc,
      ),
      enc('neu'),
    );
    expect(
      mergeValue(
        homeworkLedgerSetting,
        enc('x'),
        null,
        decode: dec,
        encode: enc,
      ),
      enc('x'),
    );
  });

  testWidgets('Seite: Senden und Übernehmen ohne Überlauf', (t) async {
    t.view.physicalSize = const Size(1080, 2424);
    t.view.devicePixelRatio = 2.625;
    addTearDown(t.view.reset);
    addTearDown(LanisClient.reset);
    await pumpTestApp(
      t,
      child: const TransferPage(),
      locale: const Locale('de'),
    );
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('Als Datei senden'), findsOneWidget);
    expect(find.text('Datei übernehmen'), findsOneWidget);
  });
}

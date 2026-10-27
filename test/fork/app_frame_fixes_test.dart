import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liblanis/liblanis.dart';
import 'package:path/path.dart' as p;
import 'package:lanis/fork/account_removal.dart';
import 'package:lanis/utils/url_modal.dart';
import 'package:lanis/view/login/school_selector.dart';
import 'package:lanis/widgets/format_text.dart';

import '../helpers/test_app.dart';

/// Regressionen der Prüfung 27.10.26 im übernommenen App-Rahmen (Lanis-Code).
void main() {
  group('isTrustedUrl (url_modal.dart)', () {
    test('Host selbst und Subdomains, nur https', () {
      expect(isTrustedUrl(Uri.parse('https://hessen.de/x')), isTrue);
      expect(
        isTrustedUrl(Uri.parse('https://start.schulportal.hessen.de/')),
        isTrue,
      );
      expect(
        isTrustedUrl(Uri.parse('https://DE.Wikipedia.org/wiki/A')),
        isTrue,
      );
    });

    test('ohne Punktgrenze, anderes Schema oder fremder Host: Rückfrage', () {
      expect(isTrustedUrl(Uri.parse('https://evilhessen.de/')), isFalse);
      expect(
        isTrustedUrl(Uri.parse('https://hessen.de.example.com/')),
        isFalse,
      );
      expect(isTrustedUrl(Uri.parse('http://hessen.de/')), isFalse);
      expect(isTrustedUrl(Uri.parse('javascript:alert(1)')), isFalse);
      expect(isTrustedUrl(Uri.parse('https://example.org/')), isFalse);
    });
  });

  test('FormattedText: & zuerst, < und > nicht doppelt maskiert', () {
    final out = FormattedText(
      text: '',
      formatStyle: FormatStyle(
        textStyle: const TextStyle(),
        timeColor: Colors.black,
        linkBackground: Colors.black,
        linkForeground: Colors.black,
        codeBackground: Colors.black,
        codeForeground: Colors.black,
      ),
    ).convertLanisSyntax('a < b & c > d');
    expect(out, contains('a &lt; b &amp; c &gt; d'));
    expect(out, isNot(contains('&amp;lt;')));
    expect(out, isNot(contains('&amp;gt;')));
  });

  group('Konto entfernen (account_removal.dart)', () {
    late Directory root;
    setUp(() => root = Directory.systemTemp.createTempSync('fork_rm_'));
    tearDown(() => root.deleteSync(recursive: true));

    test('Pfad wie StorageManager.getDocumentCacheDirectory', () {
      expect(
        accountDocumentCache(root.path, 7)!.path,
        p.join(root.path, '7', 'document_cache'),
      );
      expect(accountDocumentCache(null, 7), isNull);
      expect(accountDocumentCache('', 7), isNull);
    });

    test('löscht nur die Dateien dieses Kontos', () async {
      final mine = File(p.join(root.path, '7', 'document_cache', 'a', 'x.pdf'))
        ..createSync(recursive: true);
      final other = File(p.join(root.path, '8', 'document_cache', 'y.pdf'))
        ..createSync(recursive: true);
      await deleteAccountDocuments(root.path, 7);
      expect(mine.existsSync(), isFalse);
      expect(other.existsSync(), isTrue);
      // Ohne Ordner bzw. ohne Speicher kein Fehler.
      await deleteAccountDocuments(root.path, 9);
      await deleteAccountDocuments(null, 7);
    });
  });

  group('SchoolSelector', () {
    var calls = 0;
    setUp(() {
      calls = 0;
      SchoolSelector.beforeLoadForTest = () async {
        calls++;
        throw const SocketException('offline (Test)');
      };
    });
    tearDown(() {
      SchoolSelector.beforeLoadForTest = null;
      LanisClient.reset();
    });

    // Ursache (Prüfung 27.10.26): Nach einem Ladefehler plante die Auswahl
    // per Future.delayed alle 10 s einen neuen Versuch – auch nach dem
    // Entsorgen, endlos. Jetzt: Wiederholung solange sichtbar, danach keine.
    testWidgets('Wiederholung nur, solange die Auswahl lebt', (tester) async {
      await pumpTestApp(
        tester,
        child: Scaffold(
          body: Builder(
            builder: (context) => SchoolSelector(
              controller: TextEditingController(),
              outContext: context,
              onSchoolSelected: (_) {},
            ),
          ),
        ),
      );
      expect(calls, 1);
      await tester.pump(const Duration(seconds: 11));
      expect(calls, 2);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 30));
      expect(calls, 2);
    });
  });
}

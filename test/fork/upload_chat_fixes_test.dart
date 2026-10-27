import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/applets/conversations/view/shared.dart'
    show ConversationSettings;
import 'package:lanis/applets/conversations/view/components/rich_chat_text_editor.dart';
import 'package:lanis/applets/conversations/view/send.dart';
import 'package:lanis/applets/lessons/student/upload_dates.dart';
import 'package:lanis/fork/l10n/l10n.dart';
import 'package:lanis/fork/ui/courses/upload_view.dart';
import 'package:liblanis/liblanis.dart' show OwnFile;
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/utils/file_picker.dart' show pickedPhotoName;

import '../helpers/test_app.dart' show testLocalizationsDelegates;

/// Prüfung 27.10.26: Abgabeseite (upload_page.dart) und Unterhaltung
/// (chat.dart, rich_chat_text_editor.dart). Synthetische Werte.
void main() {
  group('UploadDates (fehlende Felder)', () {
    test('fehlender Start lässt die übrigen Felder stehen', () {
      final d = UploadDates.tryParse(
        startRaw: null,
        deadlineRaw: 'Freitag, den 6.11.26 14:00 Uhr',
        deletionRaw: '1.2.2027',
      );
      expect(d.start, isNull);
      expect(d.deadline, DateTime(2026, 11, 6, 14, 0));
      expect(d.automaticDeletion, DateTime(2027, 2, 1));
    });

    test('unlesbares Feld → null statt Ausnahme', () {
      final d = UploadDates.tryParse(
        startRaw: 'irgendwann',
        deadlineRaw: null,
        deletionRaw: 'nie',
      );
      expect(d.start, isNull);
      expect(d.deadline, isNull);
      expect(d.automaticDeletion, isNull);
    });
  });

  group('parseMaxFileSizeBytes', () {
    test('MB mit Komma und Punkt', () {
      expect(parseMaxFileSizeBytes('10 MB'), 10000000);
      expect(parseMaxFileSizeBytes('2,5 MB'), 2500000);
      expect(parseMaxFileSizeBytes('1.5MB'), 1500000);
    });

    test('andere Einheiten', () {
      expect(parseMaxFileSizeBytes('500 KB'), 500000);
      expect(parseMaxFileSizeBytes('1 GB'), 1000000000);
    });

    test('unbekannt → null (keine clientseitige Grenze)', () {
      expect(parseMaxFileSizeBytes(null), isNull);
      expect(parseMaxFileSizeBytes('unbegrenzt'), isNull);
      expect(parseMaxFileSizeBytes('10'), isNull);
    });
  });

  group('uploadWaitingTime (vor dem Start positiv)', () {
    final now = DateTime(2026, 10, 27, 8, 0);
    test('Tage', () {
      expect(uploadWaitingTime(now.add(const Duration(days: 3)), now), (
        3,
        UploadWaitUnit.day,
      ));
    });
    test('Stunden', () {
      expect(uploadWaitingTime(now.add(const Duration(hours: 5)), now), (
        5,
        UploadWaitUnit.hour,
      ));
    });
    test('Minuten', () {
      expect(uploadWaitingTime(now.add(const Duration(minutes: 30)), now), (
        30,
        UploadWaitUnit.minute,
      ));
    });
  });

  group('pickedPhotoName', () {
    test('eingegebener Name + Endung des Originals', () {
      expect(pickedPhotoName('Aufgabe 1', '/cache/abc.jpg'), 'Aufgabe 1.jpg');
    });
    test('Pfadanteile entfernt', () {
      expect(pickedPhotoName('../../evil', '/cache/abc.jpg'), 'evil.jpg');
    });
    test('leere Eingabe → Name des Originals', () {
      expect(pickedPhotoName('  ', '/cache/IMG_1.png'), 'IMG_1.png');
    });
    test('Mehrfachauswahl nummeriert', () {
      expect(
        pickedPhotoName('Blatt', '/cache/x.heic', index: 2),
        'Blatt_2.heic',
      );
    });
  });

  group('ConversationMessageText', () {
    test('nur Leerzeichen und Zeilen gelten als leer', () {
      final text = ConversationMessageText.parseText(
        Delta()..insert('   \n\n'),
      );
      expect(ConversationMessageText.isBlank(text), isTrue);
    });
    test('Fettschrift bleibt erhalten', () {
      final text = ConversationMessageText.parseText(
        Delta()
          ..insert('Hallo', {'bold': true})
          ..insert('\n'),
      );
      expect(text, '**Hallo**');
      expect(ConversationMessageText.isBlank(text), isFalse);
    });
  });

  group('RichChatTextEditor', () {
    Future<QuillController> pumpEditor(
      WidgetTester tester,
      SendMessageCallback send,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('de'),
          localizationsDelegates: [
            ...testLocalizationsDelegates,
            FlutterQuillLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.delegate.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: RichChatTextEditor(
                tooltip: 'Nachricht',
                sending: true,
                sendMessage: send,
                scrollToBottom: () {},
                editorSizeChangeCallback: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      return tester.widget<QuillEditor>(find.byType(QuillEditor)).controller;
    }

    testWidgets('Fehlschlag lässt den Text stehen', (tester) async {
      final controller = await pumpEditor(tester, (_) async => false);
      controller.replaceText(0, 0, 'Synthetisch', null);
      await tester.pump();
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();
      expect(controller.document.toPlainText(), 'Synthetisch\n');
    });

    testWidgets('Erfolg leert den Editor', (tester) async {
      final controller = await pumpEditor(tester, (_) async => true);
      controller.replaceText(0, 0, 'Synthetisch', null);
      await tester.pump();
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();
      expect(controller.document.toPlainText(), '\n');
    });

    testWidgets('nur Leerzeichen wird nicht gesendet', (tester) async {
      var calls = 0;
      final controller = await pumpEditor(tester, (_) async {
        calls++;
        return true;
      });
      controller.replaceText(0, 0, '   ', null);
      await tester.pump();
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();
      expect(calls, 0);
    });

    testWidgets('während des Sendens gesperrt', (tester) async {
      var calls = 0;
      final pending = Completer<bool>();
      final controller = await pumpEditor(tester, (_) {
        calls++;
        return pending.future;
      });
      controller.replaceText(0, 0, 'Synthetisch', null);
      await tester.pump();
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();
      expect(calls, 1);
      pending.complete(true);
      await tester.pump();
    });
  });

  test('Antwort in „nur an Absender“ geht an den Absender, sonst an alle', () {
    ConversationSettings c({
      bool private = false,
      bool own = false,
      String? sender = 'abc123',
    }) => ConversationSettings(
      id: 'x',
      groupChat: false,
      onlyPrivateAnswers: private,
      noReply: false,
      own: own,
      sender: sender,
    );
    expect(c().replyTo, 'all');
    expect(c(private: true).replyTo, 'abc123');
    expect(c(private: true, own: true).replyTo, 'all');
    expect(c(private: true, sender: null).replyTo, 'all');
    expect(c(private: true, sender: '').replyTo, 'all');
  });

  // Abgabeseite Entwurf 3 (Abnahme 27.10.26): Ein-Datei-Regel, Zustände,
  // Hilfen der Anzeige (upload_view.dart, upload_dates.dart).
  group('UploadInfo (Ein-Datei-Regel)', () {
    final now = DateTime(2026, 10, 27, 10);
    final dates = UploadDates(
      start: DateTime(2026, 10, 26, 8),
      deadline: DateTime(2026, 10, 30, 18),
    );
    OwnFile own() =>
        OwnFile(name: 'a.pdf', url: 'u', index: '1', time: '26.10.2026 19:42');

    test('nur eine Datei → Höchstzahl 1, erste Abgabe möglich', () {
      final i = UploadInfo(dates: dates, open: true);
      expect(i.maxFiles, 1);
      expect(i.done, isFalse);
      expect(i.canSubmit(now), isTrue);
    });

    test('einmalig und schon abgegeben → erledigt, kein Abgeben', () {
      final i = UploadInfo(dates: dates, open: true, ownFiles: [own()]);
      expect(i.done, isTrue);
      expect(i.canSubmit(now), isFalse);
    });

    test('beliebig oft → nach Abgabe weiter offen, bis 5 Dateien', () {
      final i = UploadInfo(
        dates: dates,
        open: true,
        multipleFiles: true,
        anyNumberOfTimes: true,
        ownFiles: [own()],
      );
      expect(i.maxFiles, 5);
      expect(i.done, isFalse);
      expect(i.canSubmit(now), isTrue);
    });

    test('vor dem Start und nach der Frist kein Abgeben', () {
      final i = UploadInfo(dates: dates, open: true);
      expect(i.canSubmit(DateTime(2026, 10, 25)), isFalse);
      expect(i.canSubmit(DateTime(2026, 10, 30, 18)), isFalse);
    });

    test('fromPortal: fehlende Felder → strenge Ersatzwerte', () {
      final i = UploadInfo.fromPortal({
        'allowed_file_types': ['PDF', ' JPG'],
        'additional_text': '  ',
      });
      expect(i.multipleFiles, isFalse);
      expect(i.anyNumberOfTimes, isFalse);
      expect(i.open, isFalse);
      expect(i.allowedTypes, ['PDF', 'JPG']);
      expect(i.additionalText, isNull);
      expect(i.ownFiles, isEmpty);
    });
  });

  group('Anzeige-Hilfen der Abgabe', () {
    test('parseOwnFileTime: verschiedene Schreibweisen', () {
      expect(
        parseOwnFileTime('26.10.2026 19:42'),
        DateTime(2026, 10, 26, 19, 42),
      );
      expect(
        parseOwnFileTime('(hochgeladen am 6.1.27 um 8:05 Uhr)'),
        DateTime(2027, 1, 6, 8, 5),
      );
      expect(parseOwnFileTime('gestern'), isNull);
      expect(cleanOwnFileTime(' (gestern) '), 'gestern');
    });

    test('formatUploadSize dezimal wie parseMaxFileSizeBytes', () {
      expect(formatUploadSize(1200000, 'de'), '1,2 MB');
      expect(formatUploadSize(10000000, 'de'), '10 MB');
      expect(formatUploadSize(350000, 'en'), '350 KB');
      expect(formatUploadSize(512, 'de'), '512 B');
    });

    test('Sichtbarkeit: nur der eindeutige Lehrkraft-Fall wird kurz', () {
      final t = forkL10nFor('de');
      expect(uploadVisibilityLabel(t, 'Lehrkraft'), 'nur Lehrkraft');
      expect(
        uploadVisibilityLabel(t, 'Lehrkraft und Kursteilnehmer'),
        'Lehrkraft und Kursteilnehmer',
      );
    });
  });
}

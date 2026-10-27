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
}

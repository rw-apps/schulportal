import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/absence/absence_form.dart';
import 'package:lanis/fork/absence/absence_parser.dart' show AbsenceCheck;
import 'package:lanis/fork/absence/absence_view.dart';

/// Erfundene Formulardaten, Aufbau wie abwesenheitsmeldung.php von Schule A.
AbsenceForm _form({DateRange? to}) => AbsenceForm(
  pupils: const [
    AbsencePupil(id: '111', name: 'Anna Beispiel', preselected: true, allowed: true),
  ],
  kinds: const [
    AbsenceChoice('krank', 'als abwesend melden'),
    AbsenceChoice('verspätet', 'als verspätet melden'),
  ],
  blocks: const [
    AbsenceBlock(value: '0', label: '0. Block', start: '08:00', end: '08:45'),
    AbsenceBlock(value: '1', label: '1. Block', start: '09:00', end: '10:15'),
  ],
  fromRange: DateRange(DateTime(2026, 10, 16), DateTime(2026, 10, 19)),
  toRange: to ?? DateRange(DateTime(2026, 10, 16), DateTime(2026, 10, 22)),
  defaultFrom: DateTime(2026, 10, 16),
  defaultTo: DateTime(2026, 10, 16),
  rules: const ['spätestens bis 12:00 des aktuellen Tages'],
);

Future<void> _tall(WidgetTester t) async {
  t.view.physicalSize = const Size(1080, 4000);
  t.view.devicePixelRatio = 2.5;
  addTearDown(t.view.reset);
}

Widget _app(AbsenceForm f) =>
    MaterialApp(home: Scaffold(body: AbsenceFormView(form: f)));

void main() {
  testWidgets('Vorgaben des Portals sind vorausgewählt, Senden gesperrt', (t) async {
    await _tall(t);
    await t.pumpWidget(_app(_form()));
    expect(find.textContaining('Anna – abwesend'), findsOneWidget);
    expect(find.textContaining('Fr, 16.10., ganzer Tag'), findsOneWidget);
    expect(find.text('Von Block'), findsNothing,
        reason: 'Abwesend: keine Blöcke (wie im Portal)');
    expect(find.text('Bitte keine Gesundheitsdaten eingeben.'), findsOneWidget);
    expect(find.textContaining('spätestens bis 12:00'), findsOneWidget);

    final send = t.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Absenden (folgt nach gemeinsamem Test)'),
    );
    expect(send.onPressed, isNull, reason: 'Kein echtes Absenden vor dem Test');

    await t.tap(find.text('Verspätet'));
    await t.pump();
    expect(find.textContaining('Anna – verspätet'), findsOneWidget);
    expect(find.text('Am'), findsOneWidget);
    expect(find.text('Von Block'), findsOneWidget);
    expect(find.text('Bis'), findsNothing);
  });

  testWidgets('Vorschau zeigt die Portal-Felder', (t) async {
    await _tall(t);
    await t.pumpWidget(_app(_form()));
    await t.tap(find.text('Vorschau der Portal-Felder'));
    await t.pumpAndSettle();
    expect(find.textContaining('selectedPupils = 111'), findsOneWidget);
    expect(find.textContaining('von = 16.10.2026'), findsOneWidget);
    expect(find.textContaining('save'), findsNothing);
  });

  testWidgets('ohne Kind keine Vorschau', (t) async {
    await _tall(t);
    await t.pumpWidget(_app(_form()));
    await t.tap(find.text('Anna Beispiel'));
    await t.pump();
    expect(find.text('Bitte ein Kind auswählen.'), findsOneWidget);
    final preview = t.widget<TextButton>(
      find.widgetWithText(TextButton, 'Vorschau der Portal-Felder'),
    );
    expect(preview.onPressed, isNull);
  });

  testWidgets('Neuladen behält Eingaben', (t) async {
    await _tall(t);
    await t.pumpWidget(_app(_form()));
    await t.tap(find.text('Verspätet'));
    await t.pump();
    await t.pumpWidget(_app(_form(to: DateRange(DateTime(2026, 10, 16), DateTime(2026, 10, 23)))));
    expect(find.textContaining('Anna – verspätet'), findsOneWidget);
  });

  testWidgets('letzter Knopf bleibt über der Navigationsleiste', (t) async {
    // Pixel-9a-ähnlich: schmal, Gestenleiste unten (randlose App).
    t.view.physicalSize = const Size(1080, 1500);
    t.view.devicePixelRatio = 2.5;
    t.view.padding = const FakeViewPadding(bottom: 120);
    addTearDown(t.view.reset);
    await t.pumpWidget(_app(_form()));
    await t.drag(find.byType(ListView), const Offset(0, -3000));
    await t.pumpAndSettle();
    final button = find.widgetWithText(TextButton, 'Vorschau der Portal-Felder');
    final screenH = 1500 / 2.5;
    final insetH = 120 / 2.5;
    expect(t.getBottomLeft(button).dy, lessThanOrEqualTo(screenH - insetH));
  });

  testWidgets('Prüfen: Antwort des Portals wird angezeigt, nichts gesendet',
      (t) async {
    await _tall(t);
    Map<String, String>? sent;
    var answer = const AbsenceCheck(true, []);
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AbsenceFormView(
          form: _form(),
          onCheck: (fields) async {
            sent = fields;
            return answer;
          },
        ),
      ),
    ));
    await t.tap(find.text('Beim Portal prüfen (sendet nichts)'));
    await t.pumpAndSettle();
    expect(find.text('Prüfung bestanden'), findsOneWidget);
    expect(find.textContaining('Gesendet wurde nichts'), findsOneWidget);
    expect(sent!['selectedPupils'], '111');
    expect(sent!.containsKey('save'), isFalse);
    await t.tap(find.text('OK'));
    await t.pumpAndSettle();

    answer = const AbsenceCheck(false, ['Meldung nur bis 12:00 möglich']);
    await t.tap(find.text('Beim Portal prüfen (sendet nichts)'));
    await t.pumpAndSettle();
    expect(find.text('Das Portal lehnt ab'), findsOneWidget);
    expect(find.text('Meldung nur bis 12:00 möglich'), findsOneWidget);
  });

  testWidgets('ohne Prüf-Anbindung ist der Knopf gesperrt', (t) async {
    await _tall(t);
    await t.pumpWidget(_app(_form()));
    final b = t.widget<OutlinedButton>(find.widgetWithText(
        OutlinedButton, 'Beim Portal prüfen (sendet nichts)'));
    expect(b.onPressed, isNull);
    final send = t.widget<FilledButton>(find.widgetWithText(
        FilledButton, 'Absenden (folgt nach gemeinsamem Test)'));
    expect(send.onPressed, isNull, reason: 'Senden bleibt gesperrt');
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/absence/absence_form.dart';
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
    expect(find.textContaining('Fr, 16.10., 0. Block bis 1. Block'), findsOneWidget);
    expect(find.textContaining('spätestens bis 12:00'), findsOneWidget);

    final send = t.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Absenden (folgt nach gemeinsamem Test)'),
    );
    expect(send.onPressed, isNull, reason: 'Kein echtes Absenden vor dem Test');

    await t.tap(find.text('Verspätet'));
    await t.pump();
    expect(find.textContaining('Anna – verspätet'), findsOneWidget);
  });

  testWidgets('Vorschau zeigt die Portal-Felder', (t) async {
    await _tall(t);
    await t.pumpWidget(_app(_form()));
    await t.tap(find.text('Vorschau der Portal-Felder'));
    await t.pumpAndSettle();
    expect(find.textContaining('selectedPupils = 111'), findsOneWidget);
    expect(find.textContaining('von = 16.10.2026'), findsOneWidget);
  });

  testWidgets('ohne Kind keine Vorschau', (t) async {
    await _tall(t);
    await t.pumpWidget(_app(_form()));
    await t.tap(find.text('Anna Beispiel'));
    await t.pump();
    expect(find.text('Bitte ein Kind auswählen.'), findsOneWidget);
    final preview = t.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Vorschau der Portal-Felder'),
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
}

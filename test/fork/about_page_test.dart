import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/ui/settings/about_page.dart';
import 'package:liblanis/liblanis.dart';

import '../helpers/test_app.dart';

void main() {
  tearDown(LanisClient.reset);

  // GPL-3.0 verlangt den Hinweis auf Lizenz und Quellcode in der Oberfläche,
  // die Bibliotheken ihre Lizenztexte – beides muss erreichbar bleiben.
  testWidgets('Über die App: Lizenz, Bibliotheken, Fehlersuche', (t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await pumpTestApp(
      t,
      locale: const Locale('de'),
      child: const AboutSettingsPage(),
    );
    await t.pumpAndSettle();
    expect(find.text('Quellcode und Lizenz'), findsOneWidget);
    expect(find.text('Verwendete Bibliotheken'), findsOneWidget);
    expect(find.text('Fehlersuche'), findsOneWidget);
    expect(find.text('Debug-Export'), findsNothing);
  });
}

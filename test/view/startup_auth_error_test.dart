import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/fork/l10n/l10n.dart';
import 'package:lanis/startup.dart';

import '../helpers/test_app.dart';

// Fork (19.10.26): Fehlerseite im Stil der App, Texte aus loginErrorText.
void main() {
  tearDown(LanisClient.reset);

  Future<ForkL10n> pump(
    WidgetTester tester,
    LanisException e, {
    VoidCallback? onRetry,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await pumpTestApp(
      tester,
      child: Scaffold(
        body: StartupAuthErrorContent(exception: e, onRetry: onRetry ?? () {}),
      ),
    );
    return tester.element(find.byType(StartupAuthErrorContent)).t;
  }

  testWidgets('offline: Titel, Symbol, kein Fehlertyp', (tester) async {
    final t = await pump(tester, NoConnectionException());
    expect(find.byIcon(Icons.wifi_off), findsOneWidget);
    expect(find.text(t.loginOfflineTitle), findsOneWidget);
    expect(find.textContaining('Exception'), findsNothing);
  });

  testWidgets('Portal gestört: Titel und Statusseite', (tester) async {
    final t = await pump(tester, LanisDownException());
    expect(find.text(t.loginDownTitle), findsOneWidget);
    expect(find.text(t.loginStatusPage), findsOneWidget);
  });

  testWidgets('gesperrt: Wartezeit statt englischem Fehlertext', (
    tester,
  ) async {
    final t = await pump(tester, LoginTimeoutException('16'));
    expect(find.text(t.loginLockedTitle), findsOneWidget);
    expect(find.text(t.loginLockedText(16)), findsOneWidget);
    expect(find.textContaining('LoginTimeoutException'), findsNothing);
  });

  testWidgets('unbekannter Fehler zeigt Details für eine Meldung', (
    tester,
  ) async {
    final t = await pump(tester, UnknownException('boom'));
    expect(find.text(t.loginOtherTitle), findsOneWidget);
    expect(find.textContaining('boom'), findsOneWidget);
  });

  testWidgets('falsches Passwort: verständlicher Titel', (tester) async {
    final t = await pump(tester, WrongCredentialsException());
    expect(find.text(t.loginWrongTitle), findsOneWidget);
    expect(find.byIcon(Icons.refresh), findsOneWidget);
  });

  testWidgets('Erneut versuchen ruft den Rückruf', (tester) async {
    var retried = false;
    final t = await pump(
      tester,
      NoConnectionException(),
      onRetry: () => retried = true,
    );
    await tester.tap(find.text(t.loginRetry));
    expect(retried, isTrue);
  });
}

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/fork/l10n/l10n.dart';
import 'package:lanis/fork/ui/settings/error_report_page.dart';
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

  testWidgets('Serverfehler des Portals: eigene Meldung, kein Englisch', (
    tester,
  ) async {
    // Wie LanisSession.authenticate einen HTTP-500 weitergibt
    // (Bildschirmfoto 22.10.26).
    final req = RequestOptions(path: '/');
    final dio = DioException.badResponse(
      statusCode: 500,
      requestOptions: req,
      response: Response(requestOptions: req, statusCode: 500),
    );
    final t = await pump(tester, UnknownException(dio.message));
    expect(find.text(t.loginServerTitle), findsOneWidget);
    expect(find.text(t.loginServerText), findsOneWidget);
    expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
    expect(find.textContaining('Exception'), findsNothing);
    expect(find.text(t.loginStatusPage), findsOneWidget);
    expect(find.text(t.reportError), findsNothing);
  });

  testWidgets('unbekannter Fehler: „Fehler melden“ öffnet den Bericht', (
    tester,
  ) async {
    final t = await pump(tester, UnknownException('boom'));
    await tester.tap(find.text(t.reportError));
    await tester.pumpAndSettle();
    expect(find.byType(ErrorReportPage), findsOneWidget);
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

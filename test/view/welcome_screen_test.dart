import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/fork/l10n/l10n.dart';
import 'package:lanis/view/login/screen.dart';

import '../helpers/test_app.dart';

void main() {
  tearDown(LanisClient.reset);

  testWidgets('welcome shows first page title', (tester) async {
    await pumpTestRouterApp(
      tester,
      initialLocation: '/welcome',
      routes: [
        GoRoute(
          path: '/welcome',
          builder: (_, _) => const WelcomeLoginScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (_, _) => const Scaffold(body: Text('login-marker')),
        ),
      ],
    );

    // Fork: eine Willkommensseite (ForkWelcomePage) statt sechs Seiten.
    expect(find.text(forkL10nFor('en').onbAppName), findsOneWidget);
    expect(find.text(forkL10nFor('en').navCalendar), findsOneWidget);
  });

  testWidgets('sign in navigates to login', (tester) async {
    await pumpTestRouterApp(
      tester,
      initialLocation: '/welcome',
      routes: [
        GoRoute(
          path: '/welcome',
          builder: (_, _) => const WelcomeLoginScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (_, _) => const Scaffold(body: Text('login-marker')),
        ),
      ],
    );

    final login = find.text(forkL10nFor('en').onbLogin);
    await tester.ensureVisible(login);
    await tester.pumpAndSettle();
    await tester.tap(login);
    await tester.pumpAndSettle();
    expect(find.text('login-marker'), findsOneWidget);
  });
}

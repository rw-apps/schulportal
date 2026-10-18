import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:lanis/fork/onboarding/onboarding_pages.dart';

/// Start der Erstanmeldung. Fork: eine Willkommensseite im Stil der App
/// (ForkWelcomePage) statt der sechs Einführungsseiten von Lanis-Mobile
/// (Entwurf 18.10.26, abgenommen); intro_screen_page_view_models.dart bleibt
/// für die Upstream-Herkunft liegen, wird aber nicht mehr gezeigt.
class WelcomeLoginScreen extends StatelessWidget {
  const WelcomeLoginScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      ForkWelcomePage(onLogin: () => context.go('/login'));
}

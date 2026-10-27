import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:lanis/fork/demo/demo_entry.dart';
import 'package:lanis/fork/onboarding/onboarding_pages.dart';
import 'package:lanis/fork/ui/settings/device_transfer_page.dart';

/// Start der Erstanmeldung. Fork: eine Willkommensseite im Stil der App
/// (ForkWelcomePage) statt der sechs Einführungsseiten der Vorlage
/// (Entwurf 18.10.26, abgenommen); die Einführungsseiten
/// (intro_screen_page_view_models.dart) sind seit der Prüfung 27.10.26
/// gelöscht.
class WelcomeLoginScreen extends StatelessWidget {
  const WelcomeLoginScreen({super.key});

  @override
  Widget build(BuildContext context) => ForkWelcomePage(
    onLogin: () => context.go('/login'),
    onDemo: () => showDemoChooser(context),
    onTransfer: () => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const DeviceReceivePage(firstSetup: true),
      ),
    ),
  );
}

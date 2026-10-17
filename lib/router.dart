import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/fork/start.dart';
import 'package:lanis/fork/ui/preview/preview_shell.dart';
import 'package:lanis/startup.dart';
import 'package:lanis/features/auth/auth_controller.dart';
import 'package:lanis/utils/auth_redirect.dart';
import 'package:lanis/utils/deep_link.dart';
import 'package:lanis/view/account_switcher/account_switcher.dart';
import 'package:lanis/utils/privacy_policy.dart';
import 'package:lanis/view/login/auth.dart';
import 'package:lanis/view/login/screen.dart';
import 'package:lanis/view/moodle.dart';
import 'package:lanis/view/privacy_policy/privacy_policy_screen.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Routen der App.
///
/// Fork (Aufräumen 17.10.26): ohne das Lanis-Gerüst (StatefulShellRoute mit
/// je einem Zweig pro Bereich, Schublade, alte Einstellungen) – die App
/// startet immer mit der neuen Oberfläche ([forkHomePath]). Unterseiten
/// (Unterhaltung, Kursseite, Abgabe, Krankmeldung, Einstellungen) öffnet die
/// Oberfläche selbst per Navigator. Geblieben sind Start, Anmeldung,
/// Datenschutz, Kontowechsel und Moodle.
final goRouterProvider = Provider<GoRouter>((ref) {
  final listenable = _AuthListenable(ref);
  ref.onDispose(listenable.dispose);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/startup',
    refreshListenable: listenable,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final shared = ref.read(sharedOverAccountSettingsProvider);
      final accounts = ref.read(accountsProvider).asData?.value;
      return resolveAuthRedirect(
        phase: auth.phase,
        loc: state.matchedLocation,
        privacyAccepted: isPrivacyPolicyAccepted(shared),
        hasAccounts: accounts?.isNotEmpty ?? false,
        isShellPath: false,
        shellSupported: true,
        deepLinkErrorPath: null,
        homePath: () => firstSupportedHomePathFromRef(ref),
      );
    },
    routes: [
      GoRoute(
        path: '/startup',
        builder: (context, state) => const StartupScreen(),
      ),
      GoRoute(
        path: '/privacy-policy',
        builder: (context, state) => const PrivacyPolicyScreen(),
      ),
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeLoginScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) =>
            const Scaffold(body: LoginForm(showBackButton: true)),
      ),
      GoRoute(
        path: forkHomePath,
        builder: (context, state) =>
            const PreviewShell(liveData: true, asRoot: true),
      ),
      GoRoute(
        path: SettingsDeepLinks.moodle,
        builder: (context, state) => const MoodleWebView(),
      ),
      GoRoute(
        path: '/accounts',
        builder: (context, state) => const AccountSwitcher(),
      ),
    ],
  );
});

/// Notifies [GoRouter] when auth phase or account list changes.
class _AuthListenable extends ChangeNotifier {
  _AuthListenable(this.ref) {
    ref.listen(authControllerProvider, (_, _) => notifyListeners());
    ref.listen(accountsProvider, (_, _) => notifyListeners());
  }

  final Ref ref;
}

import 'package:lanis/features/auth/auth_controller.dart';

/// Pure auth/privacy redirect used by [goRouterProvider].
///
/// Returns a location to redirect to, or `null` to stay on [loc].
///
/// The blocking privacy-policy update screen is only for installs that already
/// have an account. First-time users accept the policy on the login form.
///
/// Fork (Prüfung 27.10.26): Parameter isShellPath, shellSupported und
/// deepLinkErrorPath entfernt – router.dart übergab sie immer als
/// Konstanten (false/true/null), und die Route `/deep-link-error` gab es
/// nicht; die Zweige waren unerreichbar.
String? resolveAuthRedirect({
  required AuthPhase phase,
  required String loc,
  required bool privacyAccepted,
  required bool hasAccounts,
  required String Function() homePath,
}) {
  final loggingIn = loc == '/welcome' || loc == '/login';
  final onStartup = loc == '/startup';
  final onPrivacyPolicy = loc == '/privacy-policy';

  if (!privacyAccepted && !onPrivacyPolicy && hasAccounts) {
    return '/privacy-policy';
  }

  switch (phase) {
    case AuthPhase.authenticating:
      if (onStartup ||
          onPrivacyPolicy ||
          loc == '/login' ||
          loc == '/accounts') {
        return null;
      }
      return '/startup';
    case AuthPhase.unauthenticated:
      if (onPrivacyPolicy) {
        // Empty installs should not stay on the update gate.
        return hasAccounts ? null : '/welcome';
      }
      if (loggingIn || onStartup) {
        if (onStartup) return '/welcome';
        return null;
      }
      return '/welcome';
    case AuthPhase.error:
      if (onPrivacyPolicy || loc == '/login') return null;
      return onStartup ? null : '/startup';
    case AuthPhase.authenticated:
      if (onPrivacyPolicy) {
        // Fork: ohne Zustimmung auf der Seite bleiben. Ursache (Prüfung
        // 27.10.26): Angemeldet, mit Konten und neuer, noch nicht
        // angenommener Datenschutzerklärung schickte dieser Zweig nach
        // homePath, die Prüfung oben von dort zurück – eine Endlosschleife
        // im Router. Grenze: Mit Zustimmung geht es wie bisher nach Hause.
        return privacyAccepted ? homePath() : null;
      }
      if (loggingIn && loc == '/login') return null;
      if (loc == '/welcome' || onStartup) {
        return homePath();
      }
      return null;
  }
}

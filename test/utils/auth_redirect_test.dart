import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/features/auth/auth_controller.dart';
import 'package:lanis/utils/auth_redirect.dart';

void main() {
  const home = '/common/substitutions/home';

  String? resolve({
    required AuthPhase phase,
    required String loc,
    bool privacyAccepted = true,
    bool hasAccounts = true,
  }) {
    return resolveAuthRedirect(
      phase: phase,
      loc: loc,
      privacyAccepted: privacyAccepted,
      hasAccounts: hasAccounts,
      homePath: () => home,
    );
  }

  group('privacy gate', () {
    test('forces privacy-policy only when accounts already exist', () {
      expect(
        resolve(
          phase: AuthPhase.authenticating,
          loc: '/startup',
          privacyAccepted: false,
          hasAccounts: true,
        ),
        '/privacy-policy',
      );
      expect(
        resolve(
          phase: AuthPhase.unauthenticated,
          loc: '/welcome',
          privacyAccepted: false,
          hasAccounts: true,
        ),
        '/privacy-policy',
      );
    });

    test('skips privacy-policy gate for empty first-time installs', () {
      expect(
        resolve(
          phase: AuthPhase.authenticating,
          loc: '/startup',
          privacyAccepted: false,
          hasAccounts: false,
        ),
        isNull,
      );
      expect(
        resolve(
          phase: AuthPhase.unauthenticated,
          loc: '/startup',
          privacyAccepted: false,
          hasAccounts: false,
        ),
        '/welcome',
      );
      expect(
        resolve(
          phase: AuthPhase.unauthenticated,
          loc: '/welcome',
          privacyAccepted: false,
          hasAccounts: false,
        ),
        isNull,
      );
      expect(
        resolve(
          phase: AuthPhase.unauthenticated,
          loc: '/privacy-policy',
          privacyAccepted: false,
          hasAccounts: false,
        ),
        '/welcome',
      );
    });

    test('allows staying on privacy-policy when accounts exist', () {
      expect(
        resolve(
          phase: AuthPhase.unauthenticated,
          loc: '/privacy-policy',
          privacyAccepted: false,
          hasAccounts: true,
        ),
        isNull,
      );
    });
  });

  group('authenticating', () {
    test('allows startup login accounts privacy', () {
      for (final loc in [
        '/startup',
        '/login',
        '/accounts',
        '/privacy-policy',
      ]) {
        expect(
          resolve(phase: AuthPhase.authenticating, loc: loc),
          isNull,
          reason: loc,
        );
      }
    });

    test('sends other locations to startup', () {
      expect(
        resolve(phase: AuthPhase.authenticating, loc: '/welcome'),
        '/startup',
      );
      expect(
        resolve(
          phase: AuthPhase.authenticating,
          loc: '/common/substitutions/home',
        ),
        '/startup',
      );
    });
  });

  group('unauthenticated', () {
    test('startup goes to welcome', () {
      expect(
        resolve(phase: AuthPhase.unauthenticated, loc: '/startup'),
        '/welcome',
      );
    });

    test('keeps welcome and login', () {
      expect(
        resolve(phase: AuthPhase.unauthenticated, loc: '/welcome'),
        isNull,
      );
      expect(resolve(phase: AuthPhase.unauthenticated, loc: '/login'), isNull);
    });

    test('deep links go to welcome', () {
      expect(
        resolve(
          phase: AuthPhase.unauthenticated,
          loc: '/common/substitutions/home',
        ),
        '/welcome',
      );
    });
  });

  group('error', () {
    test('allows startup and login', () {
      expect(resolve(phase: AuthPhase.error, loc: '/startup'), isNull);
      expect(resolve(phase: AuthPhase.error, loc: '/login'), isNull);
    });

    test('other locations go to startup', () {
      expect(resolve(phase: AuthPhase.error, loc: '/welcome'), '/startup');
    });
  });

  group('authenticated', () {
    test('privacy and welcome/startup go home', () {
      expect(
        resolve(phase: AuthPhase.authenticated, loc: '/privacy-policy'),
        home,
      );
      expect(resolve(phase: AuthPhase.authenticated, loc: '/welcome'), home);
      expect(resolve(phase: AuthPhase.authenticated, loc: '/startup'), home);
    });

    test('login special-case stays', () {
      expect(resolve(phase: AuthPhase.authenticated, loc: '/login'), isNull);
    });

    // Fork (Prüfung 27.10.26): vorher Endlosschleife privacy ↔ home.
    test('privacy not accepted with accounts stays on privacy', () {
      expect(
        resolve(
          phase: AuthPhase.authenticated,
          loc: '/privacy-policy',
          privacyAccepted: false,
        ),
        isNull,
      );
      expect(
        resolve(
          phase: AuthPhase.authenticated,
          loc: home,
          privacyAccepted: false,
        ),
        '/privacy-policy',
      );
    });

    test('other authenticated locations stay', () {
      expect(resolve(phase: AuthPhase.authenticated, loc: home), isNull);
    });
  });
}

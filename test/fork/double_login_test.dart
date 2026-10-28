// Prüfung 27.10.26, Befund 9: doppelte Anmeldungen je Konto.
// Nur ausgedachte Daten.
import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/features/auth/auth_controller.dart';
import 'package:lanis/fork/login_guard.dart';
import 'package:lanis/fork/notify/notify_keys.dart';
import 'package:liblanis/liblanis.dart';

import '../helpers/test_app.dart';

TypedSettings _mem() {
  final m = <String, String?>{};
  return TypedSettings(
    read: (k) => m[k],
    write: (k, v) => m[k] = v,
    delete: m.remove,
  );
}

void main() {
  group('Einmal-Lauf nach dem Start (startRunDue)', () {
    final now = DateTime(2026, 10, 28, 12);
    const hour = Duration(minutes: 60);

    test('noch nie gelaufen → fällig', () {
      expect(startRunDue(null, now, hour), isTrue);
    });

    test('letzter Lauf jünger als der Abstand → nicht fällig', () {
      final last = now.subtract(const Duration(minutes: 20));
      expect(startRunDue(last, now, hour), isFalse);
    });

    test('genau ein Abstand oder älter → fällig', () {
      expect(startRunDue(now.subtract(hour), now, hour), isTrue);
      final old = now.subtract(const Duration(hours: 5));
      expect(startRunDue(old, now, hour), isTrue);
    });

    test('Zeitpunkt in der Zukunft (Uhr zurückgestellt) → fällig', () {
      final future = now.add(const Duration(days: 1));
      expect(startRunDue(future, now, hour), isTrue);
    });

    test('kürzerer Abstand (15 min) zählt', () {
      final last = now.subtract(const Duration(minutes: 20));
      expect(startRunDue(last, now, const Duration(minutes: 15)), isTrue);
    });

    test('Zeitpunkt merken und lesen', () {
      final s = _mem();
      expect(lastFullRun(s), isNull);
      noteFullRun(s, now);
      expect(lastFullRun(s), now);
      s.setString(notifyLastFullRunKey, 'kaputt');
      expect(lastFullRun(s), isNull, reason: 'unlesbar = nie gelaufen');
    });
  });

  group('Login-Link-Übergabe (handOverLoginUrl/takeLoginUrl)', () {
    setUp(clearLoginUrlHandoffs);
    tearDown(clearLoginUrlHandoffs);
    final t0 = DateTime(2026, 10, 28, 12);

    test('nur einmal und nur für dasselbe Konto', () {
      handOverLoginUrl(7, 'https://example.invalid/a', now: t0);
      expect(takeLoginUrl(8, now: t0), isNull);
      expect(takeLoginUrl(7, now: t0), 'https://example.invalid/a');
      expect(takeLoginUrl(7, now: t0), isNull, reason: 'verbraucht');
    });

    test('zu alt oder leer → keiner', () {
      handOverLoginUrl(7, 'https://example.invalid/a', now: t0);
      final late = t0.add(loginUrlHandoffMaxAge + const Duration(seconds: 1));
      expect(takeLoginUrl(7, now: late), isNull);
      handOverLoginUrl(7, '', now: t0);
      expect(takeLoginUrl(7, now: t0), isNull);
    });
  });

  group('Konto hinzufügen: eine Anmeldung', () {
    tearDown(() {
      resetAuthTestSeams();
      clearLoginUrlHandoffs();
    });

    test('Link der Prüfung wird eingelöst – genau eine Anmeldung', () async {
      installFakeSessionAuth();
      final container = createAuthTestContainer();
      addTearDown(container.dispose);
      acceptPrivacy(container);
      // Ablauf wie view/login/auth.dart: Prüfung → anlegen → übergeben →
      // loginWithAccount.
      final id = await addTestAccount(container, username: 'kind.eins');
      handOverLoginUrl(id, 'https://example.invalid/ticket');

      final ok = await container
          .read(authControllerProvider.notifier)
          .loginWithAccount(id, removeAccountOnFailure: true);

      expect(ok, isTrue);
      expect(AuthController.authenticateCallCount, 1);
      expect(AuthController.lastLoginUrl, 'https://example.invalid/ticket');
      expect(takeLoginUrl(id), isNull, reason: 'verbraucht');
    });

    test(
      'Fehlschlag: voriges Konto meldet sich ohne fremden Link an',
      () async {
        final urls = <String?>[];
        installFakeSessionAuth(
          nextResult: () {
            urls.add(AuthController.lastLoginUrl);
            return urls.length == 2
                ? FakeAuthResult.lanisDown
                : FakeAuthResult.success;
          },
        );
        final container = createAuthTestContainer();
        addTearDown(container.dispose);
        acceptPrivacy(container);
        final first = await addTestAccount(container, username: 'eltern.a');
        final auth = container.read(authControllerProvider.notifier);
        expect(await auth.loginWithAccount(first), isTrue);

        final added = await addTestAccount(container, username: 'kind.zwei');
        handOverLoginUrl(added, 'https://example.invalid/ticket');
        final ok = await auth.loginWithAccount(
          added,
          removeAccountOnFailure: true,
        );

        expect(ok, isFalse);
        // 1. erstes Konto, 2. neues Konto (Link), 3. erstes Konto zurück.
        expect(urls, [null, 'https://example.invalid/ticket', null]);
        expect(container.read(activeAccountProvider)?.localId, first);
        final left = await container.read(accountsProvider.future);
        expect(left.map((a) => a.localId), [first]);
      },
    );
  });
}

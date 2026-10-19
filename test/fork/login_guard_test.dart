import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/login_guard.dart';
import 'package:liblanis/liblanis.dart';

TypedSettings _mem() {
  final m = <String, String?>{};
  return TypedSettings(
    read: (k) => m[k],
    write: (k, v) => m[k] = v,
    delete: m.remove,
  );
}

void main() {
  final now = DateTime(2026, 10, 19, 8);

  test(
    'Sperre des Portals: bis zum Ende kein Versuch, auch nicht auf Knopfdruck',
    () {
      final s = _mem();
      noteLoginResult(s, 'pw', LoginTimeoutException('16'), now: now);
      expect(
        () => checkLoginAllowed(
          s,
          'pw',
          userInitiated: true,
          now: now.add(const Duration(seconds: 10)),
        ),
        throwsA(
          isA<LoginTimeoutException>().having((e) => e.time, 'time', '12'),
        ),
      );
      // Nach Ende (+5 s Luft) wieder erlaubt.
      checkLoginAllowed(
        s,
        'pw',
        userInitiated: false,
        now: now.add(const Duration(seconds: 22)),
      );
    },
  );

  test(
    'abgelehntes Passwort: automatisch nicht mehr, auf Knopfdruck schon',
    () {
      final s = _mem();
      noteLoginResult(s, 'alt', WrongCredentialsException(), now: now);
      expect(
        () => checkLoginAllowed(s, 'alt', userInitiated: false, now: now),
        throwsA(isA<WrongCredentialsException>()),
      );
      checkLoginAllowed(s, 'alt', userInitiated: true, now: now);
      // Neues Passwort hebt die Sperre der App auf.
      checkLoginAllowed(s, 'neu', userInitiated: false, now: now);
    },
  );

  test('Erfolg löscht beides', () {
    final s = _mem();
    noteLoginResult(s, 'pw', WrongCredentialsException(), now: now);
    noteLoginResult(s, 'pw', LoginTimeoutException('60'), now: now);
    noteLoginResult(s, 'pw', null, now: now);
    expect(lockedUntil(s, now: now), isNull);
    expect(passwordRejected(s, 'pw'), isFalse);
  });

  test('das Passwort selbst wird nicht gespeichert', () {
    final m = <String, String?>{};
    final s = TypedSettings(
      read: (k) => m[k],
      write: (k, v) => m[k] = v,
      delete: m.remove,
    );
    noteLoginResult(s, 'geheim123', WrongCredentialsException(), now: now);
    expect(m.values.join(), isNot(contains('geheim123')));
  });

  test('guardedLogin fragt das Portal während der Sperre nicht', () async {
    final s = _mem();
    noteLoginResult(s, 'pw', LoginTimeoutException('300'), now: DateTime.now());
    var called = false;
    await expectLater(
      guardedLogin(s, 'pw', () async => called = true, userInitiated: true),
      throwsA(isA<LoginTimeoutException>()),
    );
    expect(called, isFalse);
  });

  test('guardedLogin merkt Ablehnung und hebt sie bei Erfolg auf', () async {
    final s = _mem();
    await expectLater(
      guardedLogin<void>(
        s,
        'pw',
        () async => throw WrongCredentialsException(),
      ),
      throwsA(isA<WrongCredentialsException>()),
    );
    expect(passwordRejected(s, 'pw'), isTrue);
    await guardedLogin(s, 'pw', () async => 1, userInitiated: true);
    expect(passwordRejected(s, 'pw'), isFalse);
  });
}

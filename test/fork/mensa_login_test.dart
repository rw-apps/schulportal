import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/mensa_login.dart';
import 'package:liblanis/liblanis.dart' show MemorySecretStore;

/// Gemerkte Anmeldung beim Caterer (mensa_login.dart). Die Skripte selbst
/// sind am 27.10.26 in Chromium gegen nachgebaute Anmeldeseiten geprüft
/// (mit Formular, ohne Formular, keine Maske).
void main() {
  setUp(() => mensaSecrets = MemorySecretStore());

  test('merken, lesen, ablehnen, vergessen', () async {
    expect(await readMensaLogin('1:a'), isNull);
    await saveMensaLogin(
      '1:a',
      const MensaLogin(host: 'essen.example', user: 'anna', pass: 'geheim'),
    );
    final l = (await readMensaLogin('1:a'))!;
    expect([l.host, l.user, l.pass], ['essen.example', 'anna', 'geheim']);
    expect(await readMensaLogin('1:b'), isNull, reason: 'je Kind getrennt');
    await declineMensaLogin('1:b');
    expect(await mensaLoginDeclined('1:b'), isTrue);
    expect(await readMensaLogin('1:b'), isNull);
    await forgetMensaLogin('1:a');
    expect(await readMensaLogin('1:a'), isNull);
  });

  test('Ausfüllen: Werte als JSON, Anführungszeichen sicher', () {
    final js = mensaLoginFillJs(
      const MensaLogin(host: 'h', user: 'an"na', pass: "p'w\\x"),
    );
    expect(js, contains(r'"an\"na"'));
    expect(js, contains(r'''"p'w\\x"'''));
  });
}

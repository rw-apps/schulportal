import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/view/settings/subsettings/debug_export.dart';

void main() {
  // Ursache: Export vom 16.10.26 09:54 enthielt einen sid im Klartext
  // (Set-Cookie nach dateispeicher.php). Zeile wortgleich, Wert ersetzt.
  test('sid-Wert wird geschwärzt, Rest bleibt lesbar', () {
    const line =
        'set-cookie: i=1234; secure,sid=016d0000aaaabbbbccccdddd; path=/; '
        'domain=schulportal.hessen.de; secure';
    final out = redactSessionCookies(line);
    expect(out, contains('sid=<geschwaerzt>; path=/'));
    expect(out, contains('i=1234'));
    expect(out, isNot(contains('016d0000')));
    expect(out, isNot(contains(r'$1')));
  });

  test('Namen, die nur auf sid enden, bleiben unberührt', () {
    expect(redactSessionCookies('xsid=1; a=b'), 'xsid=1; a=b');
  });
}

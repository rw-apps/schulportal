import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork_identity.dart';

/// Versionsname je Build (Rückmeldung 30.10.26, Obtainium) – Anzeige und
/// User-Agent ohne doppelte Build-Nummer.
void main() {
  test('neuer Versionsname trägt den Build schon', () {
    expect(appVersionLabel('4.1.0+9452', '11452'), '4.1.0+9452');
    expect(
      forkUserAgent('4.1.0+9452', '11452'),
      'Schulportal-rw/v4.1.0+9452 (fork of Lanis-Mobile)',
    );
  });
  test('ältere Builds und iOS: Build-Nummer anhängen', () {
    expect(appVersionLabel('4.1.0', '11443'), '4.1.0+11443');
  });
}

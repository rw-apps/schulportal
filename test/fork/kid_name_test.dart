import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/kid_name.dart';
import 'package:liblanis/liblanis.dart';

/// Vorname des Kindes für die Hinweise (kid_name.dart) – synthetisch.
void main() {
  test('merken nur mit Namen, lesen leer ohne Eintrag', () async {
    final db = LanisDatabase.open();
    final id = await db.addAccount(
      schoolId: 1234,
      schoolName: 'Muster-Gymnasium',
      username: 'lena.muster',
      password: 'x',
    );
    final s = TypedSettings.account(db, id);
    expect(storedKidName(s), '');
    rememberKidName(s, '');
    expect(storedKidName(s), '');
    rememberKidName(s, shortFirstName('Lena Marie'));
    expect(storedKidName(s), 'Lena');
    rememberKidName(s, '');
    expect(storedKidName(s), 'Lena', reason: 'leer überschreibt nicht');
  });
}

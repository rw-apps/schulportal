import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/class_choice.dart';
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
  test('Schuljahresende', () {
    expect(schoolYearEnd(DateTime(2026, 10, 20)).year, 2027);
    expect(schoolYearEnd(DateTime(2027, 3, 1)).year, 2027);
    expect(schoolYearEnd(DateTime(2027, 8, 1)).year, 2028);
  });

  test('Eintrag gilt bis 31. Juli, danach abgelaufen', () {
    final s = _mem();
    storeClass(s, '9C', now: DateTime(2026, 10, 20));
    expect(storedClass(s, now: DateTime(2027, 7, 31, 12))?.name, '9C');
    expect(storedClass(s, now: DateTime(2027, 8, 1)), isNull);
    expect(classExpired(s, now: DateTime(2027, 8, 1)), isTrue);
    expect(classExpired(s, now: DateTime(2027, 7, 1)), isFalse);
  });

  test('Entfernen und Anzeige', () {
    final s = _mem();
    storeClass(s, '6 Ahorn');
    storeClass(s, null);
    expect(storedClass(s), isNull);
    expect(classExpired(s), isFalse);
    expect(classLabel('09C'), '9C');
    expect(classLabel('06 AH'), '6 AH');
    expect(classLabel('10B'), '10B');
    expect(splitClass('6 Ahorn'), (grade: 6, rest: 'Ahorn'));
    expect(splitClass('09C'), (grade: 9, rest: 'C'));
  });
}

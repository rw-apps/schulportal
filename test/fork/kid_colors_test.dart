import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/kid_colors.dart';

void main() {
  test('ohne Speicher: Anlage-Reihenfolge', () {
    final r = assignKidColors([5, 2], {});
    expect(r.colors, {2: 0, 5: 1});
    expect(r.fresh, {2: 0, 5: 1});
  });

  test('gespeicherte Farben bleiben, neue nehmen die erste freie', () {
    final r = assignKidColors([1, 2, 3], {1: 1, 2: null, 3: 0});
    expect(r.colors, {1: 1, 2: 2, 3: 0});
    expect(r.fresh, {2: 2});
  });

  test('entferntes Konto: die übrigen behalten ihre Farbe', () {
    final r = assignKidColors([3], {3: 1});
    expect(r.colors, {3: 1});
    expect(r.fresh, isEmpty);
  });

  test('mehr Kinder als Farben', () {
    final r = assignKidColors([1, 2, 3, 4, 5], {});
    expect(r.colors.values.toSet().length, kidColorCount);
    expect(r.colors.length, 5);
  });

  test('doppelte gespeicherte Farbe wird aufgelöst', () {
    final r = assignKidColors([1, 2], {1: 0, 2: 0});
    expect(r.colors, {1: 0, 2: 1});
    expect(r.fresh, {2: 1});
  });

  test('Wahl einer belegten Farbe tauscht', () {
    expect(pickKidColor({1: 0, 2: 1}, 2, 0), {2: 0, 1: 1});
    expect(pickKidColor({1: 0, 2: 1}, 2, 3), {2: 3});
  });
}

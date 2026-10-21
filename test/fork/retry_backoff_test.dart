import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/ui/live/serial_loader.dart';

/// Wiederholversuche nach einem Fehler (serial_loader.dart, RetryBackoff).
void main() {
  test('1, 2, 5 Minuten, dann fester Takt; Erfolg setzt zurück', () {
    final b = RetryBackoff(const [
      Duration(minutes: 1),
      Duration(minutes: 2),
      Duration(minutes: 5),
    ]);
    expect(b.after(failed: true), const Duration(minutes: 1));
    expect(b.after(failed: true), const Duration(minutes: 2));
    expect(b.after(failed: true), const Duration(minutes: 5));
    expect(b.after(failed: true), isNull, reason: 'dann 10-Minuten-Takt');
    expect(b.after(failed: false), isNull);
    expect(b.after(failed: true), const Duration(minutes: 1));
  });
}

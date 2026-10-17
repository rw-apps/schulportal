import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/ui/live/serial_loader.dart';

void main() {
  test('Durchgang ohne await sperrt nicht (Befund 9328)', () async {
    var runs = 0;
    final l = SerialLoader((_, _) async => runs++);
    await l.run();
    await l.run();
    expect(runs, 2);
    expect(l.busy, isFalse);
  });

  test(
    'Wunsch während eines Durchgangs wird nachgeholt, zusammengefasst',
    () async {
      final calls = <(bool, Set<String>?)>[];
      final gate = Completer<void>();
      final l = SerialLoader((force, only) async {
        calls.add((force, only));
        if (calls.length == 1) await gate.future;
      });
      final first = l.run(only: {'a'});
      await Future<void>.delayed(Duration.zero);
      final second = l.run(force: true, only: {'b'});
      final third = l.run(only: {'c'});
      gate.complete();
      await Future.wait([first, second, third]);
      expect(calls, hasLength(2));
      expect(calls[1].$1, isTrue);
      expect(calls[1].$2, {'b', 'c'});
    },
  );

  test('Fehler im Durchgang beendet die Kette nicht', () async {
    var runs = 0;
    final l = SerialLoader((_, _) async {
      runs++;
      throw StateError('x');
    });
    await l.run();
    await l.run();
    expect(runs, 2);
  });

  test('„alle“ schlägt einzelne Quellen', () async {
    final calls = <Set<String>?>[];
    final gate = Completer<void>();
    final l = SerialLoader((_, only) async {
      calls.add(only);
      if (calls.length == 1) await gate.future;
    });
    final a = l.run(only: {'a'});
    await Future<void>.delayed(Duration.zero);
    l.run(only: {'b'});
    final c = l.run();
    gate.complete();
    await Future.wait([a, c]);
    expect(calls.last, isNull);
  });
}
